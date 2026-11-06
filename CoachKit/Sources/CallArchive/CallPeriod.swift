import Foundation

/// Groupe de la liste des calls : « Aujourd'hui », « Cette semaine », puis un groupe par mois.
public struct CallPeriod: Equatable, Identifiable, Sendable {
    /// Nom affiché au-dessus du groupe.
    public var title: String
    /// Calls de la période, du plus récent au plus ancien.
    public var calls: [SavedCall]

    public init(title: String, calls: [SavedCall]) {
        self.title = title
        self.calls = calls
    }

    public var id: String { title }

    /// Calls regroupés par période, du plus récent au plus ancien. Logique pure.
    public static func group(_ calls: [SavedCall], now: Date, calendar: Calendar = .current) -> [CallPeriod] {
        var periods: [CallPeriod] = []
        for call in calls.sorted(by: { $0.startDate > $1.startDate }) {
            let title = title(for: call.startDate, now: now, calendar: calendar)
            if periods.last?.title == title {
                periods[periods.count - 1].calls.append(call)
            } else {
                periods.append(CallPeriod(title: title, calls: [call]))
            }
        }
        return periods
    }

    /// « Aujourd'hui », « Cette semaine », le mois (« Octobre »), ou le mois et l'année pour une autre année.
    static func title(for date: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return "Aujourd'hui"
        }
        if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            return "Cette semaine"
        }
        let format = calendar.isDate(date, equalTo: now, toGranularity: .year) ? "LLLL" : "LLLL yyyy"
        return CallFormat.formatter(format, calendar: calendar).string(from: date).capitalizedFirstLetter
    }
}
