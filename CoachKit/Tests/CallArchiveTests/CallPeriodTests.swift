import Foundation
import Testing
@testable import CallArchive

/// Vendredi 6 novembre 2026, 19 h, à Paris : la semaine va du lundi 2 au dimanche 8.
private let now = date("2026-11-06T19:00:00+01:00")

struct CallPeriodTests {
    @Test func callsAreGroupedFromTheMostRecent() {
        let calls = [
            makeCall(startDate: date("2025-12-15T10:00:00+01:00")),
            makeCall(startDate: date("2026-11-06T09:00:00+01:00")),
            makeCall(startDate: date("2026-10-28T10:00:00+01:00")),
            makeCall(startDate: date("2026-11-01T10:00:00+01:00")),
            makeCall(startDate: date("2026-11-06T16:20:00+01:00")),
            makeCall(startDate: date("2026-11-03T10:00:00+01:00")),
        ]

        let periods = CallPeriod.group(calls, now: now, calendar: paris)

        #expect(periods.map(\.title) == ["Aujourd'hui", "Cette semaine", "Novembre", "Octobre", "Décembre 2025"])
        #expect(periods[0].calls.map(\.startDate) == [date("2026-11-06T16:20:00+01:00"), date("2026-11-06T09:00:00+01:00")])
        #expect(periods.allSatisfy { !$0.calls.isEmpty })
    }

    @Test func noCallGivesNoPeriod() {
        #expect(CallPeriod.group([], now: now, calendar: paris).isEmpty)
    }
}
