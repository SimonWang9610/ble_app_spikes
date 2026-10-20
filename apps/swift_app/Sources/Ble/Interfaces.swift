import BlePocSwift
import Foundation

struct CharacteristicRef: Hashable, Sendable {
    let remoteId: String
    let service: String
    let characteristic: String
}

/// The adapter and scanning.
protocol BleAdapter: Sendable {
    func initialize(defaultTimeout: Double) async throws
    func adapterStates() async throws -> AsyncStream<BluetoothAdapterState>
    func startScan(names: [String]) async throws
    func stopScan() async throws
    func scanResults() async throws -> AsyncStream<[ScanResult]>
}

/// The link to one device.
protocol DeviceLink: Sendable {
    func connect(_ remoteId: String, timeout: Double) async throws
    func disconnect(_ remoteId: String) async throws
    func connectionStates(_ remoteId: String) async throws -> AsyncStream<BluetoothConnectionState>
    func discoverServices(_ remoteId: String) async throws -> [BluetoothService]
    func mtu(_ remoteId: String) async throws -> Int32
    func readRssi(_ remoteId: String) async throws -> Int32
    /// Drops the cached handle, so the next session starts from a fresh one.
    func forget(_ remoteId: String) async
}

/// Reads, writes and notifications of one characteristic.
protocol GattIO: Sendable {
    func read(_ ref: CharacteristicRef) async throws -> Data
    func write(_ ref: CharacteristicRef, _ value: Data, withoutResponse: Bool) async throws
    func setNotify(_ ref: CharacteristicRef, _ enable: Bool) async throws -> Bool
    func values(_ ref: CharacteristicRef) async throws -> AsyncStream<Data>
}
