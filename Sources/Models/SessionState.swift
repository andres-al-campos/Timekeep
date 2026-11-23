import Foundation

/// One app's sessions: the rules, the day's row and bank, and the running
/// session. Foundation only, so `tests/session-state.sh` can compile it
/// without Xcode.
///
/// The clock is time used plus a "running since" stamp, never a count of
/// ticks: an intent runs for a moment and is gone, so the only things that
/// survive between events are timestamps.
struct SessionState: Codable, Equatable {
    struct Rules: Codable, Equatable {
        var length: TimeInterval = 40 * 60
        var perDay: Int = 3
        var bankSize: Int = 1
    }

    struct Running: Codable, Equatable {
        /// Length of this session, carryover included.
        var length: TimeInterval
        /// Time spent in the app before the current visit.
        var used: TimeInterval = 0
        /// When the current visit began; nil while the app is closed, so
        /// time away from the app never counts.
        var since: Date?

        func usedTime(at now: Date) -> TimeInterval {
            used + (since.map { max(0, now.timeIntervalSince($0)) } ?? 0)
        }

        func remaining(at now: Date) -> TimeInterval {
            length - usedTime(at: now)
        }
    }

    var rules = Rules()
    /// Start of the day the row belongs to.
    var day: Date
    var usedToday = 0
    var banked = 0
    /// Time a session ended with, added to the next one.
    var carryover: TimeInterval = 0
    var running: Running?

    /// The Focus ends at the computed time, and the check that follows can land
    /// a moment before it by the clock; this much left still counts as over.
    static let endSlack: TimeInterval = 1

    init(rules: Rules = Rules(), now: Date, calendar: Calendar = .current) {
        self.rules = rules
        self.day = calendar.startOfDay(for: now)
    }

    var rowLeft: Int { max(0, rules.perDay - usedToday) }
    var canStart: Bool { running == nil && (rowLeft > 0 || banked > 0) }

    /// Length the next start would give.
    var nextLength: TimeInterval { rules.length + carryover }

    // MARK: Day reset

    /// What the row didn't use goes to the bank, up to its size; a day with no
    /// visit saves its whole row. A session running at the reset ends there and
    /// what it had left goes to the next session.
    mutating func rollDay(to now: Date, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        guard today > day else { return }

        if let running {
            let resetAt = calendar.date(byAdding: .day, value: 1, to: day) ?? today
            carryover = max(0, running.remaining(at: min(now, resetAt)))
            self.running = nil
        }
        let skipped = max(0, (calendar.dateComponents([.day], from: day, to: today).day ?? 1) - 1)
        banked = min(rules.bankSize, banked + rowLeft + skipped * rules.perDay)
        usedToday = 0
        day = today
    }

    // MARK: Lifecycle

    /// Costs one dot: the row first, the bank once the row is empty.
    @discardableResult
    mutating func start(at now: Date, calendar: Calendar = .current) -> Bool {
        rollDay(to: now, calendar: calendar)
        guard canStart else { return false }
        if rowLeft > 0 { usedToday += 1 } else { banked -= 1 }
        running = Running(length: nextLength)
        carryover = 0
        return true
    }

    /// The app came to the front. Returns when the session runs out, or nil
    /// when there's no session to resume and the gate should come up.
    mutating func enter(at now: Date, calendar: Calendar = .current) -> Date? {
        rollDay(to: now, calendar: calendar)
        guard var running else { return nil }
        if running.since == nil { running.since = now }
        self.running = running
        let left = running.remaining(at: now)
        guard left > Self.endSlack else {
            finish(at: now)
            return nil
        }
        return now.addingTimeInterval(left)
    }

    /// The app left the front: bank the visit so time away doesn't count.
    mutating func leave(at now: Date, calendar: Calendar = .current) {
        // The reset first: a visit across midnight ends at the reset, and
        // banking it to `now` would count time after the session was over.
        rollDay(to: now, calendar: calendar)
        guard var running, running.since != nil else { return }
        running.used = running.usedTime(at: now)
        running.since = nil
        self.running = running
    }

    /// Ends the session when its time is up. Returns whether it did.
    @discardableResult
    mutating func endIfOver(at now: Date) -> Bool {
        guard let running, running.remaining(at: now) <= Self.endSlack else { return false }
        finish(at: now)
        return true
    }

    /// Ends the session now; the time left goes to the next one.
    mutating func endEarly(at now: Date) {
        finish(at: now)
    }

    private mutating func finish(at now: Date) {
        guard let running else { return }
        carryover = max(0, running.remaining(at: now))
        if carryover <= Self.endSlack { carryover = 0 }
        self.running = nil
    }
}
