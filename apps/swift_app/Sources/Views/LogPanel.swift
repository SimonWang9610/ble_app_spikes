import SwiftUI

/// Always-visible device log under every screen; collapsed to the latest line.
struct LogPanel: View {
    @Environment(DeviceLog.self) private var log
    // Pure view state, nobody else needs it, so it stays in the view.
    @State private var expanded = false

    var body: some View {
        @Bindable var log = log
        let entries = log.visible

        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 8) {
                Text("Log").font(.caption.bold())
                if expanded {
                    Toggle("API calls", isOn: $log.showApiCalls).toggleStyle(.button).font(.caption)
                    Spacer()
                    Button("Clear") { log.clear() }.font(.caption)
                } else if let last = entries.last {
                    LogLine(entry: last).lineLimit(1)
                    Spacer(minLength: 0)
                } else {
                    Spacer()
                }
                Image(systemName: expanded ? "chevron.down" : "chevron.up").font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture { expanded.toggle() }

            if expanded {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(entries) { LogLine(entry: $0).id($0.id) }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 6)
                    }
                    .onAppear { proxy.scrollTo(entries.last?.id, anchor: .bottom) }
                    .onChange(of: entries.last?.id) { _, last in
                        if let last { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
                .frame(height: 200)
            }
        }
        .background(.bar)
    }
}

private struct LogLine: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(entry.time, format: .dateTime.hour().minute().second()).foregroundStyle(.secondary)
            Text(entry.text).foregroundStyle(color).textSelection(.enabled)
        }
        .font(.caption2.monospaced())
    }

    private var color: Color {
        switch entry.kind {
        case .event: .primary
        case .value: .blue
        case .error: .red
        case .api: .secondary
        }
    }
}
