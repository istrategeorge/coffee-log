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
        case backup

        var id: String {
            switch self {
            case .logShot(_, let method): "logShot-\(method?.rawValue ?? "auto")"
            case .beanLibrary: "beanLibrary"
            case .newBean: "newBean"
            case .rebuyBean: "rebuyBean"
            case .editBean: "editBean"
            case .equipment: "equipment"
            case .backup: "backup"
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
            .paperBackground()
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
                case .backup:
                    BackupView()
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
                    Divider()
                    Button {
                        activeSheet = .backup
                    } label: {
                        Label("Backup & Restore…", systemImage: "externaldrive.badge.icloud")
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
            VStack(spacing: 20) {
                ActiveBeanCard(
                    bean: bean,
                    fallbackDose: fallbackDose,
                    onToggleStorage: { toggleStorage(for: bean) },
                    onToggleFinished: { toggleFinished(for: bean) },
                    onRebuy: { activeSheet = .rebuyBean(bean) },
                    onNewBean: { activeSheet = .newBean },
                    onEdit: { activeSheet = .editBean(bean) }
                )

                if let lastShot = beanShots.first ?? preferredTemplateShot(for: bean) {
                    LastRecipeCard(
                        shot: lastShot,
                        isCarryOver: beanShots.isEmpty
                    )
                }

                recentShotsSection(for: bean, shots: beanShots)

                if let equipment = activeEquipment {
                    EquipmentStrip(equipment: equipment) {
                        activeSheet = .equipment(equipment)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
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
                        Text("See All")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
            .padding(.horizontal, 4)

            if shots.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "cup.and.saucer")
                        .font(.title2)
                        .foregroundStyle(Palette.inkSecondary)
                    Text("No pulls logged for this bag yet.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkSecondary)
                    if preferredTemplateShot(for: bean) != nil {
                        Text("Your next pull will pre-fill from your previous cup.")
                            .font(.caption)
                            .foregroundStyle(.tint)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .paperCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(shots.prefix(3).enumerated()), id: \.element.persistentModelID) { index, shot in
                        if index > 0 {
                            Rectangle()
                                .fill(Palette.track)
                                .frame(height: 1)
                        }
                        NotebookPreviewRow(shot: shot, number: shots.count - index)
                    }
                }
                .paperCard()
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Active Coffee Bean", systemImage: "mug")
        } description: {
            Text("Add a bag to track rest days, bag weight, and your dial-in pulls.")
        } actions: {
            VStack(spacing: 12) {
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

                Button {
                    activeSheet = .backup
                } label: {
                    Label("Restore from Backup", systemImage: "square.and.arrow.down")
                }
            }
        }
    }

    private func logShotBar(for bean: CoffeeBean) -> some View {
        let espTemplate = preferredTemplateShot(for: bean, method: .espresso)
        let poTemplate = preferredTemplateShot(for: bean, method: .pourOver)
        return HStack(spacing: 12) {
            logTile(
                "Log Espresso",
                symbol: BrewMethod.espresso.symbol,
                detail: espTemplate.map { "\($0.dose.fixed())g · G \($0.grindSetting.fixed()) · \(ShotFormatter.ratio($0.ratio))" },
                kind: .prominent
            ) {
                activeSheet = .logShot(bean, .espresso)
            }

            logTile(
                "Pour Over",
                symbol: BrewMethod.pourOver.symbol,
                detail: poTemplate.map { "\($0.dose.fixed())g · G \($0.grindSetting.fixed())" } ?? "15g · 1:16.7",
                kind: .card
            ) {
                activeSheet = .logShot(bean, .pourOver)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Palette.paper)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Palette.rule)
                .frame(height: 1)
        }
    }

    private func logTile(
        _ title: String,
        symbol: String,
        detail: String?,
        kind: PaperButtonStyle.Kind,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    if let detail {
                        Text(detail)
                            .font(.mono(.caption2))
                            .opacity(0.8)
                    }
                }
                Spacer(minLength: 0)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 60)
        }
        .buttonStyle(PaperButtonStyle(kind: kind, cornerRadius: 18))
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

/// Active Bean Card: rest-day ring, storage state, bag-weight meter, and bag actions (freeze, done, new bag).
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

            VStack(alignment: .leading, spacing: 18) {
                header

                HStack(spacing: 18) {
                    RestRing(days: days, isFrozen: bean.isFrozen, isFinished: bean.isFinished)
                    VStack(alignment: .leading, spacing: 10) {
                        statusPill
                        Text("Roasted \(bean.roastDate, format: .dateTime.day().month(.abbreviated))")
                            .font(.subheadline)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                    Spacer(minLength: 0)
                }

                if bean.isFinished {
                    Text("\(bean.usedGrams.fixed(0))g logged of \(bean.bagWeightGrams.fixed(0))g\(bean.untrackedGrams > 0 ? " · \(bean.untrackedGrams.fixed(0))g untracked" : "")")
                        .font(.mono(.footnote))
                        .foregroundStyle(Palette.inkSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else {
                    bagMeter(shotsLeft: shotsLeft, dose: dose)
                }

                actions
            }
            .padding(20)
            .paperCard(cornerRadius: 24)
            .sensoryFeedback(.selection, trigger: bean.isFrozen)
            .sensoryFeedback(.success, trigger: bean.isFinished)
        }
    }

    private var overline: String {
        var parts: [String] = []
        if !bean.roaster.isEmpty { parts.append(bean.roaster.uppercased()) }
        if bean.bagNumber > 1 { parts.append("BAG #\(bean.bagNumber)") }
        return parts.joined(separator: " · ")
    }

    private var originLine: String {
        [bean.variety, bean.process].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if !overline.isEmpty {
                    Text(overline)
                        .font(.caption2.weight(.bold))
                        .tracking(1.0)
                        .foregroundStyle(Palette.inkSecondary)
                }
                Text(bean.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Palette.ink)
                if !originLine.isEmpty {
                    Text(originLine)
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            Spacer(minLength: 0)
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(PaperButtonStyle(kind: .inset, cornerRadius: 22))
            .accessibilityLabel("Edit bean")
        }
    }

    private var statusPill: some View {
        let tint: Color = if bean.isFinished {
            Palette.inkSecondary
        } else if bean.isFrozen {
            Palette.frost
        } else {
            Palette.sweet
        }
        return HStack(spacing: 6) {
            if bean.isFinished {
                Image(systemName: "checkmark.seal.fill")
                    .font(.caption.weight(.bold))
                Text("Bag finished")
            } else if bean.isFrozen {
                Image(systemName: "snowflake")
                    .font(.caption.weight(.bold))
                if let freezeDate = bean.freezeDate {
                    Text("Frozen \(freezeDate, format: .dateTime.day().month(.abbreviated))")
                } else {
                    Text("In freezer")
                }
            } else {
                Image(systemName: "circle.fill")
                    .font(.system(size: 7, weight: .bold))
                    .symbolEffect(.pulse, options: .repeating)
                Text("Resting · room temp")
            }
        }
        .font(.footnote.weight(.semibold))
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundStyle(tint)
        .background(tint.opacity(0.14), in: Capsule())
        .accessibilityElement(children: .combine)
    }

    private func bagMeter(shotsLeft: Int, dose: Double) -> some View {
        let isLow = shotsLeft <= 2
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(bean.remainingGrams.fixed(0))g")
                        .fontWeight(.semibold)
                        .foregroundStyle(Palette.ink)
                    Text(" / \(bean.bagWeightGrams.fixed(0))g")
                        .foregroundStyle(Palette.inkSecondary)
                }
                .font(.mono(.subheadline))
                Spacer()
                Text("~\(shotsLeft) \(shotsLeft == 1 ? "dose" : "doses") left @ \(dose.fixed())g")
                    .font(.footnote.weight(isLow ? .semibold : .regular))
                    .foregroundStyle(isLow ? Palette.sour : Palette.inkSecondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            MeterBar(fraction: bean.remainingFraction, tint: isLow ? Palette.sour : Palette.ink)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var actions: some View {
        HStack(spacing: 8) {
            if bean.isFinished {
                actionButton("Reopen", systemImage: "arrow.uturn.backward", action: onToggleFinished)
                actionButton("Re-buy", systemImage: "shippingbox.and.arrow.backward", action: onRebuy)
                actionButton("New Coffee", systemImage: "plus", action: onNewBean)
            } else {
                actionButton(bean.isFrozen ? "Thaw" : "Freeze", systemImage: bean.isFrozen ? "sun.max" : "snowflake", action: onToggleStorage)
                    .accessibilityLabel(bean.isFrozen ? "Stored in freezer, rest paused. Thaw." : "At room temperature. Freeze.")
                actionButton("Bag Done", systemImage: "checkmark", action: onToggleFinished)
                    .accessibilityLabel("Mark coffee bag as done")
                actionButton("New Bag", systemImage: "plus", action: onRebuy)
            }
        }
    }

    private func actionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(PaperButtonStyle(kind: .inset))
    }
}

private struct EquipmentStrip: View {
    let equipment: EquipmentProfile
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "espressomachine")
                    .font(.title3)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(equipment.machineName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                    Text("\(equipment.summary) · \(equipment.defaultDripper)")
                        .font(.mono(.caption))
                        .foregroundStyle(Palette.inkSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.inkSecondary)
            }
            .padding(14)
            .paperCard(cornerRadius: 18)
        }
        .buttonStyle(.plain)
    }
}

/// "Up next": the last brew's recipe and the tweak to try on the next pull.
private struct LastRecipeCard: View {
    let shot: ShotLog
    var isCarryOver: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Up Next")
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Text(isCarryOver ? "Previous bag · Day \(shot.restDaysAtBrew)" : "Last brew · Day \(shot.restDaysAtBrew)")
                        .font(.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                    BrewMethodBadge(method: shot.brewMethod, dripper: shot.dripper)
                    Spacer(minLength: 4)
                    BalanceChip(balance: shot.tasteBalance)
                }

                metricsWell

                if let tweak = shot.actionableNextTweak, !tweak.isEmpty {
                    Rectangle()
                        .fill(Palette.rule)
                        .frame(height: 1)
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: "arrow.right")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("NEXT TWEAK")
                                .font(.caption2.weight(.bold))
                                .tracking(1.0)
                                .foregroundStyle(Palette.inkSecondary)
                            Text(tweak)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.tint)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(16)
            .paperCard()
        }
    }

    @ViewBuilder
    private var metricsWell: some View {
        HStack(spacing: 0) {
            if shot.brewMethod == .pourOver {
                metric("Grind", value: shot.grindSetting.fixed(), sub: shot.grinderRPM.map { "@\($0)" } ?? shot.feedMethod.shortLabel)
                separator
                metric("Water", value: "\(shot.dose.fixed()) → \(shot.yield.fixed(0))g", sub: ShotFormatter.ratio(shot.ratio, method: .pourOver))
                separator
                metric("Drawdown", value: ShotFormatter.drawdown(shot.totalTime), sub: ShotFormatter.bloom(water: shot.bloomWater, pause: shot.preBrewPause))
                separator
                metric("Temp", value: ShotFormatter.temperature(shot.brewTemperature), sub: ShotFormatter.pours(count: shot.pourCount, agitation: shot.agitation))
            } else {
                metric("Grind", value: shot.grindSetting.fixed(), sub: shot.grinderRPM.map { "@\($0)" } ?? shot.feedMethod.shortLabel)
                separator
                metric("Ratio", value: "\(shot.dose.fixed()) → \(shot.yield.fixed())g", sub: ShotFormatter.ratio(shot.ratio))
                separator
                metric("Time", value: "\(shot.totalTime.fixed())s", sub: ShotFormatter.preBrew(pulse: shot.preBrewPulse, pause: shot.preBrewPause))
                separator
                metric("Temp", value: ShotFormatter.temperature(shot.brewTemperature), sub: "FP \(shot.fullPressureTime.fixed())s")
            }
        }
        .padding(.vertical, 10)
        .background(Palette.inset, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var separator: some View {
        Rectangle()
            .fill(Palette.rule)
            .frame(width: 1, height: 32)
    }

    private func metric(_ label: String, value: String, sub: String) -> some View {
        VStack(spacing: 3) {
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.6)
                .foregroundStyle(Palette.inkSecondary)
            Text(value)
                .font(.mono(.subheadline, weight: .semibold))
                .foregroundStyle(Palette.ink)
            Text(sub)
                .font(.mono(.caption2))
                .foregroundStyle(Palette.inkSecondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
    }
}

/// Compact notebook line for the home screen: pull number, recipe, date · rest · grind, tasting notes, balance.
private struct NotebookPreviewRow: View {
    let shot: ShotLog
    let number: Int

    private var notes: String {
        shot.flavorNotes.joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.mono(.body, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(minWidth: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if shot.brewMethod == .pourOver {
                        BrewMethodBadge(method: .pourOver, dripper: shot.dripper)
                    }
                    Text(ShotFormatter.headline(dose: shot.dose, yield: shot.yield, time: shot.totalTime, method: shot.brewMethod))
                        .font(.mono(.subheadline, weight: .medium))
                        .foregroundStyle(Palette.ink)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.75)

                Text("\(shot.timestamp.formatted(.dateTime.day().month(.abbreviated))) · R\(shot.restDaysAtBrew) · \(ShotFormatter.grind(shot.grindSetting, zeroOffset: shot.grinderZeroOffset, rpm: shot.grinderRPM))")
                    .font(.mono(.caption))
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if shot.flowQuality.isIssue || !notes.isEmpty {
                    HStack(spacing: 6) {
                        FlowBadge(flow: shot.flowQuality, method: shot.brewMethod)
                        if !notes.isEmpty {
                            Text(notes)
                                .font(.footnote)
                                .foregroundStyle(Palette.ink)
                                .lineLimit(2)
                        }
                    }
                    .padding(.top, 2)
                }
            }

            Spacer(minLength: 4)
            BalanceChip(balance: shot.tasteBalance)
                .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }
}

#Preview(traits: .sampleData) {
    ActiveBeanDashboardView()
}
