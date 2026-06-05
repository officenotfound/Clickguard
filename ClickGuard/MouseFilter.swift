import Cocoa
import CoreGraphics
import ClickGuardCore

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

    private let engine = DebounceEngine()
    private var pendingTimers: [Int: DispatchWorkItem] = [:]

    // Marks synthetic events we post ourselves so we never re-process them.
    private let syntheticTag: Int64 = 0x4347_4658   // "CGFX"

    private init() {
        engine.onLog = { [weak self] kind in
            self?.log(kind)
        }
    }

    // MARK: - Lifecycle

    func start() {
        guard tap == nil else { return }

        let mask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue)     |
            (1 << CGEventType.leftMouseUp.rawValue)       |
            (1 << CGEventType.rightMouseDown.rawValue)    |
            (1 << CGEventType.rightMouseUp.rawValue)      |
            (1 << CGEventType.otherMouseDown.rawValue)    |
            (1 << CGEventType.otherMouseUp.rawValue)      |
            (1 << CGEventType.leftMouseDragged.rawValue)  |
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
        pendingTimers.values.forEach { $0.cancel() }
        pendingTimers = [:]
        engine.reset()
        DispatchQueue.main.async { self.isRunning = false }
    }

    // MARK: - Event handling

    private func currentConfig() -> DebounceEngine.Config {
        let s = Settings.shared
        var c = DebounceEngine.Config()
        c.leftEnabled        = s.leftEnabled
        c.rightEnabled       = s.rightEnabled
        c.middleEnabled      = s.middleEnabled
        c.clickThresholdMs   = s.thresholdMs
        c.scrollEnabled      = s.scrollFixEnabled
        c.scrollThresholdMs  = s.scrollThresholdMs
        c.dragEnabled        = s.dragFixEnabled
        c.dragStartDelayMs   = s.dragStartDelayMs
        c.dragReleaseDelayMs = s.dragReleaseDelayMs
        return c
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == syntheticTag {
            return Unmanaged.passUnretained(event)
        }

        engine.config = currentConfig()
        let now = event.timestamp.seconds
        let loc = event.location

        switch type {
        case .leftMouseDown:   return apply(engine.onDown(button: 0, now: now, location: loc), event)
        case .rightMouseDown:  return apply(engine.onDown(button: 1, now: now, location: loc), event)
        case .otherMouseDown:
            let n = Int(event.getIntegerValueField(.mouseEventButtonNumber))
            return apply(engine.onDown(button: n, now: now, location: loc), event)

        case .leftMouseUp:     return apply(engine.onUp(button: 0, now: now, location: loc), event)
        case .rightMouseUp:    return apply(engine.onUp(button: 1, now: now, location: loc), event)
        case .otherMouseUp:
            let n = Int(event.getIntegerValueField(.mouseEventButtonNumber))
            return apply(engine.onUp(button: n, now: now, location: loc), event)

        case .leftMouseDragged:  engine.onDragged(button: 0, now: now, location: loc); return Unmanaged.passUnretained(event)
        case .rightMouseDragged: engine.onDragged(button: 1, now: now, location: loc); return Unmanaged.passUnretained(event)
        case .otherMouseDragged:
            let n = Int(event.getIntegerValueField(.mouseEventButtonNumber))
            engine.onDragged(button: n, now: now, location: loc); return Unmanaged.passUnretained(event)

        case .scrollWheel:
            let dy = Int(event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
            let dx = Int(event.getIntegerValueField(.scrollWheelEventDeltaAxis2))
            return apply(engine.onScroll(deltaVertical: dy, deltaHorizontal: dx, now: now), event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func apply(_ action: DebounceEngine.Action, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        switch action {
        case .pass:
            return Unmanaged.passUnretained(event)
        case .suppress:
            return nil
        case .suppressAndCancelRelease(let button):
            pendingTimers[button]?.cancel()
            pendingTimers[button] = nil
            return nil
        case .suppressAndScheduleRelease(let button):
            scheduleRelease(button: button, location: event.location)
            return nil
        }
    }

    private func scheduleRelease(button: Int, location: CGPoint) {
        pendingTimers[button]?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingTimers[button] = nil
            self.engine.releaseTimerFired(button: button, now: ProcessInfo.processInfo.systemUptime)
            self.postSyntheticUp(button: button, fallback: location)
        }
        pendingTimers[button] = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Double(Settings.shared.dragReleaseDelayMs) / 1000.0,
            execute: work
        )
    }

    private func postSyntheticUp(button: Int, fallback: CGPoint) {
        let (type, cgButton): (CGEventType, CGMouseButton) = {
            switch button {
            case 1:  return (.rightMouseUp, .right)
            case 0:  return (.leftMouseUp, .left)
            default: return (.otherMouseUp, .center)
            }
        }()
        let loc = CGEvent(source: nil)?.location ?? fallback
        if let up = CGEvent(mouseEventSource: nil, mouseType: type,
                            mouseCursorPosition: loc, mouseButton: cgButton) {
            up.setIntegerValueField(.eventSourceUserData, value: syntheticTag)
            up.post(tap: .cgSessionEventTap)
        }
    }

    // MARK: - Logging

    private func log(_ kind: DebounceEngine.LogKind) {
        let fk: FilterEvent.Kind
        switch kind {
        case .click(let b): fk = (b == 0 ? .left : b == 1 ? .right : .middle)
        case .scroll:       fk = .scroll
        case .drag:         fk = .drag
        }
        let ev = FilterEvent(kind: fk, date: Date())
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
