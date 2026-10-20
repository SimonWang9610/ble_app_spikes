import BlePocSwift
import SwiftUI

struct NearbyView: View {
    @Binding var path: [String]
    @Environment(AdapterModel.self) private var adapter
    @Environment(NearbyModel.self) private var nearby
    @Environment(SessionStore.self) private var sessions

    var body: some View {
        // `@Bindable` turns an @Observable object into bindings ($nearby.onlyFixtures) for controls.
        @Bindable var nearby = nearby

        List {
            if let banner = bluetoothBanner {
                Label(banner, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }

            if let session = sessions.current {
                Section("Connected") {
                    NavigationLink(value: session.remoteId) {
                        DeviceRow(name: session.name, detail: session.connection.status.text, rssi: nil)
                    }
                }
            }

            Section {
                Toggle("Only HM-BLE fixtures", isOn: $nearby.onlyFixtures)
                ForEach(nearby.results, id: \.remoteId) { result in
                    // A Button, not a NavigationLink: the tap also connects.
                    Button {
                        sessions.open(remoteId: result.remoteId, name: result.advertisementData.advName)
                        path = [result.remoteId]
                    } label: {
                        DeviceRow(name: result.advertisementData.advName, detail: result.remoteId, rssi: result.rssi,
                                  chevron: true)
                    }
                }
                if let error = nearby.error {
                    Text(error).font(.caption).foregroundStyle(.red)
                } else if nearby.results.isEmpty, nearby.isScanning {
                    Text("Looking for devices…").foregroundStyle(.secondary)
                }
            } header: {
                HStack {
                    Text("Nearby")
                    Spacer()
                    if nearby.isScanning { ProgressView().controlSize(.small) }
                }
            }
        }
        .navigationTitle("Nearby")
        // Scans while this screen is visible; SwiftUI cancels the task when the Device screen covers it
        // or the filter changes (the id changes), which stops the scan.
        .task(id: ScanKey(ready: adapter.isInitialized, onlyFixtures: nearby.onlyFixtures)) {
            guard adapter.isInitialized else { return }
            await nearby.scan()
        }
    }

    private var bluetoothBanner: String? {
        if let error = adapter.error { return "Bluetooth unavailable: \(error)" }
        guard let state = adapter.state, state != .poweredOn else { return nil }
        return "Bluetooth is \(state == .poweredOff ? "off" : "not ready")"
    }
}

private struct ScanKey: Equatable {
    let ready: Bool
    let onlyFixtures: Bool
}

private struct DeviceRow: View {
    let name: String
    let detail: String
    let rssi: Int32?
    /// Drawn by hand for Button rows; a NavigationLink brings its own.
    var chevron = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name.isEmpty ? "(no name)" : name).foregroundStyle(.primary)
                Text(detail).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if let rssi {
                Text("\(rssi) dBm").font(.callout).foregroundStyle(.secondary)
            }
            if chevron {
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
    }
}

#if DEBUG
#Preview {
    let models = PreviewModels()
    NavigationStack { NearbyView(path: .constant([])) }
        .environment(models)
        .task { await models.adapter.observe() }
}
#endif
