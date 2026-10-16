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
        isActive: Bool = false
    ) {
        self.machineName = machineName
        self.grinderName = grinderName
        self.grinderZeroOffset = grinderZeroOffset
        self.basket = basket
        self.puckScreen = puckScreen
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
            puckScreen: "1.7mm"
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

    /// One-line summary, e.g. "Timemore Sculptor 078s (0pt -1) · Normcore 20g · PS 1.7mm".
    var summary: String {
        var parts = [grinderWithOffset, basket]
        if let puckScreen, !puckScreen.isEmpty, puckScreen.lowercased() != "none" {
            parts.append("PS \(puckScreen)")
        }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// Full hardware badge for individual shot rows: "Machine · Grinder (0pt -1) · Basket · PS 1.7mm".
    var fullLine: String {
        var parts = [machineName, grinderWithOffset, basket]
        if let puckScreen, !puckScreen.isEmpty, puckScreen.lowercased() != "none" {
            parts.append("PS \(puckScreen)")
        }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
