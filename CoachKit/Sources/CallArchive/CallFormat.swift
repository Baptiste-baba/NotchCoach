import Foundation

/// Libellés d'un call dans la fenêtre, en français. Logique pure.
public enum CallFormat {
    /// Titre écrit par Claude, ou la date du call tant qu'il n'est pas écrit (« Call du 6 novembre à 16 h 20 »).
    public static func title(of call: SavedCall, calendar: Calendar = .current) -> String {
        if case .written(let recap) = call.recapStatus {
            return recap.title
        }
        return "Call du \(formatter("d MMMM", calendar: calendar).string(from: call.startDate)) à \(time(of: call.startDate, calendar: calendar))"
    }

    /// Durée arrondie à la minute : « moins d'1 min », « 14 min », « 1 h 05 ».
    public static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        if minutes < 1 {
            return "moins d'1 min"
        }
        return minutes < 60 ? "\(minutes) min" : "\(minutes / 60) h \(String(format: "%02d", minutes % 60))"
    }

    /// Heure à la française : « 16 h 20 ».
    public static func time(of date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return "\(components.hour ?? 0) h \(String(format: "%02d", components.minute ?? 0))"
    }

    /// Ligne de la liste sous le titre : « Vente, 14 min, 16 h 20 ». L'heure pour un call du jour, le jour de la
    /// semaine pour un call de la semaine, la date sinon.
    public static func listDetail(of call: SavedCall, now: Date, calendar: Calendar = .current) -> String {
        let when: String
        if calendar.isDate(call.startDate, inSameDayAs: now) {
            when = time(of: call.startDate, calendar: calendar)
        } else if calendar.isDate(call.startDate, equalTo: now, toGranularity: .weekOfYear) {
            when = formatter("EEEE", calendar: calendar).string(from: call.startDate)
        } else {
            when = formatter("d MMMM", calendar: calendar).string(from: call.startDate)
        }
        return "\(call.profile.name), \(duration(call.duration)), \(when)"
    }

    /// En-tête du call : « Aujourd'hui à 16 h 20, profil Vente, 14 min ».
    public static func headerDetail(of call: SavedCall, now: Date, calendar: Calendar = .current) -> String {
        let day = calendar.isDate(call.startDate, inSameDayAs: now)
            ? "Aujourd'hui"
            : "Le \(formatter("d MMMM yyyy", calendar: calendar).string(from: call.startDate))"
        return "\(day) à \(time(of: call.startDate, calendar: calendar)), profil \(call.profile.name), \(duration(call.duration))"
    }

    /// Formateur en français, sur le calendrier et le fuseau de `calendar`.
    static func formatter(_ format: String, calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = format
        return formatter
    }
}

extension String {
    /// « octobre » devient « Octobre ».
    var capitalizedFirstLetter: String {
        prefix(1).uppercased() + dropFirst()
    }
}
