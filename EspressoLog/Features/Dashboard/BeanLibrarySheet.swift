import SwiftUI
import SwiftData

/// Searchable library of all coffee bags (active & past), allowing the user to search by
/// name, roaster, variety, process or rating notes, switch the active bag, start a new bag of a past coffee,
/// and rate bags or mark the ones you'd buy again.
struct BeanLibrarySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \CoffeeBean.createdAt, order: .reverse) private var beans: [CoffeeBean]

    @State private var searchText = ""
    @State private var scope: Scope = .all
    @State private var ratingBean: CoffeeBean?

    private enum Scope: String, CaseIterable, Identifiable {
        case all = "All"
        case favorites = "Favorites"
        case topRated = "Top Rated"

        var id: String { rawValue }
    }

    var onSelectNewBag: (CoffeeBean?) -> Void

    private var filteredBeans: [CoffeeBean] {
        let matches = beans.filter { $0.matchesSearch(searchText) }
        return switch scope {
        case .all: matches
        case .favorites: matches.filter(\.isFavorite)
        case .topRated:
            matches
                .filter { $0.rating != nil }
                .sorted { ($0.rating ?? 0, $0.createdAt) > ($1.rating ?? 0, $1.createdAt) }
        }
    }

    private var openBeans: [CoffeeBean] {
        filteredBeans.filter { !$0.isFinished }
    }

    private var finishedBeans: [CoffeeBean] {
        filteredBeans.filter(\.isFinished)
    }

    var body: some View {
        NavigationStack {
            List {
                Picker("Show", selection: $scope) {
                    ForEach(Scope.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

                if scope == .topRated {
                    if !filteredBeans.isEmpty {
                        Section("By Score") {
                            ForEach(filteredBeans) { bean in
                                beanRow(for: bean)
                            }
                        }
                    }
                } else {
                    if !openBeans.isEmpty {
                        Section("Open Bags") {
                            ForEach(openBeans) { bean in
                                beanRow(for: bean)
                            }
                        }
                    }
                    if !finishedBeans.isEmpty {
                        Section("Finished Bags") {
                            ForEach(finishedBeans) { bean in
                                beanRow(for: bean)
                            }
                        }
                    }
                }
            }
            .sheet(item: $ratingBean) { bean in
                BeanRatingSheet(bean: bean)
            }
            .searchable(text: $searchText, prompt: "Search coffee, roaster, process, notes…")
            .navigationTitle("Coffee Bags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                        onSelectNewBag(nil)
                    } label: {
                        Label("New Bag", systemImage: "plus")
                    }
                }
            }
            .overlay {
                if filteredBeans.isEmpty {
                    if !searchText.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else if scope == .favorites {
                        ContentUnavailableView(
                            "No Favorites Yet",
                            systemImage: "heart",
                            description: Text("Tap the heart on a bag you'd buy again.")
                        )
                    } else if scope == .topRated {
                        ContentUnavailableView(
                            "No Rated Bags",
                            systemImage: "star",
                            description: Text("Swipe right on a bag and tap Rate to score it 1 – 10.")
                        )
                    }
                }
            }
        }
    }

    private func beanRow(for bean: CoffeeBean) -> some View {
        let fallbackDose = beans
            .filter { $0.isSameCoffee(as: bean) }
            .compactMap { $0.latestShot?.dose }
            .first ?? 20.0
        let shotsLeft = bean.estimatedShotsRemaining(fallbackDose: fallbackDose)
        let doseUsed = bean.usualDose(fallback: fallbackDose)

        return HStack(alignment: .center, spacing: 12) {
            Button {
                context.activate(bean)
                try? context.save()
                dismiss()
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(bean.name)
                            .font(.headline)
                            .foregroundStyle(bean.isFinished ? Color.secondary : Color.primary)
                        if bean.bagNumber > 1 {
                            Text("Bag #\(bean.bagNumber)")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.tertiarySystemFill), in: Capsule())
                        }
                        if bean.isActive {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.tint)
                        }
                        RatingBadge(rating: bean.rating, isFavorite: bean.isFavorite)
                    }

                    Text("\(bean.roaster) · \(bean.variety) · \(bean.process)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        RestBadge(days: bean.restDays, isFrozen: bean.isFrozen, isFinished: bean.isFinished, compact: true)
                        if bean.isFinished {
                            Text("Finished · \(bean.usedGrams.fixed(0))/\(bean.bagWeightGrams.fixed(0))g logged")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(bean.remainingGrams.fixed(0))/\(bean.bagWeightGrams.fixed(0))g · ~\(shotsLeft) doses (@\(doseUsed.fixed())g)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !bean.ratingNotes.isEmpty {
                        Text(bean.ratingNotes)
                            .font(.footnote)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(3)
                            .padding(.top, 2)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                withAnimation(.snappy) {
                    if bean.isFinished {
                        bean.reopen()
                    } else {
                        bean.markFinished()
                    }
                    try? context.save()
                }
            } label: {
                Image(systemName: bean.isFinished ? "arrow.uturn.backward.circle" : "checkmark.circle")
                    .font(.title3)
                    .foregroundStyle(bean.isFinished ? Color.secondary : Color.green)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(bean.isFinished ? "Reopen \(bean.name)" : "Mark \(bean.name) as done")

            Button {
                dismiss()
                onSelectNewBag(bean)
            } label: {
                Label("New Bag", systemImage: "shippingbox.and.arrow.backward")
                    .font(.caption.weight(.semibold))
                    .labelStyle(.titleOnly)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.14), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start a new bag of \(bean.name)")
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .leading) {
            Button {
                ratingBean = bean
            } label: {
                Label("Rate", systemImage: "star")
            }
            .tint(Palette.accent)
            Button {
                toggleFavorite(bean)
            } label: {
                Label(bean.isFavorite ? "Unfavorite" : "Favorite", systemImage: bean.isFavorite ? "heart.slash" : "heart")
            }
            .tint(Palette.favorite)
        }
        .contextMenu {
            Button {
                ratingBean = bean
            } label: {
                Label(bean.rating == nil ? "Rate Bag…" : "Edit Rating…", systemImage: "star")
            }
            Button {
                toggleFavorite(bean)
            } label: {
                Label(bean.isFavorite ? "Remove from Favorites" : "Would Buy Again", systemImage: bean.isFavorite ? "heart.slash" : "heart")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                withAnimation(.snappy) {
                    if bean.isFinished {
                        bean.reopen()
                    } else {
                        bean.markFinished()
                    }
                    try? context.save()
                }
            } label: {
                Label(
                    bean.isFinished ? "Reopen" : "Bag Done",
                    systemImage: bean.isFinished ? "arrow.uturn.backward.circle" : "checkmark.circle.fill"
                )
            }
            .tint(bean.isFinished ? .orange : .green)
        }
    }

    private func toggleFavorite(_ bean: CoffeeBean) {
        withAnimation(.snappy) {
            bean.setFavorite(!bean.isFavorite, across: beans)
            try? context.save()
        }
    }
}
