import Cocoa
import CoreGraphics

struct FilterEvent {
    enum Button: String { case left = "Left", right = "Right", middle = "Middle" }
    let button: Button
    let date: Date
}

final class MouseFilter: ObservableObject {
    static let shared = MouseFilter()

    @Published private(set) var isRunning = false
    @Published var recentEvents: [FilterEvent] = []

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var lastDownTime: [Int: TimeInterval] = [:]

    private init() {}

    func start() {
        guard tap == nil else { return }

        let mask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue)  |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue)

        tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, info -> Unmanaged<CGEvent>? in
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
        lastDownTime = [:]
        DispatchQueue.main.async { self.isRunning = false }
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let s = Settings.shared
        let (buttonIndex, filterButton): (Int, FilterEvent.Button)

        switch type {
        case .leftMouseDown  where s.leftEnabled:   buttonIndex = 0; filterButton = .left
        case .rightMouseDown where s.rightEnabled:  buttonIndex = 1; filterButton = .right
        case .otherMouseDown where s.middleEnabled:
            let n = event.getIntegerValueField(.mouseEventButtonNumber)
            guard n == 2 else { return .passUnretained(event) }
            buttonIndex = 2; filterButton = .middle
        default:
            return .passUnretained(event)
        }

        let now = event.timestamp.seconds
        let threshold = Double(s.thresholdMs) / 1000.0

        if let last = lastDownTime[buttonIndex], (now - last) < threshold {
            let ev = FilterEvent(button: filterButton, date: Date())
            DispatchQueue.main.async {
                self.recentEvents.insert(ev, at: 0)
                if self.recentEvents.count > 20 { self.recentEvents.removeLast() }
            }
            return nil
        }

        lastDownTime[buttonIndex] = now
        return .passUnretained(event)
    }
}

private extension UInt64 {
    var seconds: TimeInterval {
        var tb = mach_timebase_info_data_t()
        mach_timebase_info(&tb)
        return Double(self) * Double(tb.numer) / Double(tb.denom) / 1_000_000_000
    }
}
