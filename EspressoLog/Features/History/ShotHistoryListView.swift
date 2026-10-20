import SwiftUI
import SwiftData

/// Dial-in history in a compact, notebook-style list. Supports bean filtering and full-text search
/// across coffee name, roaster, variety, flavor notes, next tweaks, and equipment.
struct ShotHistoryListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ShotLog.timestamp, order: .reverse) private var allShots: [ShotLog]
    @Query(sort: \CoffeeBean.createdAt, order: .reverse) private var beans: [CoffeeBean]

    @State private var beanFilter: CoffeeBean?
    @State private var methodFilter: BrewMethod?
    @State private var searchText: String = ""

    init(bean: CoffeeBean? = nil) {
        _beanFilter = State(initialValue: bean)
    }

    private var visibleShots: [ShotLog] {
        var base: [ShotLog]
        if let beanFilter {
            base = allShots.filter { $0.bean?.persistentModelID == beanFilter.persistentModelID }
        } else {
            base = allShots
        }
        if let methodFilter {
            base = base.filter { $0.brewMethod == methodFilter }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return base }

        return base.filter { shot in
            if let bean = shot.bean, bean.matchesSearch(query) { return true }
            if shot.brewMethod.label.localizedStandardContains(query) { return true }
            if let dripper = shot.dripper, dripper.localizedStandardContains(query) { return true }
            if shot.flavorNotes.contains(where: { $0.localizedStandardContains(query) }) { return true }
            if let tweak = shot.actionableNextTweak, tweak.localizedStandardContains(query) { return true }
            if let equipment = shot.equipment,
               equipment.fullLine(for: shot.brewMethod, dripper: shot.dripper).localizedStandardContains(query) {
                return true
            }
            return false
        }
    }

    /// Per-bean chronological numbering (#1 = first pull of the bag).
    private var shotNumbers: [PersistentIdentifier: Int] {
        var numbers: [PersistentIdentifier: Int] = [:]
        let grouped = Dictionary(grouping: allShots) { $0.bean?.persistentModelID }
        for shots in grouped.values {
            for (index, shot) in shots.sorted(by: { $0.timestamp < $1.timestamp }).enumerated() {
                numbers[shot.persistentModelID] = index + 1
            }
        }
        return numbers
    }

    var body: some View {
        let numbers = shotNumbers
        let shots = visibleShots

        List {
            methodChips
                .paperRow(top: 4, bottom: 4)
            if let beanFilter, searchText.isEmpty {
                NotebookHeader(bean: beanFilter, equipment: shots.first?.equipment)
                    .paperRow()
            }
            ForEach(shots) { shot in
                ShotRowView(
                    shot: shot,
                    number: numbers[shot.persistentModelID],
                    showsBeanName: beanFilter == nil || !searchText.isEmpty
                )
                .paperRow()
                .swipeActions(edge: .trailing) {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        delete(shot)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .paperBackground()
        .searchable(text: $searchText, prompt: "Search coffee, roaster, method, notes, gear…")
        .navigationTitle(beanFilter?.name ?? "All Brews")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.paper, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Bean", selection: $beanFilter) {
                        Text("All Bags").tag(CoffeeBean?.none)
                        ForEach(beans) { bean in
                            let bagSuffix = bean.bagNumber > 1 ? " #\(bean.bagNumber)" : ""
                            Text("\(bean.name)\(bagSuffix) · \(bean.roaster)").tag(Optional(bean))
                        }
                    }
                } label: {
                    Label("Filter Bags", systemImage: beanFilter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                }
            }
        }
        .overlay {
            if shots.isEmpty {
                if !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ContentUnavailableView(
                        "No Brews Yet",
                        systemImage: "cup.and.saucer",
                        description: Text("Logged espresso shots and pour overs will appear here.")
                    )
                }
            }
        }
    }

    private var methodChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                TagChip(title: "All", isSelected: methodFilter == nil, tint: Palette.ink) {
                    withAnimation(.snappy) { methodFilter = nil }
                }
                ForEach(BrewMethod.allCases) { method in
                    TagChip(title: method.label, isSelected: methodFilter == method, tint: method.tint) {
                        withAnimation(.snappy) { methodFilter = method }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: methodFilter)
    }

    private func delete(_ shot: ShotLog) {
        withAnimation {
            context.delete(shot)
            try? context.save()
        }
    }
}

private extension View {
    /// Card-on-paper list row: no separator or cell background, inset like the rest of the app.
    func paperRow(top: CGFloat = 6, bottom: CGFloat = 6) -> some View {
        listRowInsets(EdgeInsets(top: top, leading: 16, bottom: bottom, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query(sort: \CoffeeBean.createdAt) var beans: [CoffeeBean]
    NavigationStack {
        ShotHistoryListView(bean: beans.first)
    }
}
