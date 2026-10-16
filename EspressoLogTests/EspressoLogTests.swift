import Foundation
import Testing
import SwiftData
@testable import EspressoLog

@Suite("Espresso Dial-In Domain & Intelligence")
struct EspressoLogTests {

    // MARK: - CoffeeBean Rest Calculation

    @Test("Rest days increment at room temperature and pause when frozen")
    func restDaysPauseWhenFrozen() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let roastDate = calendar.date(from: DateComponents(year: 2026, month: 9, day: 6))!
        let day16 = calendar.date(from: DateComponents(year: 2026, month: 9, day: 22))!
        let day22Freeze = calendar.date(from: DateComponents(year: 2026, month: 9, day: 28))!
        let day40InFreezer = calendar.date(from: DateComponents(year: 2026, month: 10, day: 16))!

        let roomTempDays = CoffeeBean.restDays(
            roastDate: roastDate,
            isFrozen: false,
            freezeDate: nil,
            frozenDaysBanked: 0,
            on: day16,
            calendar: calendar
        )
        #expect(roomTempDays == 16)

        let frozenDays = CoffeeBean.restDays(
            roastDate: roastDate,
            isFrozen: true,
            freezeDate: day22Freeze,
            frozenDaysBanked: 0,
            on: day40InFreezer,
            calendar: calendar
        )
        #expect(frozenDays == 22)
    }

    @Test("Thawing a bean banks frozen days and resumes counting")
    func freezeAndThawCycle() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let roastDate = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!
        let freezeOnDay20 = calendar.date(from: DateComponents(year: 2026, month: 9, day: 21))!
        let thawOnDay30 = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))!
        let brewOnDay33 = calendar.date(from: DateComponents(year: 2026, month: 10, day: 4))!

        let bean = CoffeeBean(
            name: "Colombia Las Flores",
            roaster: "Meron",
            variety: "Bourbon Aji",
            process: "Thermal Shock Washed",
            roastDate: roastDate
        )

        bean.freeze(on: freezeOnDay20)
        #expect(bean.restDays(on: thawOnDay30, calendar: calendar) == 20)

        bean.thaw(on: thawOnDay30, calendar: calendar)
        #expect(bean.frozenDaysBanked == 10)
        #expect(bean.restDays(on: brewOnDay33, calendar: calendar) == 23)
    }

    // MARK: - ShotLog Computed Properties

    @Test("Ratio, fullPressureTime, positive grind clamping, and integer 0-point offset")
    func shotComputedProperties() {
        let shot = ShotLog(
            dose: 20.0,
            yield: 48.0,
            totalTime: 28.0,
            grindSetting: 0.5,
            grinderZeroOffset: -1,
            grinderRPM: 1200,
            feedMethod: .slowFeed,
            brewTemperature: 93.5,
            preBrewPulse: 3.0,
            preBrewPause: 5.0,
            flowQuality: .smoothCone,
            tasteBalance: .balancedSweet
        )

        #expect(abs(shot.ratio - 2.4) < 0.0001)
        #expect(abs(shot.fullPressureTime - 20.0) < 0.0001)
        #expect(shot.grindSetting == 0.5)
        #expect(shot.grinderZeroOffset == -1)
        #expect(shot.notebookLine.contains("G 0.5 (0pt -1) @1200"))
    }

    // MARK: - Extraction Insights Engine

    @Test("Bitter + fast full-pressure (<18s) + Slow Feed flags micro-channeling / excessive yield")
    func bitterFastSlowFeedInsight() {
        let snapshot = ShotSnapshot(
            dose: 20.0,
            yield: 50.0,
            totalTime: 25.0,
            grindSetting: 0.5,
            grinderZeroOffset: -1,
            grinderRPM: 1200,
            feedMethod: .slowFeed,
            brewTemperature: 93.5,
            preBrewPulse: 3.0,
            preBrewPause: 5.0, // fullPressureTime = 25 - 8 = 17.0s (< 18s)
            flowQuality: .smoothCone,
            tasteBalance: .overExtractedBitter,
            restDays: 18
        )

        let insights = ExtractionInsightsEngine.insights(for: snapshot, baselineFeed: .slowFeed)
        #expect(insights.contains { $0.rule == .bitterDespiteFastFullPressure })
    }

    @Test("Switching from Slow Feed to Fast Dump triggers coarser grind hint")
    func feedSwitchHint() {
        let snapshot = ShotSnapshot(
            dose: 20.0,
            yield: 48.0,
            totalTime: 28.0,
            grindSetting: 0.5,
            grinderZeroOffset: -1,
            grinderRPM: 1200,
            feedMethod: .fastDump,
            brewTemperature: 93.5,
            preBrewPulse: 3.0,
            preBrewPause: 5.0,
            flowQuality: .smoothCone,
            tasteBalance: .balancedSweet,
            restDays: 18
        )

        let insights = ExtractionInsightsEngine.insights(for: snapshot, baselineFeed: .slowFeed)
        #expect(insights.contains { $0.rule == .feedSwitchToDump })
    }

    // MARK: - Pre-fill & Keypad ViewModel

    @Test("ViewModel pre-fills positive grind setting and integer 0-point offset from previous shot")
    @MainActor
    func viewModelPrefillsAndEdits() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        SampleData.insertNotebookSample(in: container.mainContext)

        let beans = try container.mainContext.fetch(FetchDescriptor<CoffeeBean>())
        let bean = try #require(beans.first)

        let vm = ShotLoggingViewModel(bean: bean, equipment: nil)
        // Pre-filled from Pull #3 (dose 20.0g, grind 0.5, 0pt offset -1, PB 3/5, temp 94.0°C)
        #expect(vm.dose == 20.0)
        #expect(vm.grindSetting == 0.5)
        #expect(vm.grinderZeroOffset == -1)
        #expect(vm.grindRange.lowerBound == 0)
        #expect(vm.preBrewPulse == 3.0)
        #expect(vm.preBrewPause == 5.0)

        // Active field starts on Yield; typing "46.5" replaces the previous 48.5g yield
        vm.press(.digit(4))
        vm.press(.digit(6))
        vm.press(.decimal)
        vm.press(.digit(5))
        vm.advance()
        #expect(vm.yield == 46.5)
        #expect(vm.isChanged(.yield))
        #expect(!vm.isChanged(.dose))
    }

    // MARK: - Bag Weight, Shots Remaining & Search

    @Test("Bag weight tracks used grams and estimates remaining shots based on usual dose")
    @MainActor
    func bagWeightAndShotsRemaining() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        SampleData.insertNotebookSample(in: container.mainContext)

        let beans = try container.mainContext.fetch(FetchDescriptor<CoffeeBean>())
        let bean = try #require(beans.first)

        // 250g bag with 3 pulls of 20.0g = 60.0g used, 190.0g left -> 9 shots left at 20.0g dose
        #expect(bean.bagWeightGrams == 250.0)
        #expect(abs(bean.usedGrams - 60.0) < 0.001)
        #expect(abs(bean.remainingGrams - 190.0) < 0.001)
        #expect(bean.estimatedShotsRemaining() == 9)
        #expect(bean.matchesSearch("Flores"))
        #expect(bean.matchesSearch("meron"))
        #expect(bean.matchesSearch("Bourbon Aji"))
        #expect(!bean.matchesSearch("Ethiopia"))
    }

    @Test("Every FlowQuality and TasteBalance combination yields actionable advice")
    func flowAndBalanceMatrixAdvice() {
        for flow in FlowQuality.allCases {
            for balance in TasteBalance.allCases {
                let snapshot = ShotSnapshot(
                    dose: 20.0,
                    yield: 48.0,
                    totalTime: 29.0,
                    grindSetting: 0.5,
                    grinderZeroOffset: -1,
                    grinderRPM: 1200,
                    feedMethod: .slowFeed,
                    brewTemperature: 93.5,
                    preBrewPulse: 3.0,
                    preBrewPause: 5.0,
                    flowQuality: flow,
                    tasteBalance: balance,
                    restDays: 18
                )
                let insights = ExtractionInsightsEngine.insights(for: snapshot, baselineFeed: .slowFeed)
                #expect(!insights.isEmpty)
            }
        }
    }
}
