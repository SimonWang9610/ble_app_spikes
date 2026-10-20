import SwiftUI

struct DeviceView: View {
    // The session outlives this screen, so the screen only reads it; it doesn't own it.
    let session: DeviceSession
    @Environment(SessionStore.self) private var sessions
    @Environment(\.dismiss) private var dismiss
    // Which operation's dialog is open: pure view state.
    @State private var selected: OperationRow?

    var body: some View {
        @Bindable var connection = session.connection

        List {
            Section {
                HStack {
                    Circle().fill(connection.status.tint).frame(width: 10, height: 10)
                        .accessibilityHidden(true)
                    Text(connection.status.text)
                    Spacer()
                    statusButton
                }
                .buttonStyle(.borderless)
                Toggle("Auto-reconnect", isOn: $connection.autoReconnect)
                HStack {
                    Text("RSSI \(connection.rssi.map { "\($0) dBm" } ?? "–") · MTU \(connection.mtu.map(String.init) ?? "–")")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Refresh RSSI") { Task { await connection.refreshRssi() } }
                        .disabled(!connection.isConnected)
                }
                .font(.callout)
                .buttonStyle(.borderless)
            }

            ForEach(session.gatt.services) { group in
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
            CharacteristicSheet(characteristic: row.characteristic, operation: row.operation, session: session)
                .presentationDetents([.large])
        }
    }

    @ViewBuilder private var statusButton: some View {
        switch session.connection.status {
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
}

private extension ConnectionStatus {
    var tint: Color {
        switch self {
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

    private var characteristic: Characteristic { row.characteristic }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if let name = Fixture.knownName(characteristic.ref.characteristic) {
                        Text(name).font(.body.weight(.semibold)).foregroundStyle(.primary)
                    }
                    OperationChip(operation: row.operation)
                }
                Text(characteristic.ref.characteristic).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            Spacer()
            if row.operation.isSubscription {
                if characteristic.subscribed {
                    Label("\(characteristic.receivedCount)", systemImage: "dot.radiowaves.left.and.right")
                        .font(.caption).foregroundStyle(.green)
                        .accessibilityLabel("Subscribed, \(characteristic.receivedCount) received")
                } else {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash").foregroundStyle(.secondary)
                        .accessibilityLabel("Not subscribed")
                }
            }
            if characteristic.error != nil {
                Image(systemName: "exclamationmark.circle").foregroundStyle(.red)
                    .accessibilityLabel("Error")
            }
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
    }
}

#if DEBUG
#Preview {
    let models = PreviewModels()
    NavigationStack { DeviceView(session: models.session()) }
        .environment(models)
}
#endif
