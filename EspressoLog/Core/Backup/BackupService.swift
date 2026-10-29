import Foundation
import SwiftData

/// Builds backups from the store and merges backups back into it.
///
/// Restoring is a merge, never a wipe: records already in the store are matched and skipped,
/// so importing the same file twice (or a file that overlaps current data) adds no duplicates.
@MainActor
enum BackupService {
    enum BackupError: LocalizedError {
        case unreadable
        case newerFormat(Int)

        var errorDescription: String? {
            switch self {
            case .unreadable:
                "This file isn't a Dial-In backup, or it's damaged."
            case .newerFormat(let format):
                "This backup was made by a newer version of Dial-In (format \(format)). Update the app, then try again."
            }
        }
    }

    struct RestoreSummary: Equatable {
        var beansAdded = 0
        var beansSkipped = 0
        var shotsAdded = 0
        var shotsSkipped = 0
        var equipmentAdded = 0
        var equipmentSkipped = 0
    }

    // MARK: Export

    static func makeBackup(from context: ModelContext, now: Date = .now) throws -> BackupFile {
        let equipment = try context.fetch(FetchDescriptor<EquipmentProfile>(sortBy: [SortDescriptor(\.createdAt)]))
        let beans = try context.fetch(FetchDescriptor<CoffeeBean>(sortBy: [SortDescriptor(\.createdAt)]))
        let shots = try context.fetch(FetchDescriptor<ShotLog>(sortBy: [SortDescriptor(\.timestamp)]))

        var equipmentIDs: [PersistentIdentifier: Int] = [:]
        let equipmentRecords = equipment.enumerated().map { index, profile in
            equipmentIDs[profile.persistentModelID] = index + 1
            return BackupFile.EquipmentRecord(
                id: index + 1,
                machineName: profile.machineName,
                grinderName: profile.grinderName,
                grinderZeroOffset: profile.grinderZeroOffset,
                basket: profile.basket,
                puckScreen: profile.puckScreen,
                defaultDripper: profile.defaultDripper,
                isActive: profile.isActive,
                createdAt: profile.createdAt
            )
        }

        var beanIDs: [PersistentIdentifier: Int] = [:]
        let beanRecords = beans.enumerated().map { index, bean in
            beanIDs[bean.persistentModelID] = index + 1
            return BackupFile.BeanRecord(
                id: index + 1,
                name: bean.name,
                roaster: bean.roaster,
                variety: bean.variety,
                process: bean.process,
                roastDate: bean.roastDate,
                isFrozen: bean.isFrozen,
                freezeDate: bean.freezeDate,
                frozenDaysBanked: bean.frozenDaysBanked,
                bagWeightGrams: bean.bagWeightGrams,
                bagNumber: bean.bagNumber,
                isActive: bean.isActive,
                isFinished: bean.isFinished,
                finishedDate: bean.finishedDate,
                createdAt: bean.createdAt,
                rating: bean.rating,
                ratingNotes: bean.ratingNotes.isEmpty ? nil : bean.ratingNotes,
                ratedAt: bean.ratedAt,
                isFavorite: bean.isFavorite
            )
        }

        let shotRecords = shots.map { shot in
            BackupFile.ShotRecord(
                beanID: shot.bean.flatMap { beanIDs[$0.persistentModelID] },
                equipmentID: shot.equipment.flatMap { equipmentIDs[$0.persistentModelID] },
                timestamp: shot.timestamp,
                brewMethod: shot.brewMethodRaw,
                dose: shot.dose,
                yield: shot.yield,
                totalTime: shot.totalTime,
                grindSetting: shot.grindSetting,
                grinderZeroOffset: shot.grinderZeroOffset,
                grinderRPM: shot.grinderRPM,
                feedMethod: shot.feedMethodRaw,
                brewTemperature: shot.brewTemperature,
                preBrewPulse: shot.preBrewPulse,
                preBrewPause: shot.preBrewPause,
                dripper: shot.dripper,
                bloomWater: shot.bloomWater,
                pourCount: shot.pourCount,
                agitation: shot.agitationRaw,
                flowQuality: shot.flowQualityRaw,
                tasteBalance: shot.tasteBalanceRaw,
                flavorNotes: shot.flavorNotes,
                actionableNextTweak: shot.actionableNextTweak,
                restDaysAtBrew: shot.restDaysAtBrew
            )
        }

        return BackupFile(
            format: BackupFile.currentFormat,
            app: "Dial-In",
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            exportedAt: now,
            equipment: equipmentRecords,
            beans: beanRecords,
            shots: shotRecords
        )
    }

    static func exportData(from context: ModelContext) throws -> Data {
        try BackupFile.encoder().encode(makeBackup(from: context))
    }

    static func decode(_ data: Data) throws -> BackupFile {
        let file: BackupFile
        do {
            file = try BackupFile.decoder().decode(BackupFile.self, from: data)
        } catch {
            if let header = try? JSONDecoder().decode(FormatHeader.self, from: data),
               header.format > BackupFile.currentFormat {
                throw BackupError.newerFormat(header.format)
            }
            throw BackupError.unreadable
        }
        guard file.format <= BackupFile.currentFormat else {
            throw BackupError.newerFormat(file.format)
        }
        return file
    }

    private struct FormatHeader: Decodable {
        var format: Int
    }

    // MARK: Restore

    @discardableResult
    static func restore(_ file: BackupFile, into context: ModelContext) throws -> RestoreSummary {
        var summary = RestoreSummary()

        // Equipment: match on what the gear is, so the default profile a fresh install seeds
        // is reused when it is the same setup as the backed-up one.
        let existingEquipment = try context.fetch(FetchDescriptor<EquipmentProfile>())
        var equipmentByID: [Int: EquipmentProfile] = [:]
        for record in file.equipment {
            if let match = existingEquipment.first(where: { Key.equipment($0) == Key.equipment(record) }) {
                equipmentByID[record.id] = match
                summary.equipmentSkipped += 1
                continue
            }
            let profile = EquipmentProfile(
                machineName: record.machineName,
                grinderName: record.grinderName,
                grinderZeroOffset: record.grinderZeroOffset,
                basket: record.basket,
                puckScreen: record.puckScreen,
                defaultDripper: record.defaultDripper
            )
            profile.createdAt = record.createdAt
            context.insert(profile)
            equipmentByID[record.id] = profile
            summary.equipmentAdded += 1
        }

        let existingBeans = try context.fetch(FetchDescriptor<CoffeeBean>())
        var existingBeanKeys: [Key.Bean: CoffeeBean] = [:]
        for bean in existingBeans { existingBeanKeys[Key.bean(bean)] = bean }

        var beanByID: [Int: CoffeeBean] = [:]
        for record in file.beans {
            if let match = existingBeanKeys[Key.bean(record)] {
                adoptRating(from: record, into: match)
                beanByID[record.id] = match
                summary.beansSkipped += 1
                continue
            }
            let bean = CoffeeBean(
                name: record.name,
                roaster: record.roaster,
                variety: record.variety,
                process: record.process,
                roastDate: record.roastDate,
                bagWeightGrams: record.bagWeightGrams,
                bagNumber: record.bagNumber,
                isFrozen: record.isFrozen,
                freezeDate: record.freezeDate,
                isFinished: record.isFinished,
                finishedDate: record.finishedDate
            )
            bean.frozenDaysBanked = record.frozenDaysBanked
            bean.createdAt = record.createdAt
            adoptRating(from: record, into: bean)
            context.insert(bean)
            beanByID[record.id] = bean
            existingBeanKeys[Key.bean(record)] = bean
            summary.beansAdded += 1
        }

        let existingShots = try context.fetch(FetchDescriptor<ShotLog>())
        var shotKeys = Set(existingShots.map { Key.shot($0) })
        for record in file.shots {
            let key = Key.shot(record)
            guard !shotKeys.contains(key) else {
                summary.shotsSkipped += 1
                continue
            }
            let shot = ShotLog(
                timestamp: record.timestamp,
                dose: record.dose,
                yield: record.yield,
                totalTime: record.totalTime,
                grindSetting: record.grindSetting,
                grinderZeroOffset: record.grinderZeroOffset,
                grinderRPM: record.grinderRPM,
                brewTemperature: record.brewTemperature,
                preBrewPulse: record.preBrewPulse,
                preBrewPause: record.preBrewPause,
                dripper: record.dripper,
                bloomWater: record.bloomWater,
                pourCount: record.pourCount,
                tasteBalance: TasteBalance(rawValue: record.tasteBalance) ?? .balancedSweet,
                flavorNotes: record.flavorNotes,
                actionableNextTweak: record.actionableNextTweak,
                restDaysAtBrew: record.restDaysAtBrew
            )
            // Raw strings are copied as-is so values from newer app versions survive a round trip.
            shot.brewMethodRaw = record.brewMethod
            shot.feedMethodRaw = record.feedMethod
            shot.agitationRaw = record.agitation
            shot.flowQualityRaw = record.flowQuality
            shot.tasteBalanceRaw = record.tasteBalance
            context.insert(shot)
            shot.bean = record.beanID.flatMap { beanByID[$0] }
            shot.equipment = record.equipmentID.flatMap { equipmentByID[$0] }
            shotKeys.insert(key)
            summary.shotsAdded += 1
        }

        restoreActiveSelection(from: file, beans: beanByID, equipment: equipmentByID, in: context)
        try context.save()
        return summary
    }

    /// Hands the "active" bag and gear to the backup's choice unless the user is already
    /// working with something here (an active item that has logged pulls).
    private static func restoreActiveSelection(
        from file: BackupFile,
        beans: [Int: CoffeeBean],
        equipment: [Int: EquipmentProfile],
        in context: ModelContext
    ) {
        let allBeans = (try? context.fetch(FetchDescriptor<CoffeeBean>())) ?? []
        let currentBean = allBeans.first(where: \.isActive)
        if currentBean.map({ $0.shots.isEmpty }) ?? true,
           let id = file.beans.first(where: \.isActive)?.id,
           let bean = beans[id] {
            context.activate(bean)
        }

        let allEquipment = (try? context.fetch(FetchDescriptor<EquipmentProfile>())) ?? []
        let currentProfile = allEquipment.first(where: \.isActive)
        if currentProfile.map({ $0.shots.isEmpty }) ?? true,
           let id = file.equipment.first(where: \.isActive)?.id,
           let profile = equipment[id] {
            context.activate(profile)
        }
    }

    // MARK: Matching keys

    /// Identity used to recognise records already in the store. Dates compare to the whole
    /// second because the backup's ISO 8601 dates drop fractions of a second.
    /// Fills in the score, notes and favorite from a backup. A bag that already has a rating on this
    /// device keeps it, so restoring never overwrites newer notes. A favorite is only ever added.
    private static func adoptRating(from record: BackupFile.BeanRecord, into bean: CoffeeBean) {
        if bean.rating == nil, bean.ratingNotes.isEmpty {
            bean.rating = record.rating.map { min(max($0, CoffeeBean.ratingScale.lowerBound), CoffeeBean.ratingScale.upperBound) }
            bean.ratingNotes = record.ratingNotes ?? ""
            bean.ratedAt = record.ratedAt
        }
        if record.isFavorite == true {
            bean.isFavorite = true
        }
    }

    private enum Key {
        struct Bean: Hashable {
            let name: String
            let roaster: String
            let bagNumber: Int
            let createdAt: Int
        }

        struct Shot: Hashable {
            let timestamp: Int
            let method: String
            let dose: Double
            let yield: Double
        }

        struct Equipment: Equatable {
            let machine: String
            let grinder: String
            let zeroOffset: Int
            let basket: String
            let puckScreen: String
            let dripper: String
        }

        static func seconds(_ date: Date) -> Int {
            Int(date.timeIntervalSince1970.rounded(.down))
        }

        static func normalized(_ text: String) -> String {
            text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }

        static func bean(_ bean: CoffeeBean) -> Bean {
            Bean(name: normalized(bean.name), roaster: normalized(bean.roaster), bagNumber: bean.bagNumber, createdAt: seconds(bean.createdAt))
        }

        static func bean(_ record: BackupFile.BeanRecord) -> Bean {
            Bean(name: normalized(record.name), roaster: normalized(record.roaster), bagNumber: record.bagNumber, createdAt: seconds(record.createdAt))
        }

        static func shot(_ shot: ShotLog) -> Shot {
            Shot(timestamp: seconds(shot.timestamp), method: shot.brewMethodRaw, dose: shot.dose, yield: shot.yield)
        }

        static func shot(_ record: BackupFile.ShotRecord) -> Shot {
            Shot(timestamp: seconds(record.timestamp), method: record.brewMethod, dose: record.dose, yield: record.yield)
        }

        static func equipment(_ profile: EquipmentProfile) -> Equipment {
            Equipment(
                machine: normalized(profile.machineName),
                grinder: normalized(profile.grinderName),
                zeroOffset: profile.grinderZeroOffset,
                basket: normalized(profile.basket),
                puckScreen: normalized(profile.puckScreen ?? ""),
                dripper: normalized(profile.defaultDripper)
            )
        }

        static func equipment(_ record: BackupFile.EquipmentRecord) -> Equipment {
            Equipment(
                machine: normalized(record.machineName),
                grinder: normalized(record.grinderName),
                zeroOffset: record.grinderZeroOffset,
                basket: normalized(record.basket),
                puckScreen: normalized(record.puckScreen ?? ""),
                dripper: normalized(record.defaultDripper)
            )
        }
    }
}
