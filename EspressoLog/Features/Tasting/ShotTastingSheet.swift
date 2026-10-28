import SwiftUI
import SwiftData

/// "How was the cup?" Opened from a saved brew to update flow, balance, notes and the next tweak
/// once the cup is finished. The recipe itself is shown read-only for context.
struct ShotTastingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var model: ShotTastingViewModel
    @State private var newTag = ""
    @State private var didSave = false

    init(shot: ShotLog) {
        _model = State(initialValue: ShotTastingViewModel(shot: shot))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    recipeSummary
                    flowSection
                    balanceSection
                    insightsSection
                    flavorSection
                    tweakSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .animation(.snappy, value: model.insights)
            }
            .scrollDismissesKeyboard(.interactively)
            .paperBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.paper, for: .navigationBar)
            .toolbar { toolbarContent }
            .sensoryFeedback(.success, trigger: didSave)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.paper)
        .interactiveDismissDisabled(model.hasChanges)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
                .foregroundStyle(Palette.ink)
        }
        ToolbarItem(placement: .principal) {
            VStack(spacing: 1) {
                Text("How was the cup?")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                Text(model.shot.bean?.name ?? model.method.label)
                    .font(.caption)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save", action: save)
                .fontWeight(.bold)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .disabled(!model.canSave)
        }
    }

    // MARK: Sections

    private var recipeSummary: some View {
        let shot = model.shot
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Day \(shot.restDaysAtBrew) · \(shot.timestamp, format: .dateTime.day().month(.abbreviated).hour().minute())")
                        .font(.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                    BrewMethodBadge(method: shot.brewMethod, dripper: shot.dripper)
                }
                Text(ShotFormatter.headline(dose: shot.dose, yield: shot.yield, time: shot.totalTime, method: shot.brewMethod))
                    .font(.mono(.body, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text(shot.notebookLine)
                    .font(.mono(.caption))
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .paperCard()
        .accessibilityElement(children: .combine)
    }

    private var flowSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(model.method == .pourOver ? "Drawdown & Bed" : "Flow")
                .padding(.horizontal, 4)
            FlowPicker(method: model.method, selection: $model.flowQuality)
        }
    }

    private var balanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Balance")
                .padding(.horizontal, 4)
            BalanceSegmentedControl(selection: $model.tasteBalance)
        }
    }

    @ViewBuilder
    private var insightsSection: some View {
        let insights = model.insights
        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("Insights")
                    .padding(.horizontal, 4)
                ForEach(insights) { insight in
                    InsightCallout(insight: insight)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
            }
        }
    }

    private var flavorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Flavor Notes")
                .padding(.horizontal, 4)
            FlowLayout(spacing: 8) {
                ForEach(allTags, id: \.self) { tag in
                    TagChip(title: tag, isSelected: model.flavorNotes.contains(tag)) {
                        model.toggleTag(tag)
                    }
                }
            }
            HStack {
                Image(systemName: "plus.circle")
                    .foregroundStyle(Palette.inkSecondary)
                TextField("Add note…", text: $newTag)
                    .submitLabel(.done)
                    .onSubmit {
                        model.addTag(newTag)
                        newTag = ""
                    }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .paperCard(cornerRadius: 14)
        }
    }

    private var allTags: [String] {
        let extra = model.flavorNotes.filter { !model.flavorSuggestions.contains($0) }
        return model.flavorSuggestions + extra
    }

    private var tweakSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Next Tweak")
                .padding(.horizontal, 4)
            TextField("e.g. Go coarser +0.5", text: $model.nextTweak, axis: .vertical)
                .lineLimit(1...3)
                .padding(14)
                .paperCard(cornerRadius: 14)

            let suggestions = model.suggestedTweaks
            if !suggestions.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { tweak in
                            TagChip(title: tweak, isSelected: model.nextTweak.contains(tweak)) {
                                model.applyTweak(tweak)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: Actions

    private func save() {
        // Pick up a note still sitting in the field.
        if !newTag.isEmpty {
            model.addTag(newTag)
            newTag = ""
        }
        guard model.save(in: context) else { return }
        didSave.toggle()
        dismiss()
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query(sort: \ShotLog.timestamp, order: .reverse) var shots: [ShotLog]

    Color.clear.sheet(isPresented: .constant(true)) {
        if let shot = shots.first {
            ShotTastingSheet(shot: shot)
        }
    }
}
