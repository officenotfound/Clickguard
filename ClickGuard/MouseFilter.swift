import Cocoa
import CoreGraphics

struct FilterEvent {
    enum Kind: String {
        case left   = "Left click"
        case right  = "Right click"
        case middle = "Middle click"
        case scroll = "Scroll jitter"
        case drag   = "Drag glitch"
    }
    let kind: Kind
    let date: Date
}

final class MouseFilter: ObservableObject {
    static let shared = MouseFilter()

    @Published private(set) var isRunning = false
    @Published var recentEvents: [FilterEvent] = []

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Marks synthetic events we post ourselves so we never re-process them.
    private let syntheticTag: Int64 = 0x4347_4658   // "CGFX"

    // Click debounce state (index: 0=left, 1=right, 2=middle)
    private var lastUpTime: [Int: TimeInterval] = [:]
    private var suppressNextUp: [Int: Bool] = [:]

    // Scroll-wheel state (axis: 0=vertical, 1=horizontal)
    private var lastScrollDir:  [Int: Int] = [:]
    private var lastScrollTime: [Int: TimeInterval] = [:]

    // Drag-fix state
    private var buttonDownTime:     [Int: TimeInterval] = [:]
    private var buttonDownLocation: [Int: CGPoint] = [:]
    private var isDragging:         [Int: Bool] = [:]
    private var pendingRelease:     [Int: DispatchWorkItem] = [:]

    private init() {}

    // MARK: - Lifecycle

    func start() {
        guard tap == nil else { return }

        let mask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue)    |
            (1 << CGEventType.leftMouseUp.rawValue)      |
            (1 << CGEventType.rightMouseDown.rawValue)   |
            (1 << CGEventType.rightMouseUp.rawValue)     |
            (1 << CGEventType.otherMouseDown.rawValue)   |
            (1 << CGEventType.otherMouseUp.rawValue)     |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.rightMouseDragged.rawValue) |
            (1 << CGEventType.otherMouseDragged.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue)

        tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, info -> Unmanaged<CGEvent>? in
                Unmanaged<MouseFilter>.fromOpaque(info!).takeUnretainedValue()
                    .handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap else { return }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        DispatchQueue.main.async { self.isRunning = true }
    }

    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        self.tap = nil
        runLoopSource = nil
        resetState()
        DispatchQueue.main.async { self.isRunning = false }
    }

    private func resetState() {
        lastUpTime = [:]; suppressNextUp = [:]
        lastScrollDir = [:]; lastScrollTime = [:]
        buttonDownTime = [:]; buttonDownLocation = [:]; isDragging = [:]
        pendingRelease.values.forEach { $0.cancel() }
        pendingRelease = [:]
    }

    // MARK: - Dispatch

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable if macOS disabled us (timeout / input flood)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        // Never touch our own synthetic events
        if event.getIntegerValueField(.eventSourceUserData) == syntheticTag {
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .leftMouseDown:   return handleDown(button: 0, kind: .left,   enabled: Settings.shared.leftEnabled,   event: event)
        case .rightMouseDown:  return handleDown(button: 1, kind: .right,  enabled: Settings.shared.rightEnabled,  event: event)
        case .otherMouseDown:
            let n = Int(event.getIntegerValueField(.mouseEventButtonNumber))
            return handleDown(button: n, kind: .middle, enabled: Settings.shared.middleEnabled && n == 2, event: event)

        case .leftMouseUp:     return handleUp(button: 0, event: event)
        case .rightMouseUp:    return handleUp(button: 1, event: event)
        case .otherMouseUp:
            let n = Int(event.getIntegerValueField(.mouseEventButtonNumber))
            return handleUp(button: n, event: event)

        case .leftMouseDragged:  return handleDragged(button: 0, event: event)
        case .rightMouseDragged: return handleDragged(button: 1, event: event)
        case .otherMouseDragged:
            let n = Int(event.getIntegerValueField(.mouseEventButtonNumber))
            return handleDragged(button: n, event: event)

        case .scrollWheel:     return handleScroll(event: event)
        default:               return Unmanaged.passUnretained(event)
        }
    }

    // MARK: - Click debounce (+ orphaned-up suppression)

    private func handleDown(button: Int, kind: FilterEvent.Kind, enabled: Bool, event: CGEvent) -> Unmanaged<CGEvent>? {
        let now = event.timestamp.seconds

        // Drag fix: a down arriving while a release is pending = chatter mid-drag → cancel release, swallow.
        if Settings.shared.dragFixEnabled, let work = pendingRelease[button] {
            work.cancel()
            pendingRelease[button] = nil
            log(.drag)
            return nil
        }

        if enabled, let lastUp = lastUpTime[button],
           (now - lastUp) < Double(Settings.shared.thresholdMs) / 1000.0 {
            suppressNextUp[button] = true   // swallow the matching up too
            log(kind)
            return nil
        }

        // Record press for drag tracking
        buttonDownTime[button]     = now
        buttonDownLocation[button] = event.location
        isDragging[button]         = false
        return Unmanaged.passUnretained(event)
    }

    private func handleUp(button: Int, event: CGEvent) -> Unmanaged<CGEvent>? {
        if suppressNextUp[button] == true {
            suppressNextUp[button] = false
            return nil
        }

        // Drag fix: while actively dragging, delay the release so a momentary
        // glitch-release followed by a re-press is absorbed instead of dropping.
        if Settings.shared.dragFixEnabled, isDragging[button] == true {
            isDragging[button] = false
            scheduleDelayedRelease(button: button, location: event.location)
            return nil
        }

        lastUpTime[button] = event.timestamp.seconds
        buttonDownTime[button] = nil
        return Unmanaged.passUnretained(event)
    }

    private func handleDragged(button: Int, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard Settings.shared.dragFixEnabled,
              let downTime = buttonDownTime[button],
              let origin   = buttonDownLocation[button] else {
            return Unmanaged.passUnretained(event)
        }
        let held = (event.timestamp.seconds - downTime) * 1000
        let dx = event.location.x - origin.x
        let dy = event.location.y - origin.y
        let moved = (dx * dx + dy * dy) > 16   // moved > 4px

        if held >= Double(Settings.shared.dragStartDelayMs) && moved {
            isDragging[button] = true
        }
        return Unmanaged.passUnretained(event)
    }

    private func scheduleDelayedRelease(button: Int, location: CGPoint) {
        pendingRelease[button]?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingRelease[button] = nil
            self.lastUpTime[button] = ProcessInfo.processInfo.systemUptime
            self.buttonDownTime[button] = nil
            self.postSyntheticUp(button: button, location: location)
        }
        pendingRelease[button] = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Double(Settings.shared.dragReleaseDelayMs) / 1000.0,
            execute: work
        )
    }

    private func postSyntheticUp(button: Int, location: CGPoint) {
        let (type, cgButton): (CGEventType, CGMouseButton) = {
            switch button {
            case 1:  return (.rightMouseUp, .right)
            case 0:  return (.leftMouseUp, .left)
            default: return (.otherMouseUp, .center)
            }
        }()
        let loc = CGEvent(source: nil)?.location ?? location
        if let up = CGEvent(mouseEventSource: nil, mouseType: type,
                            mouseCursorPosition: loc, mouseButton: cgButton) {
            up.setIntegerValueField(.eventSourceUserData, value: syntheticTag)
            up.post(tap: .cgSessionEventTap)
        }
    }

    // MARK: - Scroll-wheel jitter fix

    private func handleScroll(event: CGEvent) -> Unmanaged<CGEvent>? {
        guard Settings.shared.scrollFixEnabled else { return Unmanaged.passUnretained(event) }

        let now = event.timestamp.seconds
        let threshold = Double(Settings.shared.scrollThresholdMs) / 1000.0
        let dy = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let dx = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)

        if shouldSuppressScroll(axis: 0, delta: dy, now: now, threshold: threshold) ||
           shouldSuppressScroll(axis: 1, delta: dx, now: now, threshold: threshold) {
            log(.scroll)
            return nil
        }
        return Unmanaged.passUnretained(event)
    }

    private func shouldSuppressScroll(axis: Int, delta: Int64, now: TimeInterval, threshold: TimeInterval) -> Bool {
        guard delta != 0 else { return false }
        let dir = delta > 0 ? 1 : -1
        if let last = lastScrollDir[axis], last != 0, dir != last,
           let t = lastScrollTime[axis], (now - t) < threshold {
            return true   // quick reversal = jitter
        }
        lastScrollDir[axis]  = dir
        lastScrollTime[axis] = now
        return false
    }

    // MARK: - Logging

    private func log(_ kind: FilterEvent.Kind) {
        let ev = FilterEvent(kind: kind, date: Date())
        DispatchQueue.main.async {
            self.recentEvents.insert(ev, at: 0)
            if self.recentEvents.count > 30 { self.recentEvents.removeLast() }
        }
    }
}

private extension UInt64 {
    var seconds: TimeInterval {
        var tb = mach_timebase_info_data_t()
        mach_timebase_info(&tb)
        return Double(self) * Double(tb.numer) / Double(tb.denom) / 1_000_000_000
    }
}
