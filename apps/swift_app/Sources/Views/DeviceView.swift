import SwiftUI

struct DeviceView: View {
    // The session outlives this screen, so the screen only reads it; it doesn't own it.
    @Bindable var session: DeviceSession
    @Environment(SessionStore.self) private var sessions
    @Environment(\.dismiss) private var dismiss
    // Which operation's dialog is open: pure view state.
    @State private var selected: OperationRow?

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
                Section {
                    ForEach(group.rows) { row in
                        Button { selected = row } label: { CharacteristicRow(row: row) }
                    }
                } header: {
                    ServiceHeader(uuid: group.uuid)
                }
            }
        }
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected) { row in
            CharacteristicSheet(state: row.state, operation: row.operation, session: session)
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

private struct ServiceHeader: View {
    let uuid: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let name = Fixture.knownName(uuid) {
                Text(name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
            }
            Text(uuid).font(.caption.monospaced()).foregroundStyle(.secondary)
        }
        .textCase(nil)
    }
}

/// One operation of a characteristic: name, chip, UUID, subscribed icon. Redraws on its own when it ticks.
private struct CharacteristicRow: View {
    let row: OperationRow

    private var state: CharacteristicState { row.state }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if let name = Fixture.knownName(state.ref.characteristic) {
                        Text(name).font(.body.weight(.semibold)).foregroundStyle(.primary)
                    }
                    OperationChip(operation: row.operation)
                }
                Text(state.ref.characteristic).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            Spacer()
            if row.operation.isSubscription {
                if state.subscribed {
                    Label("\(state.receivedCount)", systemImage: "dot.radiowaves.left.and.right")
                        .font(.caption).foregroundStyle(.green)
                } else {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash").foregroundStyle(.secondary)
                }
            }
            if state.error != nil {
                Image(systemName: "exclamationmark.circle").foregroundStyle(.red)
            }
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
    }
}
