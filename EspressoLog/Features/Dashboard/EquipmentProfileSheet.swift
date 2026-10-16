import SwiftUI
import SwiftData

/// Sheet for editing the active equipment setup (Machine, Grinder, Basket, Puck Screen).
struct EquipmentProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    private let existing: EquipmentProfile?

    @State private var machineName: String
    @State private var grinderName: String
    @State private var grinderZeroOffset: Int
    @State private var basket: String
    @State private var puckScreen: String

    private static let offsetPresets = [-3, -2, -1, 0, 1, 2, 3]

    private static let basketPresets = [
        "Normcore 20g High Extraction",
        "LM 17g Stock",
        "VST 18g",
        "VST 20g",
        "Weber Unibasket 20g",
        "Pullman 876 19-22g",
    ]

    private static let puckScreenPresets = ["1.7mm", "0.8mm", "0.2mm Mesh", "Paper Top", "None"]

    init(profile: EquipmentProfile? = nil) {
        self.existing = profile
        let seed = profile ?? EquipmentProfile.makeDefault()
        _machineName = State(initialValue: seed.machineName)
        _grinderName = State(initialValue: seed.grinderName)
        _grinderZeroOffset = State(initialValue: seed.grinderZeroOffset)
        _basket = State(initialValue: seed.basket)
        _puckScreen = State(initialValue: seed.puckScreen ?? "1.7mm")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Machine") {
                        TextField("La Marzocco Linea Micra", text: $machineName)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Grinder") {
                        TextField("Timemore Sculptor 078s", text: $grinderName)
                            .multilineTextAlignment(.trailing)
                    }
                    Stepper(value: $grinderZeroOffset, in: -10...10) {
                        HStack {
                            Text("0-Point Offset")
                            Spacer()
                            Text(grinderZeroOffset > 0 ? "+\(grinderZeroOffset)" : "\(grinderZeroOffset)")
                                .font(.body.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.tint)
                        }
                    }
                    ScrollView(.horizontal) {
                        HStack(spacing: 6) {
                            ForEach(Self.offsetPresets, id: \.self) { offset in
                                let label = offset > 0 ? "+\(offset)" : "\(offset)"
                                TagChip(title: "0pt \(label)", isSelected: grinderZeroOffset == offset) {
                                    grinderZeroOffset = offset
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollIndicators(.hidden)
                } header: {
                    Text("Hardware")
                } footer: {
                    Text("Integer offset of the relocated zero pin on your grinder. Actual grind adjustments stay positive (0.0 – 10.0).")
                }

                Section("Basket") {
                    TextField("Basket", text: $basket)
                    ScrollView(.horizontal) {
                        HStack(spacing: 6) {
                            ForEach(Self.basketPresets, id: \.self) { preset in
                                TagChip(title: preset, isSelected: basket == preset) {
                                    basket = preset
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollIndicators(.hidden)
                }

                Section("Puck Screen") {
                    TextField("Puck Screen (optional)", text: $puckScreen)
                    ScrollView(.horizontal) {
                        HStack(spacing: 6) {
                            ForEach(Self.puckScreenPresets, id: \.self) { preset in
                                TagChip(title: preset, isSelected: puckScreen == preset) {
                                    puckScreen = preset
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Equipment Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func save() {
        let trimmedMachine = machineName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGrinder = grinderName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBasket = basket.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedScreen = puckScreen.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedScreen: String? = trimmedScreen.isEmpty ? nil : trimmedScreen

        if let existing, existing.shots.isEmpty {
            existing.machineName = trimmedMachine
            existing.grinderName = trimmedGrinder
            existing.grinderZeroOffset = grinderZeroOffset
            existing.basket = trimmedBasket
            existing.puckScreen = normalizedScreen
            context.activate(existing)
        } else if let existing,
                  existing.machineName == trimmedMachine,
                  existing.grinderName == trimmedGrinder,
                  existing.grinderZeroOffset == grinderZeroOffset,
                  existing.basket == trimmedBasket,
                  existing.puckScreen == normalizedScreen {
            context.activate(existing)
        } else {
            // Preserve the equipment snapshot on earlier pulls by activating a new profile.
            let profile = EquipmentProfile(
                machineName: trimmedMachine,
                grinderName: trimmedGrinder,
                grinderZeroOffset: grinderZeroOffset,
                basket: trimmedBasket,
                puckScreen: normalizedScreen,
                isActive: true
            )
            context.insert(profile)
            context.activate(profile)
        }
        try? context.save()
        dismiss()
    }
}
