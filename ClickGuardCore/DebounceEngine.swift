import Foundation
import CoreGraphics

/// Pure, deterministic decision core for ClickGuard's mouse filtering.
///
/// It holds no platform state and posts no events — it just answers, for each
/// incoming mouse event, what the OS-level tap should do. The clock is injected
/// (`now` in seconds), so the full behaviour — including drag-release timers —
/// can be exercised in tests without any real event tap.
public final class DebounceEngine {

    public struct Config {
        public var leftEnabled        = true
        public var rightEnabled       = true
        public var middleEnabled      = false
        public var clickThresholdMs   = 50
        public var scrollEnabled      = false
        public var scrollThresholdMs  = 50
        public var dragEnabled        = false
        public var dragStartDelayMs   = 1000
        public var dragReleaseDelayMs = 150

        public init() {}

        public func clickEnabled(_ button: Int) -> Bool {
            switch button {
            case 0:  return leftEnabled
            case 1:  return rightEnabled
            case 2:  return middleEnabled
            default: return false
            }
        }
    }

    public enum Action: Equatable {
        case pass
        case suppress
        case suppressAndScheduleRelease(button: Int)
        case suppressAndCancelRelease(button: Int)
    }

    public enum LogKind: Equatable { case click(Int), scroll, drag }

    public var config: Config

    // Click state
    private var lastUpTime:     [Int: TimeInterval] = [:]
    private var suppressNextUp: [Int: Bool] = [:]

    // Drag state
    private var buttonDownTime:     [Int: TimeInterval] = [:]
    private var buttonDownLocation: [Int: CGPoint] = [:]
    private var isDragging:         [Int: Bool] = [:]
    private var pendingRelease:     Set<Int> = []

    // Scroll state
    private var lastScrollDir:  [Int: Int] = [:]
    private var lastScrollTime: [Int: TimeInterval] = [:]

    /// Optional sink so the adapter (and tests) can observe what got filtered.
    public var onLog: ((LogKind) -> Void)?

    public init(config: Config = Config()) { self.config = config }

    public func reset() {
        lastUpTime = [:]; suppressNextUp = [:]
        buttonDownTime = [:]; buttonDownLocation = [:]; isDragging = [:]
        pendingRelease = []
        lastScrollDir = [:]; lastScrollTime = [:]
    }

    // MARK: - Button down

    public func onDown(button: Int, now: TimeInterval, location: CGPoint) -> Action {
        // A press while a drag-release is pending = chatter mid-drag.
        if config.dragEnabled, pendingRelease.contains(button) {
            pendingRelease.remove(button)
            onLog?(.drag)
            return .suppressAndCancelRelease(button: button)
        }

        if config.clickEnabled(button), let lastUp = lastUpTime[button],
           (now - lastUp) < ms(config.clickThresholdMs) {
            suppressNextUp[button] = true
            onLog?(.click(button))
            return .suppress
        }

        buttonDownTime[button]     = now
        buttonDownLocation[button] = location
        isDragging[button]         = false
        return .pass
    }

    // MARK: - Button up

    public func onUp(button: Int, now: TimeInterval, location: CGPoint) -> Action {
        if suppressNextUp[button] == true {
            suppressNextUp[button] = false
            return .suppress
        }

        if config.dragEnabled, isDragging[button] == true {
            isDragging[button] = false
            pendingRelease.insert(button)
            return .suppressAndScheduleRelease(button: button)
        }

        lastUpTime[button]     = now
        buttonDownTime[button] = nil
        return .pass
    }

    // MARK: - Drag movement

    public func onDragged(button: Int, now: TimeInterval, location: CGPoint) {
        guard config.dragEnabled,
              let downTime = buttonDownTime[button],
              let origin   = buttonDownLocation[button] else { return }
        let heldMs = (now - downTime) * 1000
        let dx = location.x - origin.x
        let dy = location.y - origin.y
        let movedFarEnough = (dx * dx + dy * dy) > 16   // > 4px
        if heldMs >= Double(config.dragStartDelayMs) && movedFarEnough {
            isDragging[button] = true
        }
    }

    /// Called when the delayed-release timer fires with no intervening press.
    public func releaseTimerFired(button: Int, now: TimeInterval) {
        pendingRelease.remove(button)
        lastUpTime[button]     = now
        buttonDownTime[button] = nil
    }

    // MARK: - Scroll

    public func onScroll(deltaVertical: Int, deltaHorizontal: Int, now: TimeInterval) -> Action {
        guard config.scrollEnabled else { return .pass }
        let threshold = ms(config.scrollThresholdMs)
        if suppressScroll(axis: 0, delta: deltaVertical,   now: now, threshold: threshold) ||
           suppressScroll(axis: 1, delta: deltaHorizontal, now: now, threshold: threshold) {
            onLog?(.scroll)
            return .suppress
        }
        return .pass
    }

    private func suppressScroll(axis: Int, delta: Int, now: TimeInterval, threshold: TimeInterval) -> Bool {
        guard delta != 0 else { return false }
        let dir = delta > 0 ? 1 : -1
        if let last = lastScrollDir[axis], last != 0, dir != last,
           let t = lastScrollTime[axis], (now - t) < threshold {
            return true
        }
        lastScrollDir[axis]  = dir
        lastScrollTime[axis] = now
        return false
    }

    // MARK: - Test hooks / introspection

    public func isPendingRelease(_ button: Int) -> Bool { pendingRelease.contains(button) }
    public func isDraggingNow(_ button: Int) -> Bool { isDragging[button] == true }

    private func ms(_ value: Int) -> TimeInterval { Double(value) / 1000.0 }
}
