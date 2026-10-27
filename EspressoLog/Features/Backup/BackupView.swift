import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Backup & Restore: automatic backups to a folder in Files, plus manual export and restore.
struct BackupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var beans: [CoffeeBean]
    @Query private var shots: [ShotLog]
    @Query private var profiles: [EquipmentProfile]

    @State private var autoStatus: AutoBackup.Status = .off
    @State private var exportDocument: BackupDocument?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var importMode: ImportMode = .restore
    @State private var pendingRestore: BackupFile?
    @State private var message: Message?

    private enum ImportMode {
        case restore, folder

        var contentTypes: [UTType] {
            switch self {
            case .restore: [.json]
            case .folder: [.folder]
            }
        }
    }

    private struct Message: Identifiable {
        let id = UUID()
        let title: String
        let body: String
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Deleting Dial-In also deletes everything logged in it. Keep a backup outside the app so you can restore your bags and brews on a fresh install.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)

                    autoBackupCard
                    manualCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .fileExporter(
                isPresented: $isExporting,
                document: exportDocument,
                contentType: .json,
                defaultFilename: BackupFile.suggestedFilename()
            ) { result in
                if case .failure(let error) = result {
                    message = Message(title: "Export Failed", body: error.localizedDescription)
                }
            }
            .paperBackground()
            .navigationTitle("Backup & Restore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.paper, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: importMode.contentTypes) { result in
            handleImport(result)
        }
        .alert(
            "Restore This Backup?",
            isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }),
            presenting: pendingRestore
        ) { file in
            Button("Restore") { restore(file) }
            Button("Cancel", role: .cancel) {}
        } message: { file in
            Text("Backup from \(file.exportedAt, format: .dateTime.day().month(.abbreviated).year()) with \(count(file.beans.count, "bag")) and \(count(file.shots.count, "brew")). Entries you already have are kept; nothing is deleted.")
        }
        .alert(
            message?.title ?? "",
            isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } }),
            presenting: message
        ) { _ in
            Button("OK") {}
        } message: { message in
            Text(message.body)
        }
        .presentationBackground(Palette.paper)
        .onAppear { autoStatus = AutoBackup.status() }
    }

    // MARK: Cards

    private var autoBackupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Automatic backup")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                Spacer()
                statusPill
            }

            switch autoStatus {
            case .off:
                Text("Choose a folder in iCloud Drive and Dial-In will save a backup there every time you leave the app, so it survives deleting the app or changing phones.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    presentImporter(.folder)
                } label: {
                    buttonLabel("Choose Folder…", systemImage: "folder.badge.plus")
                }
                .buttonStyle(PaperButtonStyle(kind: .prominent))

            case .on(let folderName, let lastBackup, let lastError):
                VStack(alignment: .leading, spacing: 4) {
                    Label(folderName, systemImage: "folder")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                    Text(AutoBackup.filename)
                        .font(.mono(.caption))
                        .foregroundStyle(Palette.inkSecondary)
                    if let lastBackup {
                        Text("Last backup \(lastBackup, format: .relative(presentation: .named))")
                            .font(.footnote)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                    if let lastError {
                        Label(lastError, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(Palette.sour)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Button(action: backUpNow) {
                    buttonLabel("Back Up Now", systemImage: "arrow.clockwise")
                }
                .buttonStyle(PaperButtonStyle(kind: .prominent))

                HStack(spacing: 8) {
                    Button {
                        presentImporter(.folder)
                    } label: {
                        buttonLabel("Change Folder", systemImage: "folder")
                    }
                    Button {
                        AutoBackup.disable()
                        autoStatus = AutoBackup.status()
                    } label: {
                        buttonLabel("Turn Off", systemImage: "xmark")
                    }
                }
                .buttonStyle(PaperButtonStyle(kind: .inset))
            }
        }
        .padding(16)
        .paperCard()
    }

    private var statusPill: some View {
        let isOn = autoStatus != .off
        let tint: Color = isOn ? Palette.sweet : Palette.inkSecondary
        return Text(isOn ? "On" : "Off")
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(tint)
            .background(tint.opacity(0.14), in: Capsule())
    }

    private var manualCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Export & restore")
                .font(.headline)
                .foregroundStyle(Palette.ink)

            Text("Save a backup file anywhere, or restore one after reinstalling. Restoring only adds what's missing; it never deletes or duplicates entries.")
                .font(.subheadline)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(count(beans.count, "bag")) · \(count(shots.count, "brew")) · \(count(profiles.count, "gear profile"))")
                .font(.mono(.footnote))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.inset, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button(action: export) {
                buttonLabel("Export Backup…", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(PaperButtonStyle(kind: .card))

            Button {
                presentImporter(.restore)
            } label: {
                buttonLabel("Restore from Backup…", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(PaperButtonStyle(kind: .card))
        }
        .padding(16)
        .paperCard()
    }

    private func buttonLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, minHeight: 48)
    }

    private func count(_ value: Int, _ noun: String) -> String {
        "\(value) \(noun)\(value == 1 ? "" : "s")"
    }

    // MARK: Actions

    private func presentImporter(_ mode: ImportMode) {
        importMode = mode
        isImporting = true
    }

    private func export() {
        do {
            exportDocument = BackupDocument(data: try BackupService.exportData(from: context))
            isExporting = true
        } catch {
            message = Message(title: "Export Failed", body: error.localizedDescription)
        }
    }

    private func backUpNow() {
        do {
            try AutoBackup.backUp(context: context)
        } catch {
            message = Message(title: "Backup Failed", body: error.localizedDescription)
        }
        autoStatus = AutoBackup.status()
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            message = Message(title: "Couldn't Open", body: error.localizedDescription)
        case .success(let url):
            switch importMode {
            case .restore:
                let didAccess = url.startAccessingSecurityScopedResource()
                defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
                do {
                    pendingRestore = try BackupService.decode(Data(contentsOf: url))
                } catch {
                    message = Message(title: "Couldn't Read Backup", body: error.localizedDescription)
                }
            case .folder:
                do {
                    try AutoBackup.enable(folder: url, context: context)
                    message = Message(
                        title: "Automatic Backup On",
                        body: "Dial-In saved \(AutoBackup.filename) in “\(url.lastPathComponent)” and will update it every time you leave the app."
                    )
                } catch {
                    message = Message(title: "Couldn't Use Folder", body: error.localizedDescription)
                }
                autoStatus = AutoBackup.status()
            }
        }
    }

    private func restore(_ file: BackupFile) {
        do {
            let summary = try BackupService.restore(file, into: context)
            let skipped = summary.beansSkipped + summary.shotsSkipped
            var body = "Added \(count(summary.beansAdded, "bag")), \(count(summary.shotsAdded, "brew")) and \(count(summary.equipmentAdded, "gear profile"))."
            if skipped > 0 {
                body += " Skipped \(skipped) \(skipped == 1 ? "entry" : "entries") you already had."
            }
            message = Message(title: "Backup Restored", body: body)
        } catch {
            message = Message(title: "Restore Failed", body: error.localizedDescription)
        }
    }
}

/// JSON backup handed to the system's export sheet.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

#Preview(traits: .sampleData) {
    BackupView()
}
