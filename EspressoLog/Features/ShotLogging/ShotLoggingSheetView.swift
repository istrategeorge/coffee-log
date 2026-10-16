import SwiftUI
import SwiftData

/// Rapid "New Shot" sheet. Everything is pre-filled from the previous pull of this bean,
/// so a typical log is: tap Yield → type → tap Time → type → tap balance → Save.
struct ShotLoggingSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var model: ShotLoggingViewModel
    @State private var newTag = ""
    @State private var didSave = false
    @FocusState private var focusedText: TextInput?

    private enum TextInput: Hashable { case tag, tweak }

    init(bean: CoffeeBean, equipment: EquipmentProfile?, fallbackTemplate: ShotLog? = nil) {
        _model = State(initialValue: ShotLoggingViewModel(
            bean: bean,
            equipment: equipment,
            fallbackTemplate: fallbackTemplate
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    previousTweakBanner
                    measurementsSection
                    GrindDial(
                        tenths: $model.grindTenths,
                        zeroOffset: $model.grinderZeroOffset,
                        range: model.grindRange,
                        isChanged: model.isGrindChanged
                    )
                    feedSection
                    flowSection
                    balanceSection
                    insightsSection
                    flavorSection
                    tweakSection
                }
                .padding()
                .animation(.snappy, value: model.insights)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .safeAreaInset(edge: .bottom, spacing: 0) { keypad }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: model.keyPressCount)
            .sensoryFeedback(.success, trigger: didSave)
            .onChange(of: focusedText) { _, newValue in
                if newValue != nil { withAnimation(.snappy) { model.select(nil) } }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .principal) {
            VStack(spacing: 0) {
                Text(model.bean.name)
                    .font(.headline)
                    .lineLimit(1)
                Text("Rest Day \(model.restDays)\(model.bean.isFrozen ? " · frozen" : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save", action: save)
                .fontWeight(.semibold)
                .disabled(!model.canSave)
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var previousTweakBanner: some View {
        if let tweak = model.previousTweak, !tweak.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "arrow.turn.down.right")
                    .foregroundStyle(.tint)
                Text("Last time:")
                    .foregroundStyle(.secondary)
                Text(tweak)
                    .fontWeight(.semibold)
                Spacer(minLength: 0)
            }
            .font(.subheadline)
            .padding(12)
            .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var measurementsSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                tile(.dose)
                tile(.yield, caption: ShotFormatter.ratio(model.ratio))
                tile(.time, caption: "FP \(model.fullPressureTime.fixed())s")
            }
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                tile(.temperature, compact: true)
                tile(.pulse, compact: true)
                tile(.pause, compact: true)
                tile(.rpm, compact: true)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func tile(_ field: NumericField, caption: String? = nil, compact: Bool = false) -> some View {
        MeasurementTile(
            field: field,
            text: model.displayText(for: field),
            caption: caption,
            isActive: model.activeField == field,
            isChanged: model.isChanged(field),
            compact: compact
        ) {
            focusedText = nil
            withAnimation(.snappy) { model.select(field) }
        }
    }

    private var feedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $model.isSlowFeed) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.feedMethod.label)
                            .font(.headline)
                        Text(model.feedMethod.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: model.feedMethod.symbol)
                        .foregroundStyle(.tint)
                        .contentTransition(.symbolEffect(.replace))
                }
            }

            // Contextual hint lives right under the toggle that triggered it.
            if let hint = model.insights.first(where: { $0.rule.isFeedHint }) {
                InsightCallout(insight: hint)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .cardBackground()
        .animation(.snappy, value: model.feedMethod)
        .sensoryFeedback(.selection, trigger: model.feedMethod)
    }

    private var flowSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Flow")
            HStack(spacing: 8) {
                ForEach(FlowQuality.allCases) { flow in
                    let isSelected = model.flowQuality == flow
                    Button {
                        withAnimation(.snappy) { model.flowQuality = flow }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: flow.symbol)
                                .font(.headline)
                            Text(flow.label)
                                .font(.caption2.weight(.medium))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(isSelected ? flow.tint : Color.secondary)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isSelected ? flow.tint.opacity(0.15) : Color(.tertiarySystemFill))
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .sensoryFeedback(.selection, trigger: model.flowQuality)
        }
    }

    private var balanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel("Balance")
                Spacer()
                if model.tasteBalance == nil {
                    Text("Required")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                }
            }
            BalanceSegmentedControl(selection: $model.tasteBalance)
        }
    }

    @ViewBuilder
    private var insightsSection: some View {
        let insights = model.insights.filter { !$0.rule.isFeedHint }
        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("Insights")
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
            FlowLayout(spacing: 8) {
                ForEach(allTags, id: \.self) { tag in
                    TagChip(title: tag, isSelected: model.flavorNotes.contains(tag)) {
                        model.toggleTag(tag)
                    }
                }
            }
            HStack {
                Image(systemName: "plus.circle")
                    .foregroundStyle(.secondary)
                TextField("Add note…", text: $newTag)
                    .focused($focusedText, equals: .tag)
                    .submitLabel(.done)
                    .onSubmit {
                        model.addTag(newTag)
                        newTag = ""
                    }
            }
            .padding(10)
            .cardBackground(cornerRadius: 12)
        }
    }

    private var allTags: [String] {
        let extra = model.flavorNotes.filter { !model.flavorSuggestions.contains($0) }
        return model.flavorSuggestions + extra
    }

    private var tweakSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Next Tweak")
            TextField("e.g. Go coarser +0.5", text: $model.nextTweak, axis: .vertical)
                .focused($focusedText, equals: .tweak)
                .lineLimit(1...3)
                .padding(12)
                .cardBackground(cornerRadius: 12)

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
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: Keypad

    @ViewBuilder
    private var keypad: some View {
        if let field = model.activeField, focusedText == nil {
            NumericKeypad(
                field: field,
                onKey: { model.press($0) },
                onNudge: { model.nudge($0) },
                onNext: { withAnimation(.snappy) { model.advance() } },
                onDone: { withAnimation(.snappy) { model.select(nil) } }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: Actions

    private func save() {
        guard model.save(in: context) != nil else { return }
        didSave.toggle()
        dismiss()
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query(sort: \CoffeeBean.createdAt) var beans: [CoffeeBean]
    @Previewable @Query var profiles: [EquipmentProfile]

    Color.clear.sheet(isPresented: .constant(true)) {
        if let bean = beans.first {
            ShotLoggingSheetView(bean: bean, equipment: profiles.first)
        }
    }
}
