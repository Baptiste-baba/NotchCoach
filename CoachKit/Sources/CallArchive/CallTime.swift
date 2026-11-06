import Foundation

/// Moment d'un call, depuis son début : « 04:12 », ou « 1:04:12 » au-delà d'une heure. Logique pure.
public enum CallTime {
    /// Libellé d'un moment, en secondes depuis le début du call.
    public static func label(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let (hours, minutes, rest) = (total / 3600, total % 3600 / 60, total % 60)
        let tail = String(format: "%02d:%02d", minutes, rest)
        return hours > 0 ? "\(hours):\(tail)" : tail
    }

    /// Secondes d'un libellé « 04:12 » ou « 1:04:12 » ; `nil` s'il n'en est pas un.
    public static func seconds(from label: String) -> TimeInterval? {
        let parts = label.trimmingCharacters(in: .whitespaces).split(separator: ":").map { Int($0) }
        guard (2...3).contains(parts.count), parts.allSatisfy({ $0 != nil && $0! >= 0 }) else { return nil }
        let values = parts.compactMap { $0 }
        guard values.dropFirst().allSatisfy({ $0 < 60 }) else { return nil }
        return TimeInterval(values.reduce(0) { $0 * 60 + $1 })
    }
}
