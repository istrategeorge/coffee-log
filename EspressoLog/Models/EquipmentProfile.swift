import Foundation
import SwiftData

/// Machine + grinder + basket combination a shot was pulled on.
@Model
final class EquipmentProfile {
    var machineName: String = ""
    var grinderName: String = ""
    /// Integer offset of the grinder's relocated 0-point (e.g. -2, -1, 0, +1, +2).
    var grinderZeroOffset: Int = 0
    var basket: String = ""
    var puckScreen: String?
    /// Default pour over brewer (e.g. "Hario V60 01", "Orea V4", "Origami Air").
    var defaultDripper: String = "Hario V60 01"
    var isActive: Bool = false
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \ShotLog.equipment)
    var shots: [ShotLog] = []

    init(
        machineName: String,
        grinderName: String,
        grinderZeroOffset: Int = 0,
        basket: String,
        puckScreen: String? = nil,
        defaultDripper: String = "Hario V60 01",
        isActive: Bool = false
    ) {
        self.machineName = machineName
        self.grinderName = grinderName
        self.grinderZeroOffset = grinderZeroOffset
        self.basket = basket
        self.puckScreen = puckScreen
        self.defaultDripper = defaultDripper
        self.isActive = isActive
        self.createdAt = .now
    }
}

extension EquipmentProfile {
    static func makeDefault() -> EquipmentProfile {
        EquipmentProfile(
            machineName: "La Marzocco Linea Micra",
            grinderName: "Timemore Sculptor 078s",
            grinderZeroOffset: -1,
            basket: "Normcore 20g High Extraction",
            puckScreen: "1.7mm",
            defaultDripper: "Hario V60 01"
        )
    }

    var formattedZeroOffset: String {
        grinderZeroOffset > 0 ? "+\(grinderZeroOffset)" : "\(grinderZeroOffset)"
    }

    var grinderWithOffset: String {
        guard !grinderName.isEmpty else { return "" }
        return grinderZeroOffset == 0
            ? grinderName
            : "\(grinderName) (0pt \(formattedZeroOffset))"
    }

    /// One-line summary, e.g. "Timemore Sculptor 078s (0pt -1) · Normcore 20g · PS 1.7mm · V60".
    var summary: String {
        var parts = [grinderWithOffset, basket]
        if let puckScreen, !puckScreen.isEmpty, puckScreen.lowercased() != "none" {
            parts.append("PS \(puckScreen)")
        }
        if !defaultDripper.isEmpty {
            parts.append(defaultDripper)
        }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// Full hardware badge for individual shot rows.
    var fullLine: String {
        fullLine(for: .espresso)
    }

    func fullLine(for method: BrewMethod, dripper: String? = nil) -> String {
        switch method {
        case .espresso:
            var parts = [machineName, grinderWithOffset, basket]
            if let puckScreen, !puckScreen.isEmpty, puckScreen.lowercased() != "none" {
                parts.append("PS \(puckScreen)")
            }
            return parts.filter { !$0.isEmpty }.joined(separator: " · ")
        case .pourOver:
            let brewer = (dripper?.isEmpty == false ? dripper : nil) ?? (defaultDripper.isEmpty ? "Pour Over" : defaultDripper)
            return [brewer, grinderWithOffset].filter { !$0.isEmpty }.joined(separator: " · ")
        }
    }
}
