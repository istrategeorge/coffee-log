import SwiftUI
import SwiftData

/// Dial-in history in a compact, notebook-style list. Supports bean filtering and full-text search
/// across coffee name, roaster, variety, flavor notes, next tweaks, and equipment.
struct ShotHistoryListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ShotLog.timestamp, order: .reverse) private var allShots: [ShotLog]
    @Query(sort: \CoffeeBean.createdAt, order: .reverse) private var beans: [CoffeeBean]

    @State private var beanFilter: CoffeeBean?
    @State private var searchText: String = ""

    init(bean: CoffeeBean? = nil) {
        _beanFilter = State(initialValue: bean)
    }

    private var visibleShots: [ShotLog] {
        let base: [ShotLog]
        if let beanFilter {
            base = allShots.filter { $0.bean?.persistentModelID == beanFilter.persistentModelID }
        } else {
            base = allShots
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return base }

        return base.filter { shot in
            if let bean = shot.bean, bean.matchesSearch(query) { return true }
            if shot.flavorNotes.contains(where: { $0.localizedStandardContains(query) }) { return true }
            if let tweak = shot.actionableNextTweak, tweak.localizedStandardContains(query) { return true }
            if let equipment = shot.equipment, equipment.fullLine.localizedStandardContains(query) { return true }
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
            if let beanFilter, searchText.isEmpty {
                NotebookHeader(bean: beanFilter, equipment: shots.first?.equipment)
                    .listRowSeparator(.hidden)
            }
            ForEach(shots) { shot in
                ShotRowView(
                    shot: shot,
                    number: numbers[shot.persistentModelID],
                    showsBeanName: beanFilter == nil || !searchText.isEmpty
                )
                .swipeActions(edge: .trailing) {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        delete(shot)
                    }
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: "Search coffee, roaster, notes, gear…")
        .navigationTitle(beanFilter?.name ?? "All Shots")
        .navigationBarTitleDisplayMode(.inline)
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
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .overlay {
            if shots.isEmpty {
                if !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ContentUnavailableView(
                        "No Shots Yet",
                        systemImage: "cup.and.saucer",
                        description: Text("Logged pulls will appear here.")
                    )
                }
            }
        }
    }

    private func delete(_ shot: ShotLog) {
        withAnimation {
            context.delete(shot)
            try? context.save()
        }
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query(sort: \CoffeeBean.createdAt) var beans: [CoffeeBean]
    NavigationStack {
        ShotHistoryListView(bean: beans.first)
    }
}
