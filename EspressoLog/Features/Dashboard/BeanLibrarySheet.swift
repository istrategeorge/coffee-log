import SwiftUI
import SwiftData

/// Searchable library of all coffee bags (active & past), allowing the user to search by
/// name, roaster, variety, or process, switch the active bag, or start a new bag of a past coffee.
struct BeanLibrarySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \CoffeeBean.createdAt, order: .reverse) private var beans: [CoffeeBean]

    @State private var searchText = ""

    var onSelectNewBag: (CoffeeBean?) -> Void

    private var filteredBeans: [CoffeeBean] {
        beans.filter { $0.matchesSearch(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredBeans) { bean in
                    beanRow(for: bean)
                }
            }
            .searchable(text: $searchText, prompt: "Search coffee, roaster, variety, process…")
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
                    ContentUnavailableView.search(text: searchText)
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
                            .foregroundStyle(.primary)
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
                    }

                    Text("\(bean.roaster) · \(bean.variety) · \(bean.process)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        RestBadge(days: bean.restDays, isFrozen: bean.isFrozen, compact: true)
                        Text("\(bean.remainingGrams.fixed(0))/\(bean.bagWeightGrams.fixed(0))g · ~\(shotsLeft) shots (@\(doseUsed.fixed())g)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

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
    }
}
