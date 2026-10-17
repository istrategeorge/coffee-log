import Foundation
import SwiftData
import OSLog

/// Numeric inputs driven by the in-app keypad, in "Next" order.
enum NumericField: Int, CaseIterable, Identifiable, Sendable {
    case dose, yield, time, temperature, pulse, pause, rpm

    var id: Int { rawValue }

    var label: String { label(for: .espresso) }

    func label(for method: BrewMethod) -> String {
        switch self {
        case .dose: "Dose"
        case .yield: method == .pourOver ? "Water" : "Yield"
        case .time: method == .pourOver ? "Drawdown" : "Time"
        case .temperature: "Temp"
        case .pulse: method == .pourOver ? "Bloom H₂O" : "PB On"
        case .pause: method == .pourOver ? "Bloom Wait" : "PB Wait"
        case .rpm: "RPM"
        }
    }

    var unit: String { unit(for: .espresso) }

    func unit(for method: BrewMethod) -> String {
        switch self {
        case .dose, .yield: "g"
        case .pulse: method == .pourOver ? "g" : "s"
        case .time, .pause: "s"
        case .temperature: "°C"
        case .rpm: ""
        }
    }

    var fractionDigits: Int { self == .rpm ? 0 : 1 }

    func maxIntegerDigits(for method: BrewMethod) -> Int {
        switch self {
        case .yield: method == .pourOver ? 4 : 3
        case .time: 3
        case .pulse, .pause: method == .pourOver ? 3 : 2
        case .rpm: 4
        default: 2
        }
    }

    func range(for method: BrewMethod) -> ClosedRange<Double> {
        switch self {
        case .dose: method == .pourOver ? 5...60 : 1...40
        case .yield: method == .pourOver ? 50...1000 : 1...150
        case .time: method == .pourOver ? 30...600 : 1...180
        case .temperature: 80...100
        case .pulse: method == .pourOver ? 0...250 : 0...30
        case .pause: method == .pourOver ? 0...180 : 0...30
        case .rpm: 0...2500
        }
    }

    func nudgeStep(for method: BrewMethod) -> Double {
        switch self {
        case .dose: method == .pourOver ? 0.5 : 0.1
        case .yield: method == .pourOver ? 5.0 : 0.5
        case .time: method == .pourOver ? 5.0 : 1.0
        case .temperature: 0.5
        case .pulse, .pause: method == .pourOver ? 5.0 : 0.5
        case .rpm: 100
        }
    }

    var next: NumericField? { NumericField(rawValue: rawValue + 1) }

    func clamp(_ value: Double, for method: BrewMethod = .espresso) -> Double {
        let scale = pow(10, Double(fractionDigits))
        let rounded = (value * scale).rounded() / scale
        let bounds = range(for: method)
        return min(max(rounded, bounds.lowerBound), bounds.upperBound)
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
        "Caramel", "Chocolate", "Tea-like", "Lime", "Bergamot", "Jasmine",
    ]
    static let dripperPresets = [
        "Hario V60 01",
        "Hario V60 02",
        "Origami S",
        "Orea V4",
        "Kalita Wave 185",
        "Hario Switch",
        "Chemex",
        "AeroPress",
    ]
    /// Positive grind wheel range in tenths: 0.0 … 16.0 (covers both espresso and filter settings).
    static let grindScale: ClosedRange<Int> = 0...160
    static let decimalSeparator = Locale.current.decimalSeparator ?? "."

    private static let logger = Logger(subsystem: "EspressoLog", category: "ShotLogging")

    // MARK: Context

    let bean: CoffeeBean
    let equipment: EquipmentProfile?
    private let fallbackTemplate: ShotLog?
    /// Values the draft was pre-filled from (last shot of this bean for the selected brew method).
    private(set) var template: ShotSnapshot?
    /// The "Next" note written on this bean's previous brew of the selected method.
    private(set) var previousTweak: String?
    let restDays: Int
    private(set) var grindRange: ClosedRange<Int> = ShotLoggingViewModel.grindScale
    let flavorSuggestions: [String]
    private var baselineFeed: FeedMethod = .slowFeed

    // MARK: Draft

    var brewMethod: BrewMethod
    var dose: Double = 18.0
    var yield: Double = 36.0
    var totalTime: Double = 28.0
    /// Positive grind stored in tenths (0 … 160 → 0.0 … 16.0).
    var grindTenths: Int = 10
    /// Integer offset of the grinder's relocated 0-point (e.g. -2, -1, 0, +1, +2).
    var grinderZeroOffset: Int = 0
    var grinderRPM: Int?
    var feedMethod: FeedMethod = .slowFeed
    var brewTemperature: Double = 93.0
    var preBrewPulse: Double = 0
    var preBrewPause: Double = 0
    /// Pour Over fields
    var dripper: String = "Hario V60 01"
    var bloomWater: Double = 45.0
    var pourCount: Int = 3
    var agitation: PourAgitation = .moderateSwirl

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

    init(
        bean: CoffeeBean,
        equipment: EquipmentProfile?,
        fallbackTemplate: ShotLog? = nil,
        initialMethod: BrewMethod? = nil,
        now: Date = .now
    ) {
        self.bean = bean
        self.equipment = equipment
        self.fallbackTemplate = fallbackTemplate
        self.restDays = bean.restDays(on: now)

        let history = bean.shotsNewestFirst
        let resolvedMethod = initialMethod ?? (history.first ?? fallbackTemplate)?.brewMethod ?? .espresso
        self.brewMethod = resolvedMethod
        self.flavorSuggestions = Self.makeFlavorSuggestions(from: history)

        applyTemplate(for: resolvedMethod)
    }

    /// Switches between Espresso and Pour Over, loading the latest recipe for that method.
    func setBrewMethod(_ newMethod: BrewMethod) {
        commitBuffer()
        guard newMethod != brewMethod else { return }
        brewMethod = newMethod
        applyTemplate(for: newMethod)
    }

    private func applyTemplate(for method: BrewMethod) {
        let templateShot = bean.latestShot(for: method)
            ?? (fallbackTemplate?.brewMethod == method ? fallbackTemplate : nil)
        let snap = templateShot?.snapshot
        template = snap
        previousTweak = templateShot?.actionableNextTweak

        if let snap {
            dose = snap.dose
            self.yield = snap.yield
            totalTime = snap.totalTime
            let tenths = max(0, Int((snap.grindSetting * 10).rounded()))
            grindTenths = tenths
            grindRange = 0...max(Self.grindScale.upperBound, tenths)
            grinderZeroOffset = snap.grinderZeroOffset
            grinderRPM = snap.grinderRPM
            feedMethod = snap.feedMethod
            baselineFeed = snap.feedMethod
            brewTemperature = snap.brewTemperature
            preBrewPulse = snap.preBrewPulse
            preBrewPause = snap.preBrewPause
            dripper = snap.dripper ?? equipment?.defaultDripper ?? "Hario V60 01"
            bloomWater = snap.bloomWater > 0 ? snap.bloomWater : (snap.dose * 3).rounded()
            pourCount = max(1, snap.pourCount)
            agitation = snap.agitation
            flowQuality = snap.flowQuality
            tasteBalance = snap.tasteBalance
        } else if method == .pourOver {
            dose = 15.0
            self.yield = 250.0
            totalTime = 165.0
            grindTenths = 65
            grindRange = Self.grindScale
            grinderZeroOffset = equipment?.grinderZeroOffset ?? 0
            grinderRPM = 800
            feedMethod = .slowFeed
            baselineFeed = .slowFeed
            brewTemperature = 93.0
            preBrewPulse = 0
            preBrewPause = 45.0
            dripper = equipment?.defaultDripper ?? "Hario V60 01"
            bloomWater = 45.0
            pourCount = 3
            agitation = .moderateSwirl
            flowQuality = .smoothCone
            tasteBalance = nil
        } else {
            dose = 18.0
            self.yield = 36.0
            totalTime = 28.0
            grindTenths = 10
            grindRange = Self.grindScale
            grinderZeroOffset = equipment?.grinderZeroOffset ?? 0
            grinderRPM = nil
            feedMethod = .slowFeed
            baselineFeed = .slowFeed
            brewTemperature = 93.0
            preBrewPulse = 0
            preBrewPause = 0
            dripper = equipment?.defaultDripper ?? "Hario V60 01"
            bloomWater = 45.0
            pourCount = 3
            agitation = .moderateSwirl
            flowQuality = .smoothCone
            tasteBalance = nil
        }
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
            brewMethod: brewMethod,
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
            dripper: brewMethod == .pourOver ? dripper : nil,
            bloomWater: bloomWater,
            pourCount: pourCount,
            agitation: agitation,
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
        case .pulse: brewMethod == .pourOver ? template.bloomWater : template.preBrewPulse
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
        case .pulse: brewMethod == .pourOver ? bloomWater : preBrewPulse
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
        let val = value(for: field)
        if brewMethod == .pourOver, (field == .yield || field == .time || field == .pulse || field == .pause),
           abs(val.rounded() - val) < 0.05 {
            return val.fixed(0)
        }
        return val.fixed(field.fractionDigits)
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
                guard text.count < field.maxIntegerDigits(for: brewMethod) else { return }
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
            grinderRPM = brewMethod == .pourOver ? 800 : 1000
            return
        }
        let next = value(for: field) + Double(direction) * field.nudgeStep(for: brewMethod)
        setValue(field.clamp(next, for: brewMethod), for: field)
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
        setValue(field.clamp(parsed, for: brewMethod), for: field)
    }

    private func setValue(_ newValue: Double, for field: NumericField) {
        switch field {
        case .dose: dose = newValue
        case .yield: self.yield = newValue
        case .time: totalTime = newValue
        case .temperature: brewTemperature = newValue
        case .pulse:
            if brewMethod == .pourOver {
                bloomWater = newValue
            } else {
                preBrewPulse = newValue
            }
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
        let trimmedDripper = dripper.trimmingCharacters(in: .whitespacesAndNewlines)
        let shot = ShotLog(
            timestamp: now,
            brewMethod: brewMethod,
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
            dripper: brewMethod == .pourOver ? (trimmedDripper.isEmpty ? "Hario V60 01" : trimmedDripper) : nil,
            bloomWater: bloomWater,
            pourCount: pourCount,
            agitation: agitation,
            flowQuality: flowQuality,
            tasteBalance: tasteBalance,
            flavorNotes: flavorNotes,
            actionableNextTweak: tweak.isEmpty ? nil : tweak,
            restDaysAtBrew: bean.restDays(on: now)
        )
        context.insert(shot)
        shot.bean = bean
        equipment?.grinderZeroOffset = grinderZeroOffset
        if brewMethod == .pourOver, !trimmedDripper.isEmpty {
            equipment?.defaultDripper = trimmedDripper
        }
        shot.equipment = equipment

        do {
            try context.save()
        } catch {
            Self.logger.error("Failed to save shot: \(error.localizedDescription, privacy: .public)")
        }
        return shot
    }
}
