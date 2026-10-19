import SwiftUI
import SwiftData

/// Primary counter-side screen:
/// - Active Bean Card with live `Rest: Day XX` badge, bag weight / remaining shots tracker, and one-tap Room Temp ↔ Freezer toggle
/// - Equipment summary strip
/// - Recent pulls of the active bean in A6-notebook format
/// - Prominent thumb-zone "Log Shot" CTA
struct ActiveBeanDashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CoffeeBean.createdAt, order: .reverse) private var beans: [CoffeeBean]
    @Query(sort: \EquipmentProfile.createdAt, order: .reverse) private var profiles: [EquipmentProfile]
    @Query(sort: \ShotLog.timestamp, order: .reverse) private var allShots: [ShotLog]

    @State private var activeSheet: SheetDestination?

    private enum SheetDestination: Identifiable {
        case logShot(CoffeeBean, BrewMethod?)
        case beanLibrary
        case newBean
        case rebuyBean(CoffeeBean)
        case editBean(CoffeeBean)
        case equipment(EquipmentProfile?)

        var id: String {
            switch self {
            case .logShot(_, let method): "logShot-\(method?.rawValue ?? "auto")"
            case .beanLibrary: "beanLibrary"
            case .newBean: "newBean"
            case .rebuyBean: "rebuyBean"
            case .editBean: "editBean"
            case .equipment: "equipment"
            }
        }
    }

    private var activeBean: CoffeeBean? {
        beans.first(where: \.isActive) ?? beans.first(where: { !$0.isFinished }) ?? beans.first
    }

    private var openBeans: [CoffeeBean] {
        beans.filter { !$0.isFinished }
    }

    private var finishedBeans: [CoffeeBean] {
        beans.filter(\.isFinished)
    }

    private var activeEquipment: EquipmentProfile? {
        profiles.first(where: \.isActive) ?? profiles.first
    }

    /// Finds the best pre-fill shot for a bean:
    /// 1) Latest shot on this bag
    /// 2) Latest shot from a previous bag of the same coffee
    /// 3) Latest shot overall
    private func preferredTemplateShot(for bean: CoffeeBean, method: BrewMethod? = nil) -> ShotLog? {
        if let method {
            if let latest = bean.latestShot(for: method) { return latest }
            if let previousBagShot = beans
                .filter({ $0.isSameCoffee(as: bean) })
                .compactMap({ $0.latestShot(for: method) })
                .max(by: { $0.timestamp < $1.timestamp }) {
                return previousBagShot
            }
            return allShots.first(where: { $0.brewMethod == method })
        }
        if let latest = bean.latestShot { return latest }
        if let previousBagShot = beans
            .filter({ $0.isSameCoffee(as: bean) })
            .compactMap(\.latestShot)
            .max(by: { $0.timestamp < $1.timestamp }) {
            return previousBagShot
        }
        return allShots.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if let bean = activeBean {
                    dashboardContent(for: bean)
                } else {
                    emptyState
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dial-In")
            .toolbar { toolbarContent }
            .safeAreaInset(edge: .bottom) {
                if let bean = activeBean {
                    logShotBar(for: bean)
                }
            }
            .sheet(item: $activeSheet) { destination in
                switch destination {
                case .logShot(let bean, let method):
                    ShotLoggingSheetView(
                        bean: bean,
                        equipment: activeEquipment,
                        fallbackTemplate: preferredTemplateShot(for: bean, method: method),
                        initialMethod: method
                    )
                case .beanLibrary:
                    BeanLibrarySheet { template in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            if let template {
                                activeSheet = .rebuyBean(template)
                            } else {
                                activeSheet = .newBean
                            }
                        }
                    }
                case .newBean:
                    BeanEditorSheet()
                case .rebuyBean(let template):
                    BeanEditorSheet(rebuyOf: template)
                case .editBean(let bean):
                    BeanEditorSheet(bean: bean)
                case .equipment(let profile):
                    EquipmentProfileSheet(profile: profile)
                }
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if !beans.isEmpty {
                Menu {
                    Button {
                        activeSheet = .beanLibrary
                    } label: {
                        Label("Search All Coffees…", systemImage: "magnifyingglass")
                    }
                    Divider()
                    if !openBeans.isEmpty {
                        Section("Open Bags") {
                            ForEach(openBeans) { bean in
                                let bagSuffix = bean.bagNumber > 1 ? " #\(bean.bagNumber)" : ""
                                Button {
                                    withAnimation(.snappy) {
                                        context.activate(bean)
                                        try? context.save()
                                    }
                                } label: {
                                    Label(
                                        "\(bean.name)\(bagSuffix) · \(bean.roaster) (Day \(bean.restDays))",
                                        systemImage: bean.persistentModelID == activeBean?.persistentModelID ? "checkmark.circle.fill" : "circle"
                                    )
                                }
                            }
                        }
                    }
                    if !finishedBeans.isEmpty {
                        Section("Finished Bags") {
                            ForEach(finishedBeans) { bean in
                                let bagSuffix = bean.bagNumber > 1 ? " #\(bean.bagNumber)" : ""
                                Button {
                                    withAnimation(.snappy) {
                                        context.activate(bean)
                                        try? context.save()
                                    }
                                } label: {
                                    Label(
                                        "\(bean.name)\(bagSuffix) · \(bean.roaster) (Done)",
                                        systemImage: bean.persistentModelID == activeBean?.persistentModelID ? "checkmark.seal.fill" : "archivebox"
                                    )
                                }
                            }
                        }
                    }
                    Divider()
                    if let activeBean {
                        Button {
                            toggleFinished(for: activeBean)
                        } label: {
                            Label(
                                activeBean.isFinished ? "Reopen \(activeBean.name)" : "Mark \(activeBean.name) as Done",
                                systemImage: activeBean.isFinished ? "arrow.uturn.backward.circle" : "checkmark.circle"
                            )
                        }
                        Button {
                            activeSheet = .rebuyBean(activeBean)
                        } label: {
                            Label("New Bag of \(activeBean.name)…", systemImage: "shippingbox.and.arrow.backward")
                        }
                    }
                    Button {
                        activeSheet = .newBean
                    } label: {
                        Label("New Coffee Bean…", systemImage: "plus")
                    }
                } label: {
                    Label("Coffees", systemImage: "shippingbox")
                }
            }
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                activeSheet = .beanLibrary
            } label: {
                Label("Search Coffees", systemImage: "magnifyingglass")
            }

            Button {
                activeSheet = .equipment(activeEquipment)
            } label: {
                Label("Equipment", systemImage: "slider.horizontal.3")
            }

            NavigationLink {
                ShotHistoryListView(bean: activeBean)
            } label: {
                Label("History", systemImage: "book.pages")
            }
        }
    }

    // MARK: Content

    private func dashboardContent(for bean: CoffeeBean) -> some View {
        let beanShots = bean.shotsNewestFirst
        let fallbackDose = preferredTemplateShot(for: bean)?.dose ?? 20.0
        return ScrollView {
            VStack(spacing: 16) {
                ActiveBeanCard(
                    bean: bean,
                    fallbackDose: fallbackDose,
                    onToggleStorage: { toggleStorage(for: bean) },
                    onToggleFinished: { toggleFinished(for: bean) },
                    onRebuy: { activeSheet = .rebuyBean(bean) },
                    onNewBean: { activeSheet = .newBean },
                    onEdit: { activeSheet = .editBean(bean) }
                )

                if let equipment = activeEquipment {
                    EquipmentStrip(equipment: equipment) {
                        activeSheet = .equipment(equipment)
                    }
                }

                if let lastShot = beanShots.first ?? preferredTemplateShot(for: bean) {
                    LastRecipeCard(
                        shot: lastShot,
                        isCarryOver: beanShots.isEmpty
                    )
                }

                recentShotsSection(for: bean, shots: beanShots)
            }
            .padding()
        }
    }

    @ViewBuilder
    private func recentShotsSection(for bean: CoffeeBean, shots: [ShotLog]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel("Notebook · \(shots.count) \(shots.count == 1 ? "Pull" : "Pulls")")
                Spacer()
                if !shots.isEmpty {
                    NavigationLink {
                        ShotHistoryListView(bean: bean)
                    } label: {
                        Text("Full Log & Search")
                            .font(.caption.weight(.semibold))
                    }
                }
            }

            if shots.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "cup.and.saucer")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No pulls logged for this bag yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if preferredTemplateShot(for: bean) != nil {
                        Text("Your next pull will pre-fill from your previous cup.")
                            .font(.caption)
                            .foregroundStyle(.tint)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .cardBackground()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(shots.prefix(6).enumerated()), id: \.element.persistentModelID) { index, shot in
                        if index > 0 {
                            Divider()
                        }
                        ShotRowView(shot: shot, number: shots.count - index)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 4)
                    }
                }
                .cardBackground()
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Active Coffee Bean", systemImage: "mug")
        } description: {
            Text("Add a bag to track rest days, bag weight, and your dial-in pulls.")
        } actions: {
            HStack(spacing: 12) {
                Button("Add Bean") {
                    activeSheet = .newBean
                }
                .buttonStyle(.borderedProminent)

                Button("Load Sample Notebook") {
                    SampleData.insertNotebookSample(in: context)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func logShotBar(for bean: CoffeeBean) -> some View {
        let espTemplate = preferredTemplateShot(for: bean, method: .espresso)
        let poTemplate = preferredTemplateShot(for: bean, method: .pourOver)
        return HStack(spacing: 10) {
            Button {
                activeSheet = .logShot(bean, .espresso)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: BrewMethod.espresso.symbol)
                        .font(.subheadline.weight(.semibold))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Log Espresso")
                            .font(.subheadline.weight(.bold))
                        if let espTemplate {
                            Text("\(espTemplate.dose.fixed())g @ G \(espTemplate.grindSetting.fixed())")
                                .font(.caption2.monospacedDigit())
                                .opacity(0.85)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)

            Button {
                activeSheet = .logShot(bean, .pourOver)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: BrewMethod.pourOver.symbol)
                        .font(.subheadline.weight(.semibold))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Pour Over")
                            .font(.subheadline.weight(.bold))
                        if let poTemplate {
                            Text("\(poTemplate.dose.fixed())g @ G \(poTemplate.grindSetting.fixed())")
                                .font(.caption2.monospacedDigit())
                                .opacity(0.85)
                        } else {
                            Text("15g · 1:16.7")
                                .font(.caption2.monospacedDigit())
                                .opacity(0.85)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
            .buttonBorderShape(.capsule)
        }
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func toggleStorage(for bean: CoffeeBean) {
        withAnimation(.snappy) {
            if bean.isFrozen {
                bean.thaw()
            } else {
                bean.freeze()
            }
            try? context.save()
        }
    }

    private func toggleFinished(for bean: CoffeeBean) {
        withAnimation(.snappy) {
            if bean.isFinished {
                bean.reopen()
            } else {
                bean.markFinished()
            }
            try? context.save()
        }
    }
}

// MARK: - Subviews

/// Active Bean Card with live `TimelineView` rest badge, bag weight & shots remaining meter, and Room Temp / Freezer state pill.
private struct ActiveBeanCard: View {
    let bean: CoffeeBean
    let fallbackDose: Double
    var onToggleStorage: () -> Void
    var onToggleFinished: () -> Void
    var onRebuy: () -> Void
    var onNewBean: () -> Void
    var onEdit: () -> Void

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            let days = bean.restDays(on: timeline.date)
            let dose = bean.usualDose(fallback: fallbackDose)
            let shotsLeft = bean.estimatedShotsRemaining(fallbackDose: fallbackDose)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(bean.roaster.uppercased())
                                .font(.caption.weight(.bold))
                                .tracking(1.0)
                                .foregroundStyle(.secondary)
                            if bean.bagNumber > 1 {
                                Text("BAG #\(bean.bagNumber)")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .foregroundStyle(.tint)
                                    .background(Color.accentColor.opacity(0.14), in: Capsule())
                            }
                        }
                        Text(bean.name)
                            .font(.title2.weight(.bold))
                        HStack(spacing: 6) {
                            if !bean.variety.isEmpty {
                                Text(bean.variety)
                            }
                            if !bean.variety.isEmpty, !bean.process.isEmpty {
                                Text("·")
                            }
                            if !bean.process.isEmpty {
                                Text(bean.process)
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    RestBadge(days: days, isFrozen: bean.isFrozen, isFinished: bean.isFinished)
                }

                // Bag Weight & Remaining Shots Meter
                if bean.isFinished {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                            Text("Bag Finished")
                                .font(.caption.weight(.bold))
                            Text("· \(bean.usedGrams.fixed(0))g logged of \(bean.bagWeightGrams.fixed(0))g\(bean.untrackedGrams > 0 ? " (\(bean.untrackedGrams.fixed(0))g untracked)" : "")")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                        }

                        HStack(spacing: 8) {
                            Button(action: onToggleFinished) {
                                Label("Reopen", systemImage: "arrow.uturn.backward")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color(.tertiarySystemFill), in: Capsule())
                            }
                            .buttonStyle(.plain)

                            Button(action: onRebuy) {
                                Label("Re-buy Bag", systemImage: "shippingbox.and.arrow.backward")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .foregroundStyle(.tint)
                                    .background(Color.accentColor.opacity(0.14), in: Capsule())
                            }
                            .buttonStyle(.plain)

                            Button(action: onNewBean) {
                                Label("New Coffee", systemImage: "plus")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color(.tertiarySystemFill), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Label {
                                Text("~\(shotsLeft) \(shotsLeft == 1 ? "dose" : "doses") left")
                                    .font(.caption.weight(.bold).monospacedDigit())
                            } icon: {
                                Image(systemName: "scalemass.fill")
                                    .font(.caption)
                                    .foregroundStyle(shotsLeft <= 2 ? Color.orange : Color.accentColor)
                            }
                            Text("(\(bean.remainingGrams.fixed(0))g / \(bean.bagWeightGrams.fixed(0))g · @\(dose.fixed())g)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Spacer()
                            Button(action: onToggleFinished) {
                                Label("Bag Done", systemImage: "checkmark.circle")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .foregroundStyle(.secondary)
                                    .background(Color(.tertiarySystemFill), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Mark coffee bag as done")

                            Button(action: onRebuy) {
                                Label("New Bag", systemImage: "plus.square.on.square")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.tertiarySystemFill), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }

                        ProgressView(value: bean.remainingFraction)
                            .tint(shotsLeft <= 2 ? .orange : .accentColor)
                    }
                    .padding(10)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Divider()

                HStack(spacing: 10) {
                    storagePill
                    Spacer()
                    Text("Roasted \(bean.roastDate, format: .dateTime.day().month(.abbreviated))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button(action: onEdit) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit bean")
                }
            }
            .padding()
            .cardBackground()
            .sensoryFeedback(.selection, trigger: bean.isFrozen)
            .sensoryFeedback(.success, trigger: bean.isFinished)
        }
    }

    private var storagePill: some View {
        Button(action: onToggleStorage) {
            HStack(spacing: 6) {
                Image(systemName: bean.isFrozen ? "snowflake" : "thermometer.medium")
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 0) {
                    Text(bean.isFrozen ? "In Freezer" : "Room Temp")
                        .font(.caption.weight(.semibold))
                    if bean.isFrozen, let freezeDate = bean.freezeDate {
                        Text("Paused \(freezeDate, format: .dateTime.day().month(.abbreviated))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Tap to freeze")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(bean.isFrozen ? Color.cyan : Color.orange)
            .background((bean.isFrozen ? Color.cyan : Color.orange).opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(bean.isFrozen ? "Stored in freezer, rest paused. Tap to thaw." : "At room temperature. Tap to freeze.")
    }
}

private struct EquipmentStrip: View {
    let equipment: EquipmentProfile
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "espressomachine")
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(equipment.machineName)
                        .font(.subheadline.weight(.semibold))
                    Text("\(equipment.summary) · \(equipment.defaultDripper)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .cardBackground(cornerRadius: 14)
        }
        .buttonStyle(.plain)
    }
}

/// Quick-glance summary of the last brew + its "Next tweak" callout.
private struct LastRecipeCard: View {
    let shot: ShotLog
    var isCarryOver: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                SectionLabel(isCarryOver ? "Previous Bag Recipe · R\(shot.restDaysAtBrew)" : "Last Brew · R\(shot.restDaysAtBrew)")
                BrewMethodBadge(method: shot.brewMethod, dripper: shot.dripper)
                Spacer()
                BalanceGlyph(balance: shot.tasteBalance)
            }

            if shot.brewMethod == .pourOver {
                HStack(spacing: 0) {
                    metric("Grind", value: shot.grindSetting.fixed(), sub: shot.grinderRPM.map { "@\($0)" } ?? shot.feedMethod.shortLabel)
                    Divider().frame(height: 28)
                    metric("Water", value: "\(shot.dose.fixed()) → \(shot.yield.fixed(0))g", sub: ShotFormatter.ratio(shot.ratio, method: .pourOver))
                    Divider().frame(height: 28)
                    metric("Drawdown", value: ShotFormatter.drawdown(shot.totalTime), sub: ShotFormatter.bloom(water: shot.bloomWater, pause: shot.preBrewPause))
                    Divider().frame(height: 28)
                    metric("Temp", value: ShotFormatter.temperature(shot.brewTemperature), sub: ShotFormatter.pours(count: shot.pourCount, agitation: shot.agitation))
                }
            } else {
                HStack(spacing: 0) {
                    metric("Grind", value: shot.grindSetting.fixed(), sub: shot.grinderRPM.map { "@\($0)" } ?? shot.feedMethod.shortLabel)
                    Divider().frame(height: 28)
                    metric("Ratio", value: "\(shot.dose.fixed()) → \(shot.yield.fixed())g", sub: ShotFormatter.ratio(shot.ratio))
                    Divider().frame(height: 28)
                    metric("Time", value: "\(shot.totalTime.fixed())s", sub: ShotFormatter.preBrew(pulse: shot.preBrewPulse, pause: shot.preBrewPause))
                    Divider().frame(height: 28)
                    metric("Temp", value: ShotFormatter.temperature(shot.brewTemperature), sub: "FP \(shot.fullPressureTime.fixed())s")
                }
            }

            if let tweak = shot.actionableNextTweak, !tweak.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.turn.down.right")
                        .foregroundStyle(.tint)
                    Text("Next:")
                        .foregroundStyle(.secondary)
                    Text(tweak)
                        .fontWeight(.semibold)
                }
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding()
        .cardBackground()
    }

    private func metric(_ label: String, value: String, sub: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(sub)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview(traits: .sampleData) {
    ActiveBeanDashboardView()
}
