import Foundation

public struct BreakReminderPolicy: Sendable {
    public let reminderInterval: TimeInterval
    public let snoozeInterval: TimeInterval

    public init(reminderInterval: TimeInterval = 60 * 60, snoozeInterval: TimeInterval = 10 * 60) {
        self.reminderInterval = reminderInterval
        self.snoozeInterval = snoozeInterval
    }

    public func shouldRemind(state: BreakReminderState, now: Date = Date()) -> Bool {
        guard TimeInterval(state.activeSeconds) >= reminderInterval else { return false }

        if let snoozedUntil = state.snoozedUntil, now < snoozedUntil {
            return false
        }

        guard let lastReminderAt = state.lastReminderAt else { return true }
        return now.timeIntervalSince(lastReminderAt) >= snoozeInterval
    }

    public func markReminderShown(state: BreakReminderState, now: Date = Date()) -> BreakReminderState {
        BreakReminderState(
            activeSeconds: state.activeSeconds,
            lastReminderAt: now,
            snoozedUntil: state.snoozedUntil
        )
    }

    public func snooze(state: BreakReminderState, now: Date = Date()) -> BreakReminderState {
        BreakReminderState(
            activeSeconds: state.activeSeconds,
            lastReminderAt: now,
            snoozedUntil: now.addingTimeInterval(snoozeInterval)
        )
    }

    public func markBreakTaken(state: BreakReminderState) -> BreakReminderState {
        BreakReminderState(activeSeconds: 0, lastReminderAt: nil, snoozedUntil: nil)
    }
}
