import Foundation

/// Portable JSON snapshot of everything the user logged: equipment, coffee bags and brews.
///
/// Records reference each other by file-local integer ids (`beanID`, `equipmentID`), so a backup
/// can be restored into any store. Enum fields keep their stored raw strings.
struct BackupFile: Codable, Sendable {
    /// Bump when the record shapes change in a way older readers can't decode.
    static let currentFormat = 1

    var format: Int
    var app: String
    var appVersion: String
    var exportedAt: Date
    var equipment: [EquipmentRecord]
    var beans: [BeanRecord]
    var shots: [ShotRecord]

    struct EquipmentRecord: Codable, Sendable {
        var id: Int
        var machineName: String
        var grinderName: String
        var grinderZeroOffset: Int
        var basket: String
        var puckScreen: String?
        var defaultDripper: String
        var isActive: Bool
        var createdAt: Date
    }

    struct BeanRecord: Codable, Sendable {
        var id: Int
        var name: String
        var roaster: String
        var variety: String
        var process: String
        var roastDate: Date
        var isFrozen: Bool
        var freezeDate: Date?
        var frozenDaysBanked: Int
        var bagWeightGrams: Double
        var bagNumber: Int
        var isActive: Bool
        var isFinished: Bool
        var finishedDate: Date?
        var createdAt: Date
        // Added in v1.7. Optional so backups from earlier versions still decode.
        var rating: Int?
        var ratingNotes: String?
        var ratedAt: Date?
        var isFavorite: Bool?
    }

    struct ShotRecord: Codable, Sendable {
        var beanID: Int?
        var equipmentID: Int?
        var timestamp: Date
        var brewMethod: String
        var dose: Double
        var yield: Double
        var totalTime: Double
        var grindSetting: Double
        var grinderZeroOffset: Int
        var grinderRPM: Int?
        var feedMethod: String
        var brewTemperature: Double
        var preBrewPulse: Double
        var preBrewPause: Double
        var dripper: String?
        var bloomWater: Double
        var pourCount: Int
        var agitation: String
        var flowQuality: String
        var tasteBalance: String
        var flavorNotes: [String]
        var actionableNextTweak: String?
        var restDaysAtBrew: Int
    }
}

extension BackupFile {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// `DialIn-Backup-2026-10-27.json`
    static func suggestedFilename(on date: Date = .now) -> String {
        "DialIn-Backup-\(date.formatted(.iso8601.year().month().day()))"
    }
}
