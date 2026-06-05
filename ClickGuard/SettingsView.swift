import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = Settings.shared
    @ObservedObject private var filter   = MouseFilter.shared

    @State private var thresholdInput: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    filterSection
                    Divider()
                    generalSection
                    Divider()
                    activitySection
                }
                .padding(20)
            }
        }
        .frame(width: 340)
        .onAppear { thresholdInput = "\(settings.thresholdMs)" }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "cursorarrow.click.2")
                .font(.system(size: 28))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("ClickGuard")
                    .font(.headline)
                HStack(spacing: 5) {
                    Circle()
                        .fill(filter.isRunning ? Color.green : Color.red)
                        .frame(width: 7, height: 7)
                    Text(filter.isRunning ? "Active" : "Needs Accessibility access")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(16)
        .background(.background)
    }

    // MARK: - Filter settings

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("FILTER SETTINGS", systemImage: "slider.horizontal.3")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Threshold")
                    .font(.subheadline)
                HStack(spacing: 10) {
                    Slider(
                        value: Binding(
                            get: { Double(settings.thresholdMs) },
                            set: { settings.thresholdMs = Int($0); thresholdInput = "\(Int($0))" }
                        ),
                        in: 1...300,
                        step: 1
                    )
                    TextField("", text: $thresholdInput)
                        .frame(width: 44)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { applyThresholdInput() }
                    Text("ms")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                }
                Text("Clicks arriving faster than this on the same button are suppressed.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Buttons to filter")
                    .font(.subheadline)
                Toggle("Left button",   isOn: $settings.leftEnabled)
                Toggle("Right button",  isOn: $settings.rightEnabled)
                Toggle("Middle button", isOn: $settings.middleEnabled)
            }
        }
    }

    // MARK: - General

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("GENERAL", systemImage: "gearshape")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Toggle("Launch at login", isOn: $settings.launchAtLogin)
        }
    }

    // MARK: - Activity log

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("RECENT FILTERED CLICKS", systemImage: "list.bullet.clipboard")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !filter.recentEvents.isEmpty {
                    Button("Clear") { MouseFilter.shared.recentEvents.removeAll() }
                        .font(.caption)
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                }
            }

            if filter.recentEvents.isEmpty {
                Text("No clicks filtered yet.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(filter.recentEvents.prefix(8).indices, id: \.self) { i in
                        let ev = filter.recentEvents[i]
                        HStack {
                            Image(systemName: buttonIcon(ev.button))
                                .foregroundStyle(.secondary)
                                .frame(width: 18)
                            Text("\(ev.button.rawValue) click suppressed")
                                .font(.caption)
                            Spacer()
                            Text(ev.date, style: .time)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 8)
                        .background(i % 2 == 0 ? Color.clear : Color.primary.opacity(0.04))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.08)))
            }
        }
    }

    // MARK: - Helpers

    private func applyThresholdInput() {
        if let v = Int(thresholdInput), (1...500).contains(v) {
            settings.thresholdMs = v
        } else {
            thresholdInput = "\(settings.thresholdMs)"
        }
    }

    private func buttonIcon(_ b: FilterEvent.Button) -> String {
        switch b {
        case .left:   return "mouse.fill"
        case .right:  return "mouse.fill"
        case .middle: return "scroll"
        }
    }
}
