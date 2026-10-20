import BlePocSwift
import Observation

/// Initializes the manager once and mirrors the adapter state. Lives as long as the app.
@MainActor
@Observable
final class AdapterModel {
    private(set) var state: BluetoothAdapterState?
    private(set) var isInitialized = false
    private(set) var error: String?

    private let adapter: any BleAdapter

    init(adapter: any BleAdapter) {
        self.adapter = adapter
    }

    /// Runs for the app's lifetime, from the root view's `.task`.
    func observe() async {
        do {
            try await Log.api("initialize(defaultTimeout: 15)") { try await adapter.initialize(defaultTimeout: 15) }
            isInitialized = true
            for await state in try await adapter.adapterStates() {
                self.state = state
                Log.event(state == .poweredOn ? "Bluetooth on" : "Bluetooth \(state)")
            }
        } catch {
            self.error = describe(error)
            Log.error("Bluetooth unavailable: \(describe(error))")
        }
    }
}
