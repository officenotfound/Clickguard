import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = Settings.shared
    @ObservedObject private var filter   = MouseFilter.shared

    @State private var thresholdInput = ""
    @State private var pulsing = false

    var body: some View {
        VStack(spacing: 0) {
            statusHeader
            Divider().opacity(0.5)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    thresholdCard
                    buttonsCard
                    generalCard
                    activityCard
                }
                .padding(14)
            }
            Divider().opacity(0.5)
            footer
        }
        .frame(width: 300)
        .background(.ultraThinMaterial)
        .onAppear { thresholdInput = "\(settings.thresholdMs)" }
    }

    // MARK: - Status header

    private var statusHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(filter.isRunning ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .scaleEffect(pulsing ? 1.15 : 1.0)
                    .animation(filter.isRunning
                        ? .easeInOut(duration: 1.6).repeatForever(autoreverses: true)
                        : .default,
                        value: pulsing)
                Image(systemName: "cursorarrow.click.2")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(filter.isRunning ? Color.green : Color.red)
            }
            .onAppear { pulsing = filter.isRunning }
            .onChange(of: filter.isRunning) { pulsing = $0 }

            VStack(alignment: .leading, spacing: 1) {
                Text("ClickGuard")
                    .font(.system(size: 13, weight: .semibold))
                Text(filter.isRunning ? "Active" : "Accessibility access required")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // MARK: - Threshold

    private var thresholdCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Threshold")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    HStack(spacing: 3) {
                        TextField("", text: $thresholdInput)
                            .frame(width: 36)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 12, weight: .medium).monospacedDigit())
                            .textFieldStyle(.plain)
                            .onSubmit { applyThresholdInput() }
                        Text("ms")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                Slider(
                    value: Binding(
                        get: { Double(settings.thresholdMs) },
                        set: {
                            settings.thresholdMs = Int($0)
                            thresholdInput = "\(Int($0))"
                        }
                    ),
                    in: 1...300, step: 1
                )
                .tint(.accentColor)
                Text("Clicks faster than this on the same button are suppressed.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Buttons

    private var buttonsCard: some View {
        CardView {
            VStack(spacing: 0) {
                CardRow(first: true) {
                    ToggleRow(label: "Left button",   icon: "cursorarrow", isOn: $settings.leftEnabled)
                }
                Divider().padding(.leading, 32).opacity(0.4)
                CardRow {
                    ToggleRow(label: "Right button",  icon: "cursorarrow", isOn: $settings.rightEnabled)
                }
                Divider().padding(.leading, 32).opacity(0.4)
                CardRow(last: true) {
                    ToggleRow(label: "Middle button", icon: "scroll",      isOn: $settings.middleEnabled)
                }
            }
        }
    }

    // MARK: - General

    private var generalCard: some View {
        CardView {
            CardRow(first: true, last: true) {
                ToggleRow(label: "Launch at login", icon: "power", isOn: $settings.launchAtLogin)
            }
        }
    }

    // MARK: - Activity

    private var activityCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Recent filtered clicks")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !filter.recentEvents.isEmpty {
                        Button("Clear") {
                            withAnimation { filter.recentEvents.removeAll() }
                        }
                        .font(.system(size: 11))
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                    }
                }

                if filter.recentEvents.isEmpty {
                    Text("No clicks filtered yet")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 3) {
                        ForEach(filter.recentEvents.prefix(6), id: \.date) { ev in
                            HStack(spacing: 6) {
                                Image(systemName: "hand.tap.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 14)
                                Text("\(ev.button.rawValue)")
                                    .font(.system(size: 11))
                                Spacer()
                                Text(ev.date, style: .relative)
                                    .font(.system(size: 10).monospacedDigit())
                                    .foregroundStyle(.tertiary)
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .animation(.spring(duration: 0.3), value: filter.recentEvents.count)
                }
            }
            .padding(10)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()
            Button("Quit ClickGuard") {
                NSApplication.shared.terminate(nil)
            }
            .font(.system(size: 12))
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
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
}

// MARK: - Reusable components

private struct CardView<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.07), lineWidth: 0.5)
            )
    }
}

private struct CardRow<Content: View>: View {
    var first = false
    var last  = false
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
    }
}

private struct ToggleRow: View {
    let label: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Label(label, systemImage: icon)
                .font(.system(size: 12))
                .labelStyle(.titleAndIcon)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }
}
