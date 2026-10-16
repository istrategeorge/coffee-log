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
    /// `20.0g → 48.5g (27.0s)`
    static func headline(dose: Double, yield yieldGrams: Double, time: Double) -> String {
        "\(dose.fixed())g → \(yieldGrams.fixed())g (\(time.fixed())s)"
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

    /// `1:2.40`
    static func ratio(_ ratio: Double) -> String {
        "1:\(ratio.fixed(2))"
    }

    /// `93.5°C`
    static func temperature(_ celsius: Double) -> String {
        "\(celsius.fixed())°C"
    }
}
