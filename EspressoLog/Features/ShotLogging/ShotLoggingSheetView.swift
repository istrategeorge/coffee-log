import SwiftUI
import SwiftData

/// Rapid "New Brew" sheet. Everything is pre-filled from the previous brew of the selected method,
/// so a typical log is: tap Yield/Water → type → tap Time/Drawdown → type → tap balance → Save.
struct ShotLoggingSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var model: ShotLoggingViewModel
    @State private var newTag = ""
    @State private var didSave = false
    @FocusState private var focusedText: TextInput?

    private enum TextInput: Hashable { case tag, tweak }

    init(
        bean: CoffeeBean,
        equipment: EquipmentProfile?,
        fallbackTemplate: ShotLog? = nil,
        initialMethod: BrewMethod? = nil
    ) {
        _model = State(initialValue: ShotLoggingViewModel(
            bean: bean,
            equipment: equipment,
            fallbackTemplate: fallbackTemplate,
            initialMethod: initialMethod
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    brewMethodSwitcher
                    previousTweakBanner
                    measurementsSection
                    if model.brewMethod == .pourOver {
                        pourOverSection
                    }
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
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .animation(.snappy, value: model.brewMethod)
                .animation(.snappy, value: model.insights)
            }
            .scrollDismissesKeyboard(.interactively)
            .paperBackground()
            .safeAreaInset(edge: .bottom, spacing: 0) { keypad }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.paper, for: .navigationBar)
            .toolbar { toolbarContent }
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: model.keyPressCount)
            .sensoryFeedback(.success, trigger: didSave)
            .onChange(of: focusedText) { _, newValue in
                if newValue != nil { withAnimation(.snappy) { model.select(nil) } }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.paper)
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
                Text(model.bean.name)
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text("Rest Day \(model.restDays)\(model.bean.isFrozen ? " · frozen" : "") · \(model.brewMethod.label)")
                    .font(.caption)
                    .foregroundStyle(Palette.inkSecondary)
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

    private var brewMethodSwitcher: some View {
        HStack(spacing: 4) {
            ForEach(BrewMethod.allCases) { method in
                let isSelected = model.brewMethod == method
                Button {
                    focusedText = nil
                    withAnimation(.snappy) {
                        model.setBrewMethod(method)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: method.symbol)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isSelected ? method.tint : Palette.inkSecondary)
                        Text(method.label)
                            .font(.subheadline.weight(isSelected ? .bold : .semibold))
                            .foregroundStyle(isSelected ? Palette.ink : Palette.inkSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Palette.card)
                                .shadow(color: .black.opacity(0.12), radius: 1.5, y: 1)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Palette.control, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .sensoryFeedback(.selection, trigger: model.brewMethod)
    }

    @ViewBuilder
    private var previousTweakBanner: some View {
        if let tweak = model.previousTweak, !tweak.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "arrow.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.tint)
                (Text("Last \(model.brewMethod.label.lowercased()) tweak: ").fontWeight(.bold)
                    + Text(tweak))
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 0)
            }
            .font(.subheadline)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var measurementsSection: some View {
        let timeCaption = model.brewMethod == .pourOver
            ? ShotFormatter.drawdown(model.totalTime)
            : "FP \(model.fullPressureTime.fixed())s"

        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                tile(.dose, caption: "-\(model.dose.fixed())g bag")
                tile(.yield, caption: ShotFormatter.ratio(model.ratio, method: model.brewMethod))
                tile(.time, caption: timeCaption)
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
            method: model.brewMethod,
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

    private var pourOverSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionLabel("Dripper")
                    Spacer()
                    Text(model.dripper)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.pourOver)
                }
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(ShotLoggingViewModel.dripperPresets, id: \.self) { preset in
                            TagChip(title: preset, isSelected: model.dripper == preset, tint: Palette.pourOver) {
                                model.dripper = preset
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }

            rule

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionLabel("Pour Pulses (incl. Bloom)")
                    Spacer()
                    Text(model.pourCount == 1 ? "Single Continuous Pour" : "\(model.pourCount) Pours")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.inkSecondary)
                }
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { count in
                        let isSelected = model.pourCount == count
                        Button {
                            withAnimation(.snappy) { model.pourCount = count }
                        } label: {
                            Text("\(count)p")
                                .font(.mono(.subheadline, weight: .semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .optionTile(isSelected: isSelected, tint: Palette.pourOver, cornerRadius: 12)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .sensoryFeedback(.selection, trigger: model.pourCount)
            }

            rule

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("Agitation")
                HStack(spacing: 8) {
                    ForEach(PourAgitation.allCases) { item in
                        let isSelected = model.agitation == item
                        Button {
                            withAnimation(.snappy) { model.agitation = item }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: item.symbol)
                                    .font(.subheadline.weight(.semibold))
                                Text(item.label)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .optionTile(isSelected: isSelected, tint: Palette.pourOver, cornerRadius: 12)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .sensoryFeedback(.selection, trigger: model.agitation)
            }
        }
        .padding(16)
        .paperCard()
    }

    private var rule: some View {
        Rectangle()
            .fill(Palette.rule)
            .frame(height: 1)
    }

    private var feedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $model.isSlowFeed) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.feedMethod.label)
                            .font(.headline)
                            .foregroundStyle(Palette.ink)
                        Text(model.feedMethod.detail)
                            .font(.footnote)
                            .foregroundStyle(Palette.inkSecondary)
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
        .padding(16)
        .paperCard()
        .animation(.snappy, value: model.feedMethod)
        .sensoryFeedback(.selection, trigger: model.feedMethod)
    }

    private var flowSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(model.brewMethod == .pourOver ? "Drawdown & Bed" : "Flow")
                .padding(.horizontal, 4)
            FlowPicker(method: model.brewMethod, selection: $model.flowQuality)
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
            .padding(.horizontal, 4)
            BalanceSegmentedControl(selection: $model.tasteBalance)
            Text("Still drinking? Tap the brew in your Notebook later to update flow and balance.")
                .font(.caption)
                .foregroundStyle(Palette.inkSecondary)
                .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private var insightsSection: some View {
        let insights = model.insights.filter { !$0.rule.isFeedHint }
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
                    .focused($focusedText, equals: .tag)
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
                .focused($focusedText, equals: .tweak)
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

    // MARK: Keypad

    @ViewBuilder
    private var keypad: some View {
        if let field = model.activeField, focusedText == nil {
            NumericKeypad(
                field: field,
                method: model.brewMethod,
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
