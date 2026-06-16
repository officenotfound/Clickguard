import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = Settings.shared
    @ObservedObject private var filter   = MouseFilter.shared

    @State private var thresholdInput = ""
    @State private var pulsing = false

    var body: some View {
        VStack(spacing: 0) {
            statusHeader
            Divider().opacity(0.25)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    sectionGroup("CLICK DEBOUNCE") {
                        thresholdCard
                        buttonsCard
                    }
                    sectionGroup("SCROLL WHEEL") {
                        scrollCard
                    }
                    sectionGroup("DRAG & DROP") {
                        dragCard
                    }
                    sectionGroup("GENERAL") {
                        generalCard
                    }
                    sectionGroup("ACTIVITY") {
                        activityCard
                    }
                }
                .padding(14)
                .padding(.bottom, 4)
            }
            Divider().opacity(0.25)
            footer
        }
        .frame(width: 300)
        .background(.ultraThinMaterial)
        .onAppear { thresholdInput = "\(settings.thresholdMs)" }
    }

    // MARK: - Section group

    private func sectionGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(title)
            content()
        }
    }

    // MARK: - Status header

    private var statusHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(filter.isRunning ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                    .frame(width: 30, height: 30)
                    .scaleEffect(pulsing ? 1.12 : 1.0)
                    .animation(
                        filter.isRunning
                            ? .easeInOut(duration: 1.8).repeatForever(autoreverses: true)
                            : .default,
                        value: pulsing)
                Image(systemName: "cursorarrow.click.2")
                    .font(.system(size: 14, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(filter.isRunning ? Color.green : Color.red)
            }
            .onAppear { pulsing = filter.isRunning }
            .onChange(of: filter.isRunning) { pulsing = $0 }

            VStack(alignment: .leading, spacing: 1) {
                Text("ClickGuard")
                    .font(.system(size: 13, weight: .semibold))
                Text(filter.isRunning ? "Active" : "Accessibility required")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Threshold

    private var thresholdCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
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
                            .foregroundStyle(.tertiary)
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
            .padding(12)
        }
    }

    // MARK: - Buttons

    private var buttonsCard: some View {
        GlassCard {
            VStack(spacing: 0) {
                GlassRow(first: true) {
                    ToggleRow(label: "Left button",   icon: "cursorarrow", isOn: $settings.leftEnabled)
                }
                GlassDivider()
                GlassRow {
                    ToggleRow(label: "Right button",  icon: "cursorarrow", isOn: $settings.rightEnabled)
                }
                GlassDivider()
                GlassRow(last: true) {
                    ToggleRow(label: "Middle button", icon: "scroll",      isOn: $settings.middleEnabled)
                }
            }
        }
    }

    // MARK: - Scroll wheel fix

    private var scrollCard: some View {
        GlassCard {
            VStack(spacing: 0) {
                GlassRow(first: true, last: !settings.scrollFixEnabled) {
                    ToggleRow(label: "Filter scroll jitter", icon: "scroll", isOn: $settings.scrollFixEnabled)
                }
                if settings.scrollFixEnabled {
                    GlassDivider()
                    GlassRow(last: true) {
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
        GlassCard {
            VStack(spacing: 0) {
                GlassRow(first: true, last: !settings.dragFixEnabled) {
                    VStack(alignment: .leading, spacing: 3) {
                        ToggleRow(label: "Prevent drops while dragging", icon: "hand.draw", isOn: $settings.dragFixEnabled)
                        Text("Experimental — enable only if your mouse drops items mid-drag.")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 22)
                    }
                }
                if settings.dragFixEnabled {
                    GlassDivider()
                    GlassRow {
                        StepperRow(label: "Drag start delay",
                                   value: $settings.dragStartDelayMs,
                                   range: 100...3000, step: 100, unit: "ms")
                    }
                    GlassDivider()
                    GlassRow(last: true) {
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
        GlassCard {
            GlassRow(first: true, last: true) {
                ToggleRow(label: "Launch at login", icon: "power", isOn: $settings.launchAtLogin)
            }
        }
    }

    // MARK: - Activity

    private var activityCard: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    VStack(spacing: 3) {
                        Text("\(filter.sessionCount)")
                            .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                            .contentTransition(.numericText())
                            .animation(.snappy, value: filter.sessionCount)
                        Text("this session")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    Divider().frame(height: 28).opacity(0.4)
                    VStack(spacing: 3) {
                        Text("\(filter.allTimeCount)")
                            .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                            .contentTransition(.numericText())
                            .animation(.snappy, value: filter.allTimeCount)
                        Text("all time")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 4)

                Button {
                    NotificationCenter.default.post(name: .openClickGuardStats, object: nil)
                } label: {
                    HStack {
                        Image(systemName: "list.bullet.rectangle")
                            .symbolRenderingMode(.hierarchical)
                        Text("See all blocked clicks")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .font(.system(size: 12))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            }
            .padding(12)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()
            Button("Quit ClickGuard") {
                NSApplication.shared.terminate(nil)
            }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.5)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 2)
    }

    private func applyThresholdInput() {
        if let v = Int(thresholdInput), (1...500).contains(v) {
            settings.thresholdMs = v
        } else {
            thresholdInput = "\(settings.thresholdMs)"
        }
    }
}

// MARK: - Glass design system

private struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.22), Color.primary.opacity(0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.75
                    )
            )
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }
}

private struct GlassRow<Content: View>: View {
    var first = false
    var last  = false
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
    }
}

private struct GlassDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 12)
            .opacity(0.3)
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
                .symbolRenderingMode(.hierarchical)
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
