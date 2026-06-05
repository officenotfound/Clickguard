import Foundation
import Combine
import ServiceManagement

final class Settings: ObservableObject {
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    @Published var thresholdMs: Int {
        didSet { defaults.set(thresholdMs, forKey: "thresholdMs") }
    }
    @Published var leftEnabled: Bool {
        didSet { defaults.set(leftEnabled, forKey: "leftEnabled") }
    }
    @Published var rightEnabled: Bool {
        didSet { defaults.set(rightEnabled, forKey: "rightEnabled") }
    }
    @Published var middleEnabled: Bool {
        didSet { defaults.set(middleEnabled, forKey: "middleEnabled") }
    }

    // MARK: Scroll-wheel jitter fix
    @Published var scrollFixEnabled: Bool {
        didSet { defaults.set(scrollFixEnabled, forKey: "scrollFixEnabled") }
    }
    @Published var scrollThresholdMs: Int {
        didSet { defaults.set(scrollThresholdMs, forKey: "scrollThresholdMs") }
    }

    // MARK: Drag & drop fix (experimental)
    @Published var dragFixEnabled: Bool {
        didSet { defaults.set(dragFixEnabled, forKey: "dragFixEnabled") }
    }
    @Published var dragStartDelayMs: Int {
        didSet { defaults.set(dragStartDelayMs, forKey: "dragStartDelayMs") }
    }
    @Published var dragReleaseDelayMs: Int {
        didSet { defaults.set(dragReleaseDelayMs, forKey: "dragReleaseDelayMs") }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            do {
                if launchAtLogin { try SMAppService.mainApp.register() }
                else             { try SMAppService.mainApp.unregister() }
            } catch {
                print("Launch at login error: \(error)")
            }
        }
    }

    private init() {
        let ms = defaults.integer(forKey: "thresholdMs")
        thresholdMs    = ms == 0 ? 50 : ms
        leftEnabled    = defaults.object(forKey: "leftEnabled")   as? Bool ?? true
        rightEnabled   = defaults.object(forKey: "rightEnabled")  as? Bool ?? true
        middleEnabled  = defaults.object(forKey: "middleEnabled") as? Bool ?? false

        scrollFixEnabled   = defaults.object(forKey: "scrollFixEnabled") as? Bool ?? false
        let sms = defaults.integer(forKey: "scrollThresholdMs")
        scrollThresholdMs  = sms == 0 ? 50 : sms

        dragFixEnabled     = defaults.object(forKey: "dragFixEnabled") as? Bool ?? false
        let dsd = defaults.integer(forKey: "dragStartDelayMs")
        dragStartDelayMs   = dsd == 0 ? 1000 : dsd
        let drd = defaults.integer(forKey: "dragReleaseDelayMs")
        dragReleaseDelayMs = drd == 0 ? 150 : drd

        launchAtLogin  = SMAppService.mainApp.status == .enabled
    }
}
