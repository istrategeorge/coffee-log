import SwiftUI
import SwiftData

/// Sheet for adding a new bean, re-buying a new bag of a past coffee, or editing an existing bag.
struct BeanEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \CoffeeBean.createdAt, order: .reverse) private var allBeans: [CoffeeBean]

    private let existing: CoffeeBean?

    @State private var name: String
    @State private var roaster: String
    @State private var variety: String
    @State private var process: String
    @State private var bagWeightGrams: Double
    @State private var roastDate: Date
    @State private var isFrozen: Bool
    @State private var freezeDate: Date
    @State private var isFinished: Bool
    @State private var markPreviousFinished: Bool
    @State private var pastCoffeeSearch: String = ""

    init(bean: CoffeeBean? = nil, rebuyOf template: CoffeeBean? = nil) {
        self.existing = bean
        let source = bean ?? template
        _name = State(initialValue: source?.name ?? "")
        _roaster = State(initialValue: source?.roaster ?? "")
        _variety = State(initialValue: source?.variety ?? "")
        _process = State(initialValue: source?.process ?? "Washed")
        _bagWeightGrams = State(initialValue: source?.bagWeightGrams ?? 250.0)
        // A re-bought bag gets a fresh roast date (defaults to 7 days ago), whereas editing keeps the bag's roast date.
        let defaultRoast = Calendar.current.date(byAdding: .day, value: template != nil ? -7 : -14, to: .now) ?? .now
        _roastDate = State(initialValue: bean?.roastDate ?? defaultRoast)
        _isFrozen = State(initialValue: bean?.isFrozen ?? false)
        _freezeDate = State(initialValue: bean?.freezeDate ?? .now)
        _isFinished = State(initialValue: bean?.isFinished ?? false)
        _markPreviousFinished = State(initialValue: template != nil)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !roaster.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        bagWeightGrams > 0
    }

    private var previewRestDays: Int {
        CoffeeBean.restDays(
            roastDate: roastDate,
            isFrozen: isFrozen,
            freezeDate: isFrozen ? freezeDate : nil,
            frozenDaysBanked: existing?.frozenDaysBanked ?? 0,
            isFinished: isFinished,
            finishedDate: isFinished ? (existing?.finishedDate ?? .now) : nil,
            on: .now
        )
    }

    /// Distinct coffees from history (deduplicated by name + roaster), filtered by `pastCoffeeSearch`.
    private var uniquePastCoffees: [CoffeeBean] {
        var seen = Set<String>()
        var result: [CoffeeBean] = []
        for candidate in allBeans {
            let key = "\(candidate.name.lowercased())|\(candidate.roaster.lowercased())"
            if seen.insert(key).inserted, candidate.matchesSearch(pastCoffeeSearch) {
                result.append(candidate)
            }
        }
        return result
    }

    /// Matching bags of the currently typed coffee (name + roaster).
    private var matchingBags: [CoffeeBean] {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRoaster = roaster.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedRoaster.isEmpty else { return [] }
        return allBeans.filter {
            $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame &&
            $0.roaster.caseInsensitiveCompare(trimmedRoaster) == .orderedSame
        }
    }

    /// Usual dose inferred from this bag or previous bags of the same coffee, falling back to the overall latest shot or 20.0g.
    private var inferredUsualDose: Double {
        if let dose = existing?.latestShot?.dose, dose > 0 { return dose }
        if let previousDose = matchingBags.compactMap({ $0.latestShot?.dose }).first, previousDose > 0 {
            return previousDose
        }
        if let anyDose = allBeans.compactMap({ $0.latestShot?.dose }).first, anyDose > 0 {
            return anyDose
        }
        return 20.0
    }

    private var estimatedTotalShots: Int {
        guard !isFinished else { return 0 }
        let used = existing?.usedGrams ?? 0
        let remaining = max(0, bagWeightGrams - used)
        return max(0, Int((remaining / inferredUsualDose).rounded(.down)))
    }

    var body: some View {
        NavigationStack {
            Form {
                if existing == nil && !allBeans.isEmpty {
                    rebuySection
                }

                Section("Coffee") {
                    TextField("Bean Name (e.g. Colombia Las Flores)", text: $name)
                    TextField("Roaster (e.g. Meron)", text: $roaster)
                    TextField("Variety (e.g. Bourbon Aji)", text: $variety)
                    TextField("Process", text: $process)
                    ScrollView(.horizontal) {
                        HStack(spacing: 6) {
                            ForEach(CoffeeBean.processPresets, id: \.self) { preset in
                                TagChip(title: preset, isSelected: process == preset) {
                                    process = preset
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollIndicators(.hidden)
                }

                Section {
                    HStack {
                        Text("Bag Weight")
                        Spacer()
                        TextField("250", value: $bagWeightGrams, format: .number.precision(.fractionLength(0...1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.body.weight(.semibold).monospacedDigit())
                            .frame(width: 90)
                        Text("g")
                            .foregroundStyle(.secondary)
                    }

                    ScrollView(.horizontal) {
                        HStack(spacing: 6) {
                            ForEach(CoffeeBean.bagWeightPresets, id: \.self) { weight in
                                TagChip(
                                    title: "\(Int(weight))g",
                                    isSelected: abs(bagWeightGrams - weight) < 0.5
                                ) {
                                    bagWeightGrams = weight
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollIndicators(.hidden)

                    if existing != nil {
                        Toggle(isOn: $isFinished.animation()) {
                            Label("Bag Finished (Empty)", systemImage: isFinished ? "checkmark.seal.fill" : "shippingbox")
                        }
                    } else if matchingBags.contains(where: { !$0.isFinished }) {
                        Toggle(isOn: $markPreviousFinished) {
                            Label("Mark Previous Bag as Done", systemImage: "checkmark.circle")
                        }
                    }
                } header: {
                    Text("Bag Weight & Shot Estimate")
                } footer: {
                    HStack(spacing: 6) {
                        Image(systemName: isFinished ? "checkmark.seal.fill" : "cup.and.saucer.fill")
                            .foregroundStyle(isFinished ? Color.green : Color.accentColor)
                        if let existing, isFinished {
                            Text("Bag marked done (\(existing.usedGrams.fixed(0))g logged of \(bagWeightGrams.fixed(0))g)")
                        } else if let existing, existing.usedGrams > 0 {
                            Text("~\(estimatedTotalShots) doses left (\(max(0, bagWeightGrams - existing.usedGrams).fixed(0))g left at \(inferredUsualDose.fixed())g dose)")
                        } else {
                            Text("~\(estimatedTotalShots) doses in bag (based on \(inferredUsualDose.fixed())g usual dose)")
                        }
                    }
                    .font(.footnote.weight(.medium))
                    .padding(.top, 4)
                }

                Section {
                    DatePicker("Roast Date", selection: $roastDate, in: ...Date.now, displayedComponents: .date)
                    Toggle(isOn: $isFrozen.animation()) {
                        Label("Stored in Freezer", systemImage: isFrozen ? "snowflake" : "thermometer.medium")
                    }
                    if isFrozen {
                        DatePicker("Frozen On", selection: $freezeDate, in: roastDate...Date.now, displayedComponents: .date)
                    }
                } header: {
                    Text("Rest & Storage")
                } footer: {
                    HStack {
                        Text("Effective rest:")
                        RestBadge(days: previewRestDays, isFrozen: isFrozen, isFinished: isFinished, compact: true)
                    }
                    .padding(.top, 4)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
    }

    private var navigationTitle: String {
        if existing != nil { return "Edit Bag" }
        let nextBagNum = matchingBags.count + 1
        return nextBagNum > 1 ? "New Bag (#\(nextBagNum))" : "New Bag"
    }

    private var rebuySection: some View {
        Section {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search past coffees by name, roaster, variety…", text: $pastCoffeeSearch)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !pastCoffeeSearch.isEmpty {
                    Button {
                        pastCoffeeSearch = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if uniquePastCoffees.isEmpty {
                Text("No matching past coffees.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(uniquePastCoffees) { past in
                            let isSelected = name.caseInsensitiveCompare(past.name) == .orderedSame
                                && roaster.caseInsensitiveCompare(past.roaster) == .orderedSame
                            Button {
                                applyTemplate(past)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(past.name)
                                        .font(.caption.weight(.semibold))
                                        .lineLimit(1)
                                    Text("\(past.roaster) · \(past.variety)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(isSelected ? Color.accentColor.opacity(0.18) : Color(.tertiarySystemFill))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
        } header: {
            Text("Re-buy from Past Coffees")
        } footer: {
            if !matchingBags.isEmpty {
                Text("Creates Bag #\(matchingBags.count + 1) of \(name) and carries over your last dialed-in recipe.")
                    .foregroundStyle(.tint)
            }
        }
    }

    private func applyTemplate(_ template: CoffeeBean) {
        withAnimation(.snappy) {
            name = template.name
            roaster = template.roaster
            variety = template.variety
            process = template.process
            bagWeightGrams = template.bagWeightGrams
            markPreviousFinished = true
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRoaster = roaster.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedVariety = variety.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedProcess = process.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existing {
            existing.name = trimmedName
            existing.roaster = trimmedRoaster
            existing.variety = trimmedVariety
            existing.process = trimmedProcess
            existing.bagWeightGrams = max(0, bagWeightGrams)
            existing.roastDate = roastDate
            if isFrozen {
                existing.isFrozen = true
                existing.freezeDate = freezeDate
            } else if existing.isFrozen {
                existing.thaw()
            }
            if isFinished {
                existing.markFinished()
            } else if existing.isFinished {
                existing.reopen()
            }
        } else {
            if markPreviousFinished {
                for oldBag in matchingBags where !oldBag.isFinished {
                    oldBag.markFinished()
                }
            }
            let nextBagNumber = matchingBags.count + 1
            let bean = CoffeeBean(
                name: trimmedName,
                roaster: trimmedRoaster,
                variety: trimmedVariety,
                process: trimmedProcess,
                roastDate: roastDate,
                bagWeightGrams: max(0, bagWeightGrams),
                bagNumber: nextBagNumber,
                isFrozen: isFrozen,
                freezeDate: isFrozen ? freezeDate : nil,
                isActive: true
            )
            context.insert(bean)
            context.activate(bean)
        }
        try? context.save()
        dismiss()
    }
}
