import Foundation
import SwiftData
import OSLog

/// Numeric inputs driven by the in-app keypad, in "Next" order.
enum NumericField: Int, CaseIterable, Identifiable, Sendable {
    case dose, yield, time, temperature, pulse, pause, rpm

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .dose: "Dose"
        case .yield: "Yield"
        case .time: "Time"
        case .temperature: "Temp"
        case .pulse: "PB On"
        case .pause: "PB Wait"
        case .rpm: "RPM"
        }
    }

    var unit: String {
        switch self {
        case .dose, .yield: "g"
        case .time, .pulse, .pause: "s"
        case .temperature: "°C"
        case .rpm: ""
        }
    }

    var fractionDigits: Int { self == .rpm ? 0 : 1 }

    var maxIntegerDigits: Int {
        switch self {
        case .yield, .time: 3
        case .rpm: 4
        default: 2
        }
    }

    var range: ClosedRange<Double> {
        switch self {
        case .dose: 1...40
        case .yield: 1...150
        case .time: 1...180
        case .temperature: 80...100
        case .pulse, .pause: 0...30
        case .rpm: 0...2500
        }
    }

    var nudgeStep: Double {
        switch self {
        case .dose: 0.1
        case .yield, .temperature, .pulse, .pause: 0.5
        case .time: 1
        case .rpm: 100
        }
    }

    var next: NumericField? { NumericField(rawValue: rawValue + 1) }

    func clamp(_ value: Double) -> Double {
        let scale = pow(10, Double(fractionDigits))
        let rounded = (value * scale).rounded() / scale
        return min(max(rounded, range.lowerBound), range.upperBound)
    }
}

enum KeypadKey: Hashable, Sendable {
    case digit(Int)
    case decimal
    case delete
}

@MainActor
@Observable
final class ShotLoggingViewModel {
    static let defaultFlavorTags = [
        "Juicy Peach", "Raspberry", "Honey", "Floral", "Citrus", "Stone Fruit",
        "Caramel", "Chocolate", "Tea-like", "Lime",
    ]
    /// Positive grind wheel range in tenths: 0.0 … 10.0.
    static let grindScale: ClosedRange<Int> = 0...100
    static let decimalSeparator = Locale.current.decimalSeparator ?? "."

    private static let logger = Logger(subsystem: "EspressoLog", category: "ShotLogging")

    // MARK: Context

    let bean: CoffeeBean
    let equipment: EquipmentProfile?
    /// Values the draft was pre-filled from (last shot of this bean, else last shot overall).
    let template: ShotSnapshot?
    /// The "Next" note written on this bean's previous shot.
    let previousTweak: String?
    let restDays: Int
    let grindRange: ClosedRange<Int>
    let flavorSuggestions: [String]
    private let baselineFeed: FeedMethod

    // MARK: Draft

    var dose: Double
    var yield: Double
    var totalTime: Double
    /// Positive grind stored in tenths (0 … 100 → 0.0 … 10.0).
    var grindTenths: Int
    /// Integer offset of the grinder's relocated 0-point (e.g. -2, -1, 0, +1, +2).
    var grinderZeroOffset: Int
    var grinderRPM: Int?
    var feedMethod: FeedMethod
    var brewTemperature: Double
    var preBrewPulse: Double
    var preBrewPause: Double
    var flowQuality: FlowQuality = .smoothCone
    var tasteBalance: TasteBalance?
    var flavorNotes: [String] = []
    var nextTweak: String = ""

    // MARK: Keypad state

    private(set) var activeField: NumericField? = .yield
    private(set) var buffer: String?
    /// Incremented on every key press; drives haptics.
    private(set) var keyPressCount = 0
    @ObservationIgnored private var bufferOriginal: Double?

    init(bean: CoffeeBean, equipment: EquipmentProfile?, fallbackTemplate: ShotLog? = nil, now: Date = .now) {
        self.bean = bean
        self.equipment = equipment

        let history = bean.shotsNewestFirst
        let templateShot = history.first ?? fallbackTemplate
        let template = templateShot?.snapshot
        self.template = template
        self.previousTweak = templateShot?.actionableNextTweak
        self.restDays = bean.restDays(on: now)

        dose = template?.dose ?? 18.0
        self.yield = template?.yield ?? 36.0
        totalTime = template?.totalTime ?? 28.0

        let rawTenths = Int(((template?.grindSetting ?? 1.0) * 10).rounded())
        let tenths = max(0, rawTenths)
        grindTenths = tenths
        grindRange = 0...max(Self.grindScale.upperBound, tenths)
        grinderZeroOffset = template?.grinderZeroOffset ?? equipment?.grinderZeroOffset ?? 0

        grinderRPM = template?.grinderRPM
        feedMethod = template?.feedMethod ?? .slowFeed
        baselineFeed = template?.feedMethod ?? .slowFeed
        brewTemperature = template?.brewTemperature ?? 93.0
        preBrewPulse = template?.preBrewPulse ?? 0
        preBrewPause = template?.preBrewPause ?? 0
        flowQuality = template?.flowQuality ?? .smoothCone
        tasteBalance = template?.tasteBalance

        flavorSuggestions = Self.makeFlavorSuggestions(from: history)
    }

    // MARK: Derived

    var grindSetting: Double { Double(max(0, grindTenths)) / 10 }

    var ratio: Double { dose > 0 ? self.yield / dose : 0 }

    var fullPressureTime: Double { max(0, totalTime - (preBrewPulse + preBrewPause)) }

    var isSlowFeed: Bool {
        get { feedMethod == .slowFeed }
        set { feedMethod = newValue ? .slowFeed : .fastDump }
    }

    var draft: ShotSnapshot {
        ShotSnapshot(
            dose: dose,
            yield: self.yield,
            totalTime: totalTime,
            grindSetting: grindSetting,
            grinderZeroOffset: grinderZeroOffset,
            grinderRPM: grinderRPM,
            feedMethod: feedMethod,
            brewTemperature: brewTemperature,
            preBrewPulse: preBrewPulse,
            preBrewPause: preBrewPause,
            flowQuality: flowQuality,
            tasteBalance: tasteBalance,
            restDays: restDays
        )
    }

    var insights: [ExtractionInsight] {
        ExtractionInsightsEngine.insights(for: draft, baselineFeed: baselineFeed)
    }

    var suggestedTweaks: [String] {
        ExtractionInsightsEngine.suggestedTweaks(for: draft)
    }

    var canSave: Bool {
        tasteBalance != nil && dose > 0 && self.yield > 0 && totalTime > 0
    }

    var isGrindChanged: Bool {
        guard let template else { return false }
        return Int((max(0, template.grindSetting) * 10).rounded()) != grindTenths
            || template.grinderZeroOffset != grinderZeroOffset
    }

    /// Whether a field differs from the pre-filled template (shown as a dot on the tile).
    func isChanged(_ field: NumericField) -> Bool {
        guard let template else { return false }
        let original: Double = switch field {
        case .dose: template.dose
        case .yield: template.yield
        case .time: template.totalTime
        case .temperature: template.brewTemperature
        case .pulse: template.preBrewPulse
        case .pause: template.preBrewPause
        case .rpm: Double(template.grinderRPM ?? 0)
        }
        return abs(value(for: field) - original) > 0.001
    }

    // MARK: Keypad

    func value(for field: NumericField) -> Double {
        switch field {
        case .dose: dose
        case .yield: self.yield
        case .time: totalTime
        case .temperature: brewTemperature
        case .pulse: preBrewPulse
        case .pause: preBrewPause
        case .rpm: Double(grinderRPM ?? 0)
        }
    }

    func displayText(for field: NumericField) -> String {
        if field == activeField, let buffer {
            let text = buffer.isEmpty ? "0" : buffer
            return text.replacingOccurrences(of: ".", with: Self.decimalSeparator)
        }
        if field == .rpm, grinderRPM == nil { return "—" }
        return value(for: field).fixed(field.fractionDigits)
    }

    func select(_ field: NumericField?) {
        commitBuffer()
        activeField = field
    }

    func advance() {
        commitBuffer()
        activeField = activeField?.next
    }

    /// The first key press on a field replaces its value; subsequent presses append.
    func press(_ key: KeypadKey) {
        guard let field = activeField else { return }
        keyPressCount += 1
        if buffer == nil { bufferOriginal = value(for: field) }
        var text = buffer ?? ""

        switch key {
        case .digit(let digit):
            let parts = text.split(separator: ".", omittingEmptySubsequences: false)
            if parts.count == 2 {
                guard parts[1].count < field.fractionDigits else { return }
            } else {
                if text == "0" { text = "" }
                guard text.count < field.maxIntegerDigits else { return }
            }
            text += String(digit)
        case .decimal:
            guard field.fractionDigits > 0, !text.contains(".") else { return }
            text = (text.isEmpty ? "0" : text) + "."
        case .delete:
            if buffer == nil {
                text = String(format: "%.\(field.fractionDigits)f", value(for: field))
            }
            if !text.isEmpty { text.removeLast() }
        }

        buffer = text
        if let parsed = Self.parse(text) {
            setValue(parsed, for: field)   // live update so ratio / FP time react while typing
        }
    }

    /// Fine adjustment of the active field by its nudge step.
    func nudge(_ direction: Int) {
        guard let field = activeField else { return }
        commitBuffer()
        keyPressCount += 1
        if field == .rpm, grinderRPM == nil {
            grinderRPM = 1000
            return
        }
        let next = value(for: field) + Double(direction) * field.nudgeStep
        setValue(field.clamp(next), for: field)
    }

    private func commitBuffer() {
        guard let field = activeField, let text = buffer else { return }
        defer {
            buffer = nil
            bufferOriginal = nil
        }
        if field == .rpm, (Self.parse(text) ?? 0) == 0 {
            grinderRPM = nil
            return
        }
        let parsed = Self.parse(text) ?? bufferOriginal ?? value(for: field)
        setValue(field.clamp(parsed), for: field)
    }

    private func setValue(_ newValue: Double, for field: NumericField) {
        switch field {
        case .dose: dose = newValue
        case .yield: self.yield = newValue
        case .time: totalTime = newValue
        case .temperature: brewTemperature = newValue
        case .pulse: preBrewPulse = newValue
        case .pause: preBrewPause = newValue
        case .rpm: grinderRPM = newValue > 0 ? Int(newValue.rounded()) : nil
        }
    }

    private static func parse(_ text: String) -> Double? {
        let cleaned = text.hasSuffix(".") ? String(text.dropLast()) : text
        return cleaned.isEmpty ? nil : Double(cleaned)
    }

    // MARK: Flavor & tweak

    func toggleTag(_ tag: String) {
        if let index = flavorNotes.firstIndex(of: tag) {
            flavorNotes.remove(at: index)
        } else {
            flavorNotes.append(tag)
        }
    }

    func addTag(_ raw: String) {
        let tag = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty,
              !flavorNotes.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame })
        else { return }
        flavorNotes.append(tag)
    }

    func applyTweak(_ tweak: String) {
        let current = nextTweak.trimmingCharacters(in: .whitespaces)
        guard !current.contains(tweak) else { return }
        nextTweak = current.isEmpty ? tweak : "\(current) · \(tweak)"
    }

    private static func makeFlavorSuggestions(from history: [ShotLog]) -> [String] {
        var counts: [String: Int] = [:]
        for shot in history {
            for note in shot.flavorNotes { counts[note, default: 0] += 1 }
        }
        let recent = counts.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }.map(\.key)
        var seen = Set<String>()
        return (recent + defaultFlavorTags).filter { seen.insert($0.lowercased()).inserted }
    }

    // MARK: Persist

    @discardableResult
    func save(in context: ModelContext, now: Date = .now) -> ShotLog? {
        commitBuffer()
        guard let tasteBalance else { return nil }

        let tweak = nextTweak.trimmingCharacters(in: .whitespacesAndNewlines)
        let shot = ShotLog(
            timestamp: now,
            dose: dose,
            yield: self.yield,
            totalTime: totalTime,
            grindSetting: grindSetting,
            grinderZeroOffset: grinderZeroOffset,
            grinderRPM: grinderRPM,
            feedMethod: feedMethod,
            brewTemperature: brewTemperature,
            preBrewPulse: preBrewPulse,
            preBrewPause: preBrewPause,
            flowQuality: flowQuality,
            tasteBalance: tasteBalance,
            flavorNotes: flavorNotes,
            actionableNextTweak: tweak.isEmpty ? nil : tweak,
            restDaysAtBrew: bean.restDays(on: now)
        )
        context.insert(shot)
        shot.bean = bean
        equipment?.grinderZeroOffset = grinderZeroOffset
        shot.equipment = equipment

        do {
            try context.save()
        } catch {
            Self.logger.error("Failed to save shot: \(error.localizedDescription, privacy: .public)")
        }
        return shot
    }
}
