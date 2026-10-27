import Foundation
import SwiftData

/// Keeps `DialIn-Backup.json` up to date in a folder the user picked in Files (e.g. iCloud Drive).
///
/// The app's own storage is deleted with the app, so the backup lives outside it. Access to the
/// folder survives relaunches through a security-scoped bookmark; the file is rewritten whenever
/// the app goes to the background.
@MainActor
enum AutoBackup {
    static let filename = "DialIn-Backup.json"

    private enum Keys {
        static let bookmark = "autoBackup.folderBookmark"
        static let lastBackup = "autoBackup.lastBackupDate"
        static let lastError = "autoBackup.lastError"
    }

    enum Status: Equatable {
        case off
        case on(folderName: String, lastBackup: Date?, lastError: String?)
    }

    static func status(defaults: UserDefaults = .standard) -> Status {
        guard let folder = resolveFolder(defaults: defaults) else { return .off }
        let interval = defaults.double(forKey: Keys.lastBackup)
        return .on(
            folderName: folder.lastPathComponent,
            lastBackup: interval > 0 ? Date(timeIntervalSince1970: interval) : nil,
            lastError: defaults.string(forKey: Keys.lastError)
        )
    }

    /// Remembers `folder` (just picked in the document browser) and writes a first backup there.
    static func enable(folder: URL, context: ModelContext, defaults: UserDefaults = .standard) throws {
        let didAccess = folder.startAccessingSecurityScopedResource()
        defer { if didAccess { folder.stopAccessingSecurityScopedResource() } }
        let bookmark = try folder.bookmarkData()
        defaults.set(bookmark, forKey: Keys.bookmark)
        try backUp(context: context, defaults: defaults)
    }

    static func disable(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: Keys.bookmark)
        defaults.removeObject(forKey: Keys.lastBackup)
        defaults.removeObject(forKey: Keys.lastError)
    }

    /// Writes a fresh backup if auto-backup is on. Errors are recorded for the Backup screen
    /// rather than thrown, since this runs as the app leaves the foreground.
    static func runIfEnabled(context: ModelContext, defaults: UserDefaults = .standard) {
        guard defaults.data(forKey: Keys.bookmark) != nil else { return }
        try? backUp(context: context, defaults: defaults)
    }

    /// Writes the backup now. Throws, and records the error, if the folder can't be reached.
    static func backUp(context: ModelContext, defaults: UserDefaults = .standard) throws {
        do {
            guard let folder = resolveFolder(defaults: defaults) else {
                throw CocoaError(.fileNoSuchFile)
            }
            let data = try BackupService.exportData(from: context)
            try write(data, into: folder)
            defaults.set(Date.now.timeIntervalSince1970, forKey: Keys.lastBackup)
            defaults.removeObject(forKey: Keys.lastError)
        } catch {
            defaults.set(error.localizedDescription, forKey: Keys.lastError)
            throw error
        }
    }

    private static func resolveFolder(defaults: UserDefaults) -> URL? {
        guard let bookmark = defaults.data(forKey: Keys.bookmark) else { return nil }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale) else {
            return nil
        }
        if isStale {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            if let refreshed = try? url.bookmarkData() {
                defaults.set(refreshed, forKey: Keys.bookmark)
            }
        }
        return url
    }

    /// Coordinated, atomic write so iCloud Drive and the Files app never see a half-written file.
    private static func write(_ data: Data, into folder: URL) throws {
        let didAccess = folder.startAccessingSecurityScopedResource()
        defer { if didAccess { folder.stopAccessingSecurityScopedResource() } }

        let target = folder.appendingPathComponent(filename)
        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: target, options: .forReplacing, error: &coordinationError) { url in
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                writeError = error
            }
        }
        if let error = (coordinationError as Error?) ?? writeError {
            throw error
        }
    }
}
