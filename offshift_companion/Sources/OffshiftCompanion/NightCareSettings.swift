import Foundation
import OffshiftCompanionCore

/// Stores only the local user's care-window preferences. This object never
/// sends its values to MCP, the Worker, ChatGPT, or Home Assistant.
@MainActor
final class NightCareSettings: ObservableObject {
    private static let enabledKey = "offshift.nightCare.enabled"
    private static let startHourKey = "offshift.nightCare.startHour"
    private static let endHourKey = "offshift.nightCare.endHour"
    private static let earlyStartTomorrowKey = "offshift.nightCare.earlyStartTomorrow"

    @Published private(set) var isEnabled: Bool
    @Published private(set) var startHour: Int
    @Published private(set) var endHour: Int
    @Published private(set) var hasEarlyStartTomorrow: Bool
    var onSettingsChanged: (() -> Void)?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: Self.enabledKey)
        let storedStart = defaults.object(forKey: Self.startHourKey) as? Int
        let storedEnd = defaults.object(forKey: Self.endHourKey) as? Int
        let resolvedStartHour: Int
        if let storedStart, (0..<24).contains(storedStart) {
            resolvedStartHour = storedStart
        } else {
            resolvedStartHour = 23
        }
        startHour = resolvedStartHour
        if let storedEnd, (0..<24).contains(storedEnd), storedEnd != resolvedStartHour {
            endHour = storedEnd
        } else {
            endHour = 7
        }
        hasEarlyStartTomorrow = defaults.bool(forKey: Self.earlyStartTomorrowKey)
    }

    var schedule: QuietHoursSchedule {
        QuietHoursSchedule(startHour: startHour, endHour: endHour)
    }

    var summary: String {
        guard isEnabled else { return "Night care is off. Offshift will not use the time of day as a factor." }
        return "Night care is on from \(Self.hourLabel(startHour)) to \(Self.hourLabel(endHour))."
    }

    func isInsideQuietHours(at date: Date = .now) -> Bool {
        isEnabled && schedule.contains(date)
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.enabledKey)
        onSettingsChanged?()
    }

    func setStartHour(_ hour: Int) {
        guard (0..<24).contains(hour), hour != endHour else { return }
        startHour = hour
        defaults.set(hour, forKey: Self.startHourKey)
        onSettingsChanged?()
    }

    func setEndHour(_ hour: Int) {
        guard (0..<24).contains(hour), hour != startHour else { return }
        endHour = hour
        defaults.set(hour, forKey: Self.endHourKey)
        onSettingsChanged?()
    }

    func setEarlyStartTomorrow(_ enabled: Bool) {
        hasEarlyStartTomorrow = enabled
        defaults.set(enabled, forKey: Self.earlyStartTomorrowKey)
        onSettingsChanged?()
    }

    static func hourLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}
