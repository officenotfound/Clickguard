import Foundation
import CoreGraphics
import ClickGuardCore

// Tiny assertion harness (XCTest isn't available with Command Line Tools only).
var failures = 0
var checks = 0
func check(_ cond: Bool, _ msg: String) {
    checks += 1
    if !cond { failures += 1; print("  ✗ FAIL: \(msg)") }
}
func eq<T: Equatable>(_ a: T, _ b: T, _ msg: String) {
    check(a == b, "\(msg)  (got \(a), expected \(b))")
}
func section(_ name: String) { print("• \(name)") }

let origin = CGPoint(x: 100, y: 100)
func engine(_ mutate: (inout DebounceEngine.Config) -> Void = { _ in }) -> DebounceEngine {
    var c = DebounceEngine.Config(); mutate(&c); return DebounceEngine(config: c)
}

typealias Action = DebounceEngine.Action

// ──────────────────────────────────────────────────────────────────────────
section("Click debounce")

// Normal clicks always pass
do {
    let e = engine { $0.clickThresholdMs = 50 }
    var t = 0.0, ok = true
    for _ in 0..<1000 {
        if e.onDown(button: 0, now: t, location: origin) != .pass { ok = false }
        if e.onUp(button: 0, now: t + 0.02, location: origin) != .pass { ok = false }
        t += 0.5
    }
    check(ok, "1000 well-spaced clicks all pass")
}

// Bounce + its orphaned up are both suppressed
do {
    let e = engine { $0.clickThresholdMs = 50 }
    _ = e.onDown(button: 0, now: 0.0, location: origin)
    _ = e.onUp(button: 0, now: 0.02, location: origin)
    eq(e.onDown(button: 0, now: 0.030, location: origin), .suppress, "press 10ms after release is filtered")
    eq(e.onUp(button: 0, now: 0.035, location: origin), .suppress, "the up after a suppressed down is also filtered")
}

// Just over threshold passes
do {
    let e = engine { $0.clickThresholdMs = 50 }
    _ = e.onDown(button: 0, now: 0.0, location: origin)
    _ = e.onUp(button: 0, now: 0.02, location: origin)
    eq(e.onDown(button: 0, now: 0.080, location: origin), .pass, "60ms gap (> 50ms) passes")
}

// Disabled button never filtered
do {
    let e = engine { $0.clickThresholdMs = 50; $0.rightEnabled = false }
    _ = e.onDown(button: 1, now: 0.0, location: origin)
    _ = e.onUp(button: 1, now: 0.01, location: origin)
    eq(e.onDown(button: 1, now: 0.012, location: origin), .pass, "disabled right button isn't filtered")
}

// Bounce storm — 10k events, no stuck state
do {
    let e = engine { $0.clickThresholdMs = 50 }
    var t = 0.0, suppressed = 0, passed = 0, bad = 0
    for i in 0..<10_000 {
        let d = e.onDown(button: 0, now: t, location: origin)
        let isBounce = (i % 2 == 1)
        switch d {
        case .suppress: suppressed += 1; _ = e.onUp(button: 0, now: t + 0.002, location: origin)
        case .pass:     passed += 1;     _ = e.onUp(button: 0, now: t + 0.01, location: origin)
        default:        bad += 1
        }
        t += isBounce ? 0.005 : 0.4
    }
    eq(suppressed + passed, 10_000, "every event resolved to pass/suppress")
    check(bad == 0, "no unexpected actions in storm")
    check(suppressed > 0 && passed > 0, "storm produced both suppressed and passed clicks")
}

// Buttons independent
do {
    let e = engine { $0.clickThresholdMs = 50 }
    _ = e.onDown(button: 0, now: 0.0, location: origin)
    _ = e.onUp(button: 0, now: 0.01, location: origin)
    eq(e.onDown(button: 0, now: 0.015, location: origin), .suppress, "left bounce caught")
    _ = e.onUp(button: 0, now: 0.02, location: origin)
    eq(e.onDown(button: 1, now: 0.016, location: origin), .pass, "right unaffected by left bounce")
}

// ──────────────────────────────────────────────────────────────────────────
section("Scroll jitter")

do {
    let e = engine { $0.scrollEnabled = true; $0.scrollThresholdMs = 50 }
    var t = 0.0, ok = true
    for _ in 0..<1000 {
        if e.onScroll(deltaVertical: -1, deltaHorizontal: 0, now: t) != .pass { ok = false }
        t += 0.005
    }
    check(ok, "1000 same-direction scroll ticks all pass")
}
do {
    let e = engine { $0.scrollEnabled = true; $0.scrollThresholdMs = 50 }
    eq(e.onScroll(deltaVertical: -1, deltaHorizontal: 0, now: 0.0), .pass, "first scroll passes")
    eq(e.onScroll(deltaVertical: 1, deltaHorizontal: 0, now: 0.010), .suppress, "10ms reversal = jitter, suppressed")
}
do {
    let e = engine { $0.scrollEnabled = true; $0.scrollThresholdMs = 50 }
    eq(e.onScroll(deltaVertical: -1, deltaHorizontal: 0, now: 0.0), .pass, "scroll down")
    eq(e.onScroll(deltaVertical: 1, deltaHorizontal: 0, now: 0.200), .pass, "200ms later reversal is intentional")
}
do {
    let e = engine { $0.scrollEnabled = false }
    eq(e.onScroll(deltaVertical: -1, deltaHorizontal: 0, now: 0.0), .pass, "disabled: pass")
    eq(e.onScroll(deltaVertical: 1, deltaHorizontal: 0, now: 0.001), .pass, "disabled: pass even on instant reversal")
}
do {
    let e = engine { $0.scrollEnabled = true; $0.scrollThresholdMs = 50 }
    eq(e.onScroll(deltaVertical: -1, deltaHorizontal: 0, now: 0.0), .pass, "vertical scroll")
    eq(e.onScroll(deltaVertical: 0, deltaHorizontal: 1, now: 0.005), .pass, "horizontal axis independent of vertical")
}

// ──────────────────────────────────────────────────────────────────────────
section("Drag & drop")

// Plain click not delayed
do {
    let e = engine { $0.dragEnabled = true }
    eq(e.onDown(button: 0, now: 0.0, location: origin), .pass, "drag-fix on: plain down passes")
    eq(e.onUp(button: 0, now: 0.05, location: origin), .pass, "drag-fix on: non-drag click not delayed")
}

// Drag release is delayed
do {
    let e = engine { $0.dragEnabled = true; $0.dragStartDelayMs = 1000; $0.dragReleaseDelayMs = 150 }
    _ = e.onDown(button: 0, now: 0.0, location: origin)
    e.onDragged(button: 0, now: 1.1, location: CGPoint(x: 300, y: 300))
    check(e.isDraggingNow(0), "drag engaged after 1.1s hold + move")
    eq(e.onUp(button: 0, now: 1.2, location: CGPoint(x: 300, y: 300)),
       .suppressAndScheduleRelease(button: 0), "drag release is delayed")
    check(e.isPendingRelease(0), "release pending after drag up")
}

// Glitch release during drag is cancelled
do {
    let e = engine { $0.dragEnabled = true; $0.dragStartDelayMs = 1000; $0.dragReleaseDelayMs = 150 }
    _ = e.onDown(button: 0, now: 0.0, location: origin)
    e.onDragged(button: 0, now: 1.1, location: CGPoint(x: 300, y: 300))
    eq(e.onUp(button: 0, now: 1.2, location: CGPoint(x: 300, y: 300)),
       .suppressAndScheduleRelease(button: 0), "glitch up schedules release")
    eq(e.onDown(button: 0, now: 1.25, location: CGPoint(x: 300, y: 300)),
       .suppressAndCancelRelease(button: 0), "re-press within window cancels release (drag continues)")
    check(!e.isPendingRelease(0), "pending release cleared after cancel")
}

// Timer completes a real release
do {
    let e = engine { $0.dragEnabled = true; $0.dragStartDelayMs = 1000; $0.dragReleaseDelayMs = 150 }
    _ = e.onDown(button: 0, now: 0.0, location: origin)
    e.onDragged(button: 0, now: 1.1, location: CGPoint(x: 300, y: 300))
    _ = e.onUp(button: 0, now: 1.2, location: CGPoint(x: 300, y: 300))
    e.releaseTimerFired(button: 0, now: 1.35)
    check(!e.isPendingRelease(0), "release completed when timer fires")
    eq(e.onDown(button: 0, now: 2.0, location: origin), .pass, "subsequent click works normally")
}

// Short hold doesn't enter drag
do {
    let e = engine { $0.dragEnabled = true; $0.dragStartDelayMs = 1000 }
    _ = e.onDown(button: 0, now: 0.0, location: origin)
    e.onDragged(button: 0, now: 0.1, location: CGPoint(x: 400, y: 400))
    check(!e.isDraggingNow(0), "100ms hold doesn't engage drag-lock")
    eq(e.onUp(button: 0, now: 0.12, location: CGPoint(x: 400, y: 400)), .pass, "quick drag-then-release passes")
}

// Reset clears everything
do {
    let e = engine { $0.dragEnabled = true; $0.clickThresholdMs = 50 }
    _ = e.onDown(button: 0, now: 0.0, location: origin)
    e.onDragged(button: 0, now: 1.1, location: CGPoint(x: 300, y: 300))
    _ = e.onUp(button: 0, now: 1.2, location: CGPoint(x: 300, y: 300))
    check(e.isPendingRelease(0), "pending before reset")
    e.reset()
    check(!e.isPendingRelease(0) && !e.isDraggingNow(0), "reset clears drag state")
    eq(e.onDown(button: 0, now: 5.0, location: origin), .pass, "first press after reset is clean")
}

// ──────────────────────────────────────────────────────────────────────────
print("")
if failures == 0 {
    print("✅ All \(checks) checks passed.")
    exit(0)
} else {
    print("❌ \(failures) of \(checks) checks FAILED.")
    exit(1)
}
