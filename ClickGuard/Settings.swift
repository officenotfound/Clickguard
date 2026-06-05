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
        launchAtLogin  = SMAppService.mainApp.status == .enabled
    }
}
