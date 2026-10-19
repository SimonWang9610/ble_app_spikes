import BlePocSwift
import Foundation

// hm_ble makes every public object thread-safe (ble-poc-plan.md B10), so its classes may cross
// actors. The generated code doesn't say so; these conformances do.
extension BleManager: @retroactive @unchecked Sendable {}
extension BluetoothDevice: @retroactive @unchecked Sendable {}
extension BluetoothCharacteristic: @retroactive @unchecked Sendable {}
extension BleManagerAdapterStateStream: @retroactive @unchecked Sendable {}
extension BleManagerScanResultsStream: @retroactive @unchecked Sendable {}
extension BluetoothDeviceConnectionStateStream: @retroactive @unchecked Sendable {}
extension BluetoothCharacteristicOnValueReceivedStream: @retroactive @unchecked Sendable {}

struct CharacteristicRef: Hashable, Sendable {
    let remoteId: String
    let service: String
    let characteristic: String
}

/// The only code that touches the binding. Models call it; it holds no UI state.
///
/// An actor so the device cache is safe to use from any task. While a call awaits the binding,
/// the actor is free for other calls (actors are re-entrant), so a slow `connect` blocks nothing.
actor BleService {
    private let manager = BleManager()
    // Handles share the core's state; keeping one per device keeps the core from forgetting it.
    private var devices: [String: BluetoothDevice] = [:]

    // MARK: Adapter

    func initialize(defaultTimeout: Double) async throws {
        try await manager.initialize(options: InitOptions(defaultTimeout: defaultTimeout))
    }

    func adapterStates() throws -> AsyncStream<BluetoothAdapterState> {
        let stream = try manager.adapterState()
        return bridge(stream.items()) { stream.close() }
    }

    // MARK: Scan

    func startScan(names: [String]) async throws {
        try await manager.startScan(
            options: ScanOptions(withServices: [], withNames: names, timeout: nil, removeIfGone: nil))
    }

    func stopScan() async throws {
        try await manager.stopScan()
    }

    func scanResults() throws -> AsyncStream<[ScanResult]> {
        let stream = try manager.scanResults()
        return bridge(stream.items()) { stream.close() }
    }

    // MARK: Device

    func connect(_ remoteId: String, timeout: Double) async throws {
        try await device(remoteId).connect(timeout: timeout)
    }

    func disconnect(_ remoteId: String) async throws {
        try await device(remoteId).disconnect()
    }

    func connectionStates(_ remoteId: String) throws -> AsyncStream<BluetoothConnectionState> {
        let stream = try device(remoteId).connectionState()
        return bridge(stream.items()) { stream.close() }
    }

    func discoverServices(_ remoteId: String) async throws -> [BluetoothService] {
        try await device(remoteId).discoverServices(timeout: nil)
    }

    func servicesList(_ remoteId: String) throws -> [BluetoothService] {
        try device(remoteId).servicesList()
    }

    func mtu(_ remoteId: String) throws -> Int32 {
        try device(remoteId).mtuNow()
    }

    func readRssi(_ remoteId: String) async throws -> Int32 {
        try await device(remoteId).readRssi()
    }

    // MARK: Characteristic

    func read(_ ref: CharacteristicRef) async throws -> Data {
        try await characteristic(ref).read(timeout: nil)
    }

    func write(_ ref: CharacteristicRef, _ value: Data, withoutResponse: Bool) async throws {
        try await characteristic(ref).write(value: value, withoutResponse: withoutResponse, timeout: nil)
    }

    func setNotify(_ ref: CharacteristicRef, _ enable: Bool) async throws -> Bool {
        try await characteristic(ref).setNotifyValue(enable: enable, timeout: nil)
    }

    func isNotifying(_ ref: CharacteristicRef) throws -> Bool {
        try characteristic(ref).isNotifying()
    }

    func values(_ ref: CharacteristicRef) throws -> AsyncStream<Data> {
        let stream = try characteristic(ref).onValueReceived()
        return bridge(stream.items()) { stream.close() }
    }

    // MARK: Handles

    private func device(_ remoteId: String) throws -> BluetoothDevice {
        if let device = devices[remoteId] { return device }
        let device = try manager.device(remoteId: remoteId)
        devices[remoteId] = device
        return device
    }

    private func characteristic(_ ref: CharacteristicRef) throws -> BluetoothCharacteristic {
        try device(ref.remoteId).characteristic(serviceUuid: ref.service, characteristicUuid: ref.characteristic)
    }
}

/// Re-wraps a binding stream so the binding object stays alive while it is consumed,
/// and is closed when the consumer stops (its task is cancelled or the loop ends).
private func bridge<T: Sendable>(
    _ items: AsyncStream<T>,
    close: @escaping @Sendable () -> Void
) -> AsyncStream<T> {
    AsyncStream { continuation in
        let task = Task {
            for await item in items { continuation.yield(item) }
            continuation.finish()
        }
        continuation.onTermination = { _ in
            task.cancel()
            close()
        }
    }
}

func describe(_ error: Error) -> String {
    if let error = error as? BleError { return "BleError.\(error)" }
    return error.localizedDescription
}
