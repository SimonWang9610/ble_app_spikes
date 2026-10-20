#if DEBUG
import BlePocSwift
import Foundation

/// In-memory stand-in for `BleService`, for previews and tests: one fixture-like device whose link
/// can fail, drop and push notify values on demand. Records every call.
actor FakeBle: BleAdapter, DeviceLink, GattIO {
    static let deviceId = "FAKE-DEVICE"
    static let value = CharacteristicRef(
        remoteId: deviceId, service: "f0e10000-5a3e-4c1a-9d2b-1b2c3d4e5f60",
        characteristic: "f0e10001-5a3e-4c1a-9d2b-1b2c3d4e5f60")
    static let notify = CharacteristicRef(
        remoteId: deviceId, service: "f0e10100-5a3e-4c1a-9d2b-1b2c3d4e5f60",
        characteristic: "f0e10101-5a3e-4c1a-9d2b-1b2c3d4e5f60")
    static let indicate = CharacteristicRef(
        remoteId: deviceId, service: "f0e10100-5a3e-4c1a-9d2b-1b2c3d4e5f60",
        characteristic: "f0e10102-5a3e-4c1a-9d2b-1b2c3d4e5f60")

    private(set) var calls: [String] = []
    private(set) var connected: Set<String> = []
    private(set) var notifying: Set<CharacteristicRef> = []
    private var devices: [ScanResult]
    private var services: [BluetoothService]
    private var failConnect = false
    private var failNotify = false
    private var dropOnNotify = false
    private var notifyDelay: Duration?
    private var stored: [CharacteristicRef: Data] = [:]
    private var scanStreams: [AsyncStream<[ScanResult]>.Continuation] = []
    private var stateStreams: [String: [AsyncStream<BluetoothConnectionState>.Continuation]] = [:]
    private var valueStreams: [CharacteristicRef: [AsyncStream<Data>.Continuation]] = [:]

    init(devices: [ScanResult] = FakeBle.nearby, services: [BluetoothService] = FakeBle.fixture) {
        self.devices = devices
        self.services = services
    }

    // MARK: Scripting

    func setFailConnect(_ fail: Bool) { failConnect = fail }

    func setFailNotify(_ fail: Bool) { failNotify = fail }

    /// The link drops during the next setNotify.
    func setDropOnNotify() { dropOnNotify = true }

    func setNotifyDelay(_ delay: Duration?) { notifyDelay = delay }

    /// What the next discovery finds.
    func setServices(_ services: [BluetoothService]) { self.services = services }

    /// The link drops as if the device went away.
    func dropLink(_ remoteId: String) {
        connected.remove(remoteId)
        notifying = notifying.filter { $0.remoteId != remoteId }
        stateStreams[remoteId]?.forEach { $0.yield(.disconnected) }
    }

    /// The device sends a notify / indicate value, if subscribed.
    func push(_ value: Data, to ref: CharacteristicRef) {
        guard notifying.contains(ref) else { return }
        valueStreams[ref]?.forEach { $0.yield(value) }
    }

    // MARK: BleAdapter

    func initialize(defaultTimeout: Double) {
        calls.append("initialize")
    }

    func adapterStates() -> AsyncStream<BluetoothAdapterState> {
        AsyncStream { $0.yield(.poweredOn) }
    }

    func startScan(names: [String]) {
        calls.append("startScan")
        let found = devices.filter { names.isEmpty || names.contains($0.advertisementData.advName) }
        scanStreams.forEach { $0.yield(found) }
    }

    func stopScan() {
        calls.append("stopScan")
    }

    func scanResults() -> AsyncStream<[ScanResult]> {
        stream(into: &scanStreams)
    }

    // MARK: DeviceLink

    func connect(_ remoteId: String, timeout: Double) throws {
        calls.append("connect")
        if failConnect { throw FakeError.refused }
        connected.insert(remoteId)
        stateStreams[remoteId]?.forEach { $0.yield(.connected) }
    }

    func disconnect(_ remoteId: String) {
        calls.append("disconnect")
        dropLink(remoteId)
    }

    func connectionStates(_ remoteId: String) -> AsyncStream<BluetoothConnectionState> {
        let (stream, continuation) = AsyncStream<BluetoothConnectionState>.makeStream()
        continuation.yield(connected.contains(remoteId) ? .connected : .disconnected)
        stateStreams[remoteId, default: []].append(continuation)
        return stream
    }

    func discoverServices(_ remoteId: String) throws -> [BluetoothService] {
        guard connected.contains(remoteId) else { throw FakeError.notConnected }
        return services
    }

    func mtu(_ remoteId: String) -> Int32 { 247 }

    func readRssi(_ remoteId: String) -> Int32 { -52 }

    func forget(_ remoteId: String) {
        calls.append("forget")
    }

    // MARK: GattIO

    func read(_ ref: CharacteristicRef) throws -> Data {
        guard connected.contains(ref.remoteId) else { throw FakeError.notConnected }
        return stored[ref] ?? Data("hi".utf8)
    }

    /// Like the fixture's VALUE: a write to a notifying characteristic comes back as "echo: <value>".
    func write(_ ref: CharacteristicRef, _ value: Data, withoutResponse: Bool) throws {
        calls.append("write")
        guard connected.contains(ref.remoteId) else { throw FakeError.notConnected }
        stored[ref] = value
        push(Data("echo: ".utf8) + value, to: ref)
    }

    func setNotify(_ ref: CharacteristicRef, _ enable: Bool) async throws -> Bool {
        calls.append("setNotify(\(enable))")
        if let notifyDelay { try? await Task.sleep(for: notifyDelay) }
        if dropOnNotify {
            dropOnNotify = false
            dropLink(ref.remoteId)
        }
        guard connected.contains(ref.remoteId) else { throw FakeError.notConnected }
        if failNotify { throw FakeError.notifyFailed }
        if enable { notifying.insert(ref) } else { notifying.remove(ref) }
        return enable
    }

    func values(_ ref: CharacteristicRef) -> AsyncStream<Data> {
        stream(into: &valueStreams[ref, default: []])
    }

    private func stream<T>(into continuations: inout [AsyncStream<T>.Continuation]) -> AsyncStream<T> {
        let (stream, continuation) = AsyncStream<T>.makeStream()
        continuations.append(continuation)
        return stream
    }
}

enum FakeError: LocalizedError {
    case refused, notConnected, notifyFailed

    var errorDescription: String? {
        switch self {
        case .refused: "connection refused"
        case .notConnected: "not connected"
        case .notifyFailed: "notify failed"
        }
    }
}

extension FakeBle {
    static let nearby = [
        ScanResult(remoteId: deviceId, address: nil, rssi: -52, advertisementData: advertisement(Fixture.name),
                   timeStamp: .now),
        ScanResult(remoteId: "FAKE-OTHER", address: nil, rssi: -80, advertisementData: advertisement("Speaker"),
                   timeStamp: .now),
    ]

    static let fixture = [
        BluetoothService(remoteId: deviceId, serviceUuid: value.service, isPrimary: true, characteristics: [
            CharacteristicInfo(characteristicUuid: value.characteristic, properties: properties(read: true, write: true, notify: true)),
        ]),
        BluetoothService(remoteId: deviceId, serviceUuid: notify.service, isPrimary: true, characteristics: [
            CharacteristicInfo(characteristicUuid: notify.characteristic, properties: properties(notify: true)),
            CharacteristicInfo(characteristicUuid: indicate.characteristic, properties: properties(indicate: true)),
        ]),
    ]

    private static func advertisement(_ name: String) -> AdvertisementData {
        AdvertisementData(advName: name, txPowerLevel: nil, manufacturerData: [:], serviceData: [:], serviceUuids: [])
    }

    private static func properties(read: Bool = false, write: Bool = false, notify: Bool = false,
                                   indicate: Bool = false) -> CharacteristicProperties {
        CharacteristicProperties(read: read, write: write, writeWithoutResponse: write, notify: notify,
                                 indicate: indicate)
    }
}
#endif
