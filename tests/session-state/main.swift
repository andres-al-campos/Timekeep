import Foundation

var cal = Calendar(identifier: .gregorian)
cal.timeZone = TimeZone(identifier: "UTC")!
let t0 = cal.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 12))!
func at(_ minutes: Double) -> Date { t0.addingTimeInterval(minutes * 60) }

var failures: [String] = []
func expect(_ ok: Bool, _ what: String, line: Int = #line) {
    if !ok { failures.append("line \(line): \(what)") }
}
func approx(_ a: TimeInterval?, _ b: TimeInterval) -> Bool { a.map { abs($0 - b) < 0.001 } ?? false }

let rules = SessionState.Rules(length: 20 * 60, perDay: 3, bankSize: 1)

// No session: entering brings up the gate.
do {
    var s = SessionState(rules: rules, now: t0, calendar: cal)
    expect(s.enter(at: at(0), calendar: cal) == nil, "entering with no session returns nil (gate)")
}

// Time away from the app doesn't count.
do {
    var s = SessionState(rules: rules, now: t0, calendar: cal)
    s.start(at: at(0), calendar: cal)
    let end1 = s.enter(at: at(0), calendar: cal)
    expect(end1 == at(20), "first visit ends 20 minutes out, got \(String(describing: end1))")
    s.leave(at: at(5), calendar: cal)
    let end2 = s.enter(at: at(65), calendar: cal)
    expect(end2 == at(80), "after 5 used and an hour away, 15 are left, got \(String(describing: end2))")
}

// Running out ends the session; nothing carries.
do {
    var s = SessionState(rules: rules, now: t0, calendar: cal)
    s.start(at: at(0), calendar: cal)
    _ = s.enter(at: at(0), calendar: cal)
    expect(!s.endIfOver(at: at(10)), "not over at 10 of 20 minutes")
    expect(s.endIfOver(at: at(20)), "over at 20 minutes")
    expect(s.running == nil && s.carryover == 0, "ended with nothing carried")
    expect(s.enter(at: at(21), calendar: cal) == nil, "the gate comes back after it ends")
}

// The Focus check can land a moment early and still ends it.
do {
    var s = SessionState(rules: rules, now: t0, calendar: cal)
    s.start(at: at(0), calendar: cal)
    _ = s.enter(at: at(0), calendar: cal)
    expect(s.endIfOver(at: at(20).addingTimeInterval(-0.5)), "half a second early still counts as over")
}

// Closing the app turns the Focus off: that check must not end the session.
do {
    var s = SessionState(rules: rules, now: t0, calendar: cal)
    s.start(at: at(0), calendar: cal)
    _ = s.enter(at: at(0), calendar: cal)
    s.leave(at: at(3), calendar: cal)
    expect(!s.endIfOver(at: at(3)), "leaving with time left isn't over")
    expect(s.running != nil, "the session is still there to resume")
}

// Ending early keeps the time left for the next session, and costs the dot.
do {
    var s = SessionState(rules: rules, now: t0, calendar: cal)
    s.start(at: at(0), calendar: cal)
    _ = s.enter(at: at(0), calendar: cal)
    s.endEarly(at: at(8))
    expect(approx(s.carryover, 12 * 60), "12 minutes carried, got \(s.carryover / 60)")
    expect(s.rowLeft == 2, "the early end still cost its dot")
    s.start(at: at(30), calendar: cal)
    expect(approx(s.running?.length, 32 * 60), "next session is 20 + 12 minutes")
    expect(s.carryover == 0, "carryover is spent by the start")
}

// The row runs out, then the bank, then nothing.
do {
    var s = SessionState(rules: rules, now: t0, calendar: cal)
    s.banked = 1
    for i in 0..<3 {
        expect(s.start(at: at(Double(i)), calendar: cal), "start \(i + 1) uses the row")
        s.endEarly(at: at(Double(i)))
    }
    s.carryover = 0
    expect(s.start(at: at(5), calendar: cal), "fourth start uses the bank")
    expect(s.banked == 0, "bank spent")
    s.endEarly(at: at(5))
    expect(!s.start(at: at(6), calendar: cal), "nothing left to start")
}

// Day reset: leftovers bank up to its size; a running session ends with its time carried.
do {
    var s = SessionState(rules: rules, now: t0, calendar: cal)
    // In at 23:50, out at 00:30: 10 minutes run before midnight.
    s.start(at: at(60 * 11 + 50), calendar: cal)
    _ = s.enter(at: at(60 * 11 + 50), calendar: cal)
    s.leave(at: at(60 * 12 + 30), calendar: cal)
    expect(s.running == nil, "a session running across midnight ends at the reset")
    expect(approx(s.carryover, 10 * 60), "the 10 minutes before midnight were used, 10 carry, got \(s.carryover / 60)")
    expect(s.banked == 1 && s.usedToday == 0, "two unused dots bank 1 (bank size 1); the row refills")
}

// Law: whatever the order of visits, used time is the time spent inside.
do {
    var rng = SystemRandomNumberGenerator()
    for trial in 0..<500 {
        var s = SessionState(rules: SessionState.Rules(length: 10_000 * 60, perDay: 1, bankSize: 0), now: t0, calendar: cal)
        s.start(at: t0, calendar: cal)
        var now = t0, inside: TimeInterval = 0, isIn = false
        for _ in 0..<Int.random(in: 1...30, using: &rng) {
            let step = TimeInterval(Int.random(in: 0...600, using: &rng))
            if isIn { inside += step }
            now = now.addingTimeInterval(step)
            if Bool.random(using: &rng) { _ = s.enter(at: now, calendar: cal); isIn = true }
            else { s.leave(at: now, calendar: cal); isIn = false }
        }
        let used = s.running?.usedTime(at: now) ?? -1
        if abs(used - inside) > 0.001 {
            failures.append("law, trial \(trial): used \(used)s but \(inside)s were spent inside")
            break
        }
    }
}

if failures.isEmpty {
    print("✓ session-state: time away doesn't count, early ends carry, the row and bank refill at the day reset.")
} else {
    failures.forEach { print("✗ session-state: \($0)") }
    print("Fix SessionState.swift, or the test if the rule changed.")
    exit(1)
}
