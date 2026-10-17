import Foundation

extension Double {
    /// Fixed fraction digits, no grouping: `20.0`, `-0.5`, `1200`.
    func fixed(_ digits: Int = 1) -> String {
        formatted(.number.precision(.fractionLength(digits)).grouping(.never))
    }

    /// Up to one fraction digit, trailing zero dropped: `3`, `3.5`.
    var trimmed: String {
        formatted(.number.precision(.fractionLength(0...1)).grouping(.never))
    }
}

/// Notebook-style string builders shared by rows, headers and tests.
enum ShotFormatter {
    /// Espresso: `20.0g → 48.5g (27.0s)` · Pour Over: `15.0g : 250g (2:30)`
    static func headline(
        dose: Double,
        yield yieldGrams: Double,
        time: Double,
        method: BrewMethod = .espresso
    ) -> String {
        switch method {
        case .espresso:
            "\(dose.fixed())g → \(yieldGrams.fixed())g (\(time.fixed())s)"
        case .pourOver:
            "\(dose.fixed())g : \(yieldGrams.fixed(0))g (\(drawdown(time)))"
        }
    }

    /// Formats total seconds as `m:ss` (e.g. `155` → `2:35`).
    static func drawdown(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }

    /// `G 0.5 (0pt -1) @1200` or `G 0.5 @1200`
    static func grind(_ setting: Double, zeroOffset: Int = 0, rpm: Int?) -> String {
        let clamped = max(0, setting)
        let offsetPart: String = if zeroOffset == 0 {
            ""
        } else if zeroOffset > 0 {
            " (0pt +\(zeroOffset))"
        } else {
            " (0pt \(zeroOffset))"
        }
        if let rpm { return "G \(clamped.fixed())\(offsetPart) @\(rpm)" }
        return "G \(clamped.fixed())\(offsetPart)"
    }

    /// `PB 3/5`
    static func preBrew(pulse: Double, pause: Double) -> String {
        "PB \(pulse.trimmed)/\(pause.trimmed)"
    }

    /// `Bloom 45g/45s`
    static func bloom(water: Double, pause: Double) -> String {
        "Bloom \(water.fixed(0))g/\(pause.fixed(0))s"
    }

    /// `3 Pours · Swirl`
    static func pours(count: Int, agitation: PourAgitation) -> String {
        let label = count == 1 ? "1 Pour" : "\(count) Pours"
        return "\(label) · \(agitation.shortLabel)"
    }

    /// Espresso: `1:2.40` · Pour Over: `1:16.7`
    static func ratio(_ ratio: Double, method: BrewMethod = .espresso) -> String {
        switch method {
        case .espresso: "1:\(ratio.fixed(2))"
        case .pourOver: "1:\(ratio.fixed(1))"
        }
    }

    /// `93.5°C`
    static func temperature(_ celsius: Double) -> String {
        "\(celsius.fixed())°C"
    }
}
