import SwiftUI
import SwiftData

/// Rate a bag 1 – 10, write notes about it, and mark the coffee as one you'd buy again.
/// Earlier bags of the same coffee are listed underneath with their scores and notes.
struct BeanRatingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \CoffeeBean.createdAt, order: .reverse) private var allBags: [CoffeeBean]

    let bean: CoffeeBean

    @State private var rating: Int?
    @State private var notes: String
    @State private var isFavorite: Bool
    @State private var didSave = false

    init(bean: CoffeeBean) {
        self.bean = bean
        _rating = State(initialValue: bean.rating)
        _notes = State(initialValue: bean.ratingNotes)
        _isFavorite = State(initialValue: bean.isFavorite)
    }

    private var otherBags: [CoffeeBean] {
        allBags.filter {
            $0.persistentModelID != bean.persistentModelID
                && $0.isSameCoffee(as: bean)
                && ($0.rating != nil || !$0.ratingNotes.isEmpty)
        }
    }

    private var hasChanges: Bool {
        rating != bean.rating
            || notes.trimmingCharacters(in: .whitespacesAndNewlines) != bean.ratingNotes
            || isFavorite != bean.isFavorite
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    scoreSection
                    favoriteToggle
                    notesSection
                    if !otherBags.isEmpty {
                        earlierBagsSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .paperBackground()
            .navigationTitle("Rate Bag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.paper, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Palette.ink)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.bold)
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .disabled(!hasChanges)
                }
            }
            .sensoryFeedback(.success, trigger: didSave)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.paper)
        .interactiveDismissDisabled(hasChanges)
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text([bean.roaster.uppercased(), bean.bagNumber > 1 ? "BAG #\(bean.bagNumber)" : ""]
                .filter { !$0.isEmpty }
                .joined(separator: " · "))
                .font(.caption2.weight(.bold))
                .tracking(1.0)
                .foregroundStyle(Palette.inkSecondary)
            Text(bean.name)
                .font(.title3.weight(.bold))
                .foregroundStyle(Palette.ink)
            Text(summaryLine)
                .font(.mono(.caption))
                .foregroundStyle(Palette.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .paperCard()
    }

    private var summaryLine: String {
        let pulls = bean.shots.count
        var parts = [bean.variety, bean.process].filter { !$0.isEmpty }
        parts.append("\(pulls) \(pulls == 1 ? "brew" : "brews")")
        parts.append("Day \(bean.restDays)")
        return parts.joined(separator: " · ")
    }

    private var scoreSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("Score")
                Spacer()
                if rating != nil {
                    Button("Clear") {
                        withAnimation(.snappy) { rating = nil }
                    }
                    .font(.caption.weight(.semibold))
                }
            }
            .padding(.horizontal, 4)

            VStack(spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(rating.map(String.init) ?? "–")
                        .font(.mono(.largeTitle, weight: .bold))
                        .foregroundStyle(rating == nil ? Palette.inkSecondary : Palette.accent)
                        .contentTransition(.numericText())
                    Text("/ 10")
                        .font(.mono(.headline))
                        .foregroundStyle(Palette.inkSecondary)
                    Spacer()
                    Text(Self.verdict(for: rating))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                    ForEach(Array(CoffeeBean.ratingScale), id: \.self) { score in
                        let isSelected = rating == score
                        Button {
                            withAnimation(.snappy) { rating = score }
                        } label: {
                            Text("\(score)")
                                .font(.mono(.title3, weight: .semibold))
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .optionTile(isSelected: isSelected, tint: Palette.accent, cornerRadius: 12)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(score) out of 10")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .sensoryFeedback(.selection, trigger: rating)
            }
            .padding(16)
            .paperCard()
        }
    }

    private var favoriteToggle: some View {
        Toggle(isOn: $isFavorite.animation(.snappy)) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Would buy again")
                        .font(.headline)
                        .foregroundStyle(Palette.ink)
                    Text("Favorites every bag of this coffee")
                        .font(.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                }
            } icon: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(Palette.favorite)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .tint(Palette.favorite)
        .padding(16)
        .paperCard()
        .sensoryFeedback(.selection, trigger: isFavorite)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Notes")
                .padding(.horizontal, 4)
            TextField(
                "What stood out? Best recipe, rest day, what you'd change…",
                text: $notes,
                axis: .vertical
            )
            .lineLimit(5...12)
            .padding(14)
            .paperCard(cornerRadius: 14)
        }
    }

    private var earlierBagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Earlier bags of this coffee")
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                ForEach(Array(otherBags.enumerated()), id: \.element.persistentModelID) { index, bag in
                    if index > 0 {
                        Rectangle().fill(Palette.track).frame(height: 1)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Bag #\(bag.bagNumber) · roasted \(bag.roastDate, format: .dateTime.day().month(.abbreviated).year())")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Palette.ink)
                            Spacer()
                            RatingBadge(rating: bag.rating)
                        }
                        if !bag.ratingNotes.isEmpty {
                            Text(bag.ratingNotes)
                                .font(.footnote)
                                .foregroundStyle(Palette.inkSecondary)
                        }
                    }
                    .padding(14)
                }
            }
            .paperCard()
        }
    }

    // MARK: Actions

    static func verdict(for rating: Int?) -> String {
        guard let rating else { return "Not rated" }
        return switch rating {
        case ...3: "Not for me"
        case 4...5: "Okay"
        case 6...7: "Good"
        case 8...9: "Great"
        default: "Exceptional"
        }
    }

    private func save() {
        bean.rate(rating, notes: notes)
        bean.setFavorite(isFavorite, across: allBags)
        try? context.save()
        didSave.toggle()
        dismiss()
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query(sort: \CoffeeBean.createdAt) var beans: [CoffeeBean]

    Color.clear.sheet(isPresented: .constant(true)) {
        if let bean = beans.first {
            BeanRatingSheet(bean: bean)
        }
    }
}
