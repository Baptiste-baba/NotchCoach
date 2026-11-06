import Foundation
import Testing
@testable import CallArchive

/// Vendredi 6 novembre 2026, 19 h, à Paris.
private let now = date("2026-11-06T19:00:00+01:00")

struct CallFormatTests {
    @Test(arguments: [(20.0, "moins d'1 min"), (61.0, "1 min"), (850.0, "14 min"), (3900.0, "1 h 05")] as [(TimeInterval, String)])
    func durationIsRoundedToTheMinute(seconds: TimeInterval, label: String) {
        #expect(CallFormat.duration(seconds) == label)
    }

    @Test func timeIsWrittenTheFrenchWay() {
        #expect(CallFormat.time(of: date("2026-11-06T16:20:00+01:00"), calendar: paris) == "16 h 20")
        #expect(CallFormat.time(of: date("2026-11-06T09:05:00+01:00"), calendar: paris) == "9 h 05")
    }

    @Test func titleIsTheDateUntilTheRecapIsWritten() {
        #expect(CallFormat.title(of: makeCall(), calendar: paris) == "Call du 6 novembre à 16 h 20")
        #expect(CallFormat.title(of: makeCall(recapStatus: .failed(reason: "réseau")), calendar: paris) == "Call du 6 novembre à 16 h 20")
        #expect(CallFormat.title(of: makeCall(recapStatus: .written(recap: sampleRecap)), calendar: paris) == "Objection prix, Mme Martin")
    }

    @Test func listDetailGivesTheTimeTheWeekdayOrTheDate() {
        let today = makeCall(startDate: date("2026-11-06T16:20:00+01:00"))
        let thisWeek = makeCall(startDate: date("2026-11-03T10:00:00+01:00"))
        let older = makeCall(startDate: date("2026-10-28T10:00:00+01:00"))

        #expect(CallFormat.listDetail(of: today, now: now, calendar: paris) == "Vente, 14 min, 16 h 20")
        #expect(CallFormat.listDetail(of: thisWeek, now: now, calendar: paris) == "Vente, 14 min, mardi")
        #expect(CallFormat.listDetail(of: older, now: now, calendar: paris) == "Vente, 14 min, 28 octobre")
    }

    @Test func headerDetailSaysTodayOrTheFullDate() {
        let today = makeCall(startDate: date("2026-11-06T16:20:00+01:00"))
        let older = makeCall(startDate: date("2026-10-28T10:00:00+01:00"))

        #expect(CallFormat.headerDetail(of: today, now: now, calendar: paris) == "Aujourd'hui à 16 h 20, profil Vente, 14 min")
        #expect(CallFormat.headerDetail(of: older, now: now, calendar: paris) == "Le 28 octobre 2026 à 10 h 00, profil Vente, 14 min")
    }
}
