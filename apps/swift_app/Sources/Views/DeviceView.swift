import BlePocSwift
import SwiftUI

struct DeviceView: View {
    // The session outlives this screen, so the screen only reads it; it doesn't own it.
    @Bindable var session: DeviceSession
    @Environment(SessionStore.self) private var sessions
    @Environment(\.dismiss) private var dismiss
    // Which characteristic's dialog is open: pure view state.
    @State private var selected: CharacteristicState?

    var body: some View {
        List {
            Section {
                HStack {
                    Circle().fill(statusColor).frame(width: 10, height: 10)
                    Text(session.status.text)
                    Spacer()
                    statusButton
                }
                Toggle("Auto-reconnect", isOn: $session.autoReconnect)
                HStack {
                    Text("RSSI \(session.rssi.map { "\($0) dBm" } ?? "–") · MTU \(session.mtu.map(String.init) ?? "–")")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Refresh RSSI") { Task { await session.refreshRssi() } }
                        .disabled(!session.isConnected)
                }
                .font(.callout)
            }

            ForEach(session.services) { group in
                Section(Fixture.label(group.uuid)) {
                    ForEach(group.characteristics) { state in
                        Button { selected = state } label: { CharacteristicRow(state: state) }
                    }
                }
            }
        }
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected) { state in
            CharacteristicSheet(state: state, session: session)
                .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder private var statusButton: some View {
        switch session.status {
        case .connected, .reconnecting:
            Button("Disconnect", role: .destructive) {
                dismiss()
                Task { await sessions.disconnect() }
            }
        case .disconnected:
            Button("Connect") { Task { await session.connect() } }
        case .connecting, .disconnecting:
            ProgressView()
        }
    }

    private var statusColor: Color {
        switch session.status {
        case .connected: .green
        case .connecting, .reconnecting, .disconnecting: .orange
        case .disconnected: .red
        }
    }
}

/// One characteristic: name, properties, latest value, live badge. Redraws on its own when it ticks.
private struct CharacteristicRow: View {
    let state: CharacteristicState

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(state.name).font(.body.weight(.semibold)).foregroundStyle(.primary)
                Text(state.properties.summary).font(.caption).foregroundStyle(.secondary)
                Text(valueLine).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if state.subscribed {
                Label("\(state.receivedCount)", systemImage: "dot.radiowaves.left.and.right")
                    .font(.caption).foregroundStyle(.green)
            }
            if state.error != nil {
                Image(systemName: "exclamationmark.circle").foregroundStyle(.red)
            }
        }
    }

    private var valueLine: String {
        guard let value = state.latest, let time = state.latestTime, let source = state.latestSource else { return "–" }
        return "\(state.show(value)) · \(source.rawValue) \(time.formatted(date: .omitted, time: .standard))"
    }
}

extension CharacteristicProperties {
    var summary: String {
        [
            read ? "read" : nil,
            write ? "write" : nil,
            writeWithoutResponse ? "write without response" : nil,
            notify ? "notify" : nil,
            indicate ? "indicate" : nil,
        ].compactMap(\.self).joined(separator: " · ")
    }
}
