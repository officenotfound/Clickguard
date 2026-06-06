import SwiftUI

struct StatsView: View {
    @ObservedObject private var filter   = MouseFilter.shared
    @ObservedObject private var settings = Settings.shared

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"; return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            counters
            Divider().opacity(0.5)
            listHeader
            list
        }
        .frame(minWidth: 460, minHeight: 540)
        .background(.ultraThinMaterial)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 20))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text("Blocked Clicks")
                    .font(.system(size: 15, weight: .semibold))
                Text(filter.isRunning ? "Filtering is active" : "Not active — grant Accessibility access")
                    .font(.system(size: 11))
                    .foregroundStyle(filter.isRunning ? .secondary : Color.red)
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    // MARK: Counters

    private var counters: some View {
        HStack(spacing: 12) {
            statTile(value: filter.sessionCount, label: "This session", icon: "bolt.fill")
            statTile(value: filter.allTimeCount, label: "All time", icon: "infinity")
        }
        .padding(16)
    }

    private func statTile(value: Int, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11)).foregroundStyle(.secondary)
                Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Text("\(value)")
                .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                .contentTransition(.numericText())
                .animation(.snappy, value: value)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.07), lineWidth: 0.5))
    }

    // MARK: List

    private var listHeader: some View {
        HStack {
            Text("EVENT LOG")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text("threshold \(settings.thresholdMs) ms")
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(.tertiary)
            if !filter.recentEvents.isEmpty {
                Button("Clear") { withAnimation { filter.clearHistory() } }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var list: some View {
        if filter.recentEvents.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "cursorarrow.click.2")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
                Text("No bounces caught yet")
                    .font(.system(size: 13, weight: .medium))
                Text("Rapidly double-click your mouse to test.\nAny click landing under \(settings.thresholdMs) ms after the\nprevious one will be blocked and listed here.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(30)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(filter.recentEvents.enumerated()), id: \.element.id) { idx, ev in
                        row(ev, alt: idx % 2 == 1)
                        Divider().opacity(0.25)
                    }
                }
            }
        }
    }

    private func row(_ ev: FilterEvent, alt: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon(ev.kind))
                .font(.system(size: 12))
                .foregroundStyle(Color.accentColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(ev.kind.rawValue + " blocked")
                    .font(.system(size: 12, weight: .medium))
                Text(Self.timeFmt.string(from: ev.date))
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if let gap = ev.gapMs {
                Text("\(String(format: "%.0f", gap)) ms")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.orange.opacity(0.12), in: Capsule())
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(alt ? Color.primary.opacity(0.03) : .clear)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func icon(_ kind: FilterEvent.Kind) -> String {
        switch kind {
        case .left, .right, .middle: return "cursorarrow.click"
        case .scroll:                return "scroll"
        case .drag:                  return "hand.draw"
        }
    }
}
