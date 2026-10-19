import BlePocSwift
import Observation

/// Initializes the manager once and mirrors the adapter state. Lives as long as the app.
@MainActor
@Observable
final class AdapterModel {
    private(set) var state: BluetoothAdapterState?
    private(set) var isInitialized = false
    private(set) var error: String?

    private let service: BleService
    private let log: DeviceLog

    init(service: BleService, log: DeviceLog) {
        self.service = service
        self.log = log
    }

    /// Runs for the app's lifetime, from the root view's `.task`.
    func observe() async {
        do {
            try await log.api("initialize(defaultTimeout: 15)") { try await service.initialize(defaultTimeout: 15) }
            isInitialized = true
            for await state in try await service.adapterStates() {
                self.state = state
                log.event(state == .poweredOn ? "Bluetooth on" : "Bluetooth \(state)")
            }
        } catch {
            self.error = describe(error)
            log.error("Bluetooth unavailable: \(describe(error))")
        }
    }
}
