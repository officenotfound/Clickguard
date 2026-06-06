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
                    sectionLabel("DOUBLE-CLICK FIX")
                    thresholdCard
                    buttonsCard

                    sectionLabel("SCROLL WHEEL FIX")
                    scrollCard

                    sectionLabel("DRAG & DROP FIX")
                    dragCard

                    sectionLabel("GENERAL")
                    generalCard

                    sectionLabel("ACTIVITY")
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

    // MARK: - Scroll wheel fix

    private var scrollCard: some View {
        CardView {
            VStack(spacing: 0) {
                CardRow(first: settings.scrollFixEnabled ? false : true, last: !settings.scrollFixEnabled) {
                    ToggleRow(label: "Filter scroll jitter", icon: "scroll", isOn: $settings.scrollFixEnabled)
                }
                if settings.scrollFixEnabled {
                    Divider().padding(.leading, 32).opacity(0.4)
                    CardRow(last: true) {
                        StepperRow(label: "Reversal threshold",
                                   value: $settings.scrollThresholdMs,
                                   range: 1...300, step: 5, unit: "ms")
                    }
                }
            }
        }
    }

    // MARK: - Drag & drop fix

    private var dragCard: some View {
        CardView {
            VStack(spacing: 0) {
                CardRow(first: true, last: !settings.dragFixEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        ToggleRow(label: "Prevent drops while dragging", icon: "hand.draw", isOn: $settings.dragFixEnabled)
                        Text("Experimental — enable only if your mouse drops items mid-drag.")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 22)
                    }
                }
                if settings.dragFixEnabled {
                    Divider().padding(.leading, 32).opacity(0.4)
                    CardRow {
                        StepperRow(label: "Drag start delay",
                                   value: $settings.dragStartDelayMs,
                                   range: 100...3000, step: 100, unit: "ms")
                    }
                    Divider().padding(.leading, 32).opacity(0.4)
                    CardRow(last: true) {
                        StepperRow(label: "Release delay",
                                   value: $settings.dragReleaseDelayMs,
                                   range: 50...500, step: 25, unit: "ms")
                    }
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
            VStack(spacing: 10) {
                HStack(spacing: 0) {
                    VStack(spacing: 2) {
                        Text("\(filter.sessionCount)")
                            .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                            .contentTransition(.numericText())
                            .animation(.snappy, value: filter.sessionCount)
                        Text("this session").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    Divider().frame(height: 32)
                    VStack(spacing: 2) {
                        Text("\(filter.allTimeCount)")
                            .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                            .contentTransition(.numericText())
                            .animation(.snappy, value: filter.allTimeCount)
                        Text("all time").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                Button {
                    NotificationCenter.default.post(name: .openClickGuardStats, object: nil)
                } label: {
                    HStack {
                        Image(systemName: "list.bullet.rectangle")
                        Text("See all blocked clicks")
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(.tertiary)
                    }
                    .font(.system(size: 12))
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
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

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
            .padding(.top, 2)
    }

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

private struct StepperRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let unit: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
            Spacer()
            Text("\(value) \(unit)")
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 52, alignment: .trailing)
            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()
                .controlSize(.small)
        }
    }
}
