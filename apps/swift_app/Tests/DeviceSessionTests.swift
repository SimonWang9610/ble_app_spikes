import Foundation
import Testing
@testable import BlePocSwiftApp

@MainActor
struct DeviceSessionTests {
    private let ble = FakeBle()
    private let log = Log()
    private let session: DeviceSession

    init() {
        session = DeviceSession(remoteId: FakeBle.deviceId, name: "", ble: ble, log: log)
    }

    private var notify: Characteristic { session.gatt.characteristic(FakeBle.notify)! }

    @Test func connectsAndDiscovers() async {
        await session.connect()
        #expect(session.connection.status == .connected)
        #expect(session.name == FakeBle.deviceId)
        #expect(session.connection.mtu == 247)
        #expect(session.gatt.services.map { $0.characteristics.count } == [1, 2])
    }

    @Test func reportsAFailedConnect() async {
        await ble.setFailConnect(true)
        await session.connect()
        #expect(session.connection.status == .disconnected(reason: "connection refused"))
        #expect(log.entries.contains { $0.kind == .error && $0.text == "Connect failed: connection refused" })
    }

    @Test func receivesSubscribedValues() async {
        await session.connect()
        await session.subscriptions.set(notify, true)
        #expect(notify.subscribed)
        await ble.push(Data([0x2a, 0, 0, 0]), to: FakeBle.notify)
        #expect(await eventually { notify.receivedCount == 1 })
        #expect(notify.latest == Data([0x2a, 0, 0, 0]))
        #expect(notify.latestSource == .received)
    }

    @Test func reconnectsAndResumesAfterLinkLoss() async {
        await session.connect()
        await session.subscriptions.set(notify, true)
        await ble.dropLink(FakeBle.deviceId)
        #expect(await eventually { reconnectedLine?.hasSuffix(", resumed NOTIFY") == true })
        #expect(session.connection.status == .connected)
        #expect(await ble.notifying == [FakeBle.notify])
        #expect(notify.subscribed)
    }

    @Test func retriesAfterAFailedAttempt() async {
        await session.connect()
        await ble.setFailConnect(true)
        await ble.dropLink(FakeBle.deviceId)
        #expect(await eventually { logged("Reconnect attempt 1 failed: connection refused") })
        // The failed attempt closes its half-open link before the next one.
        #expect(await ble.calls.last == "disconnect")
        await ble.setFailConnect(false)
        #expect(await eventually(within: .seconds(3)) { reconnectedLine != nil })
        #expect(session.connection.status == .connected)
    }

    @Test func disconnectStopsReconnecting() async {
        await session.connect()
        await ble.setFailConnect(true)
        await ble.dropLink(FakeBle.deviceId)
        #expect(await eventually { logged("Reconnect attempt 1 failed: connection refused") })
        await session.disconnect()
        await ble.setFailConnect(false)
        try? await Task.sleep(for: .seconds(1.5))
        #expect(session.connection.status == .disconnected(reason: nil))
        #expect(!logged("Reconnecting, attempt 2"))
    }

    @Test func reconnectFailsWhenASubscribedCharacteristicIsGone() async {
        await session.connect()
        await session.subscriptions.set(notify, true)
        await ble.setServices(Array(FakeBle.fixture.prefix(1)))
        await ble.dropLink(FakeBle.deviceId)
        #expect(await eventually { logged("Reconnect attempt 1 failed: not found after discovery: NOTIFY") })
        #expect(session.connection.status != .connected)
    }

    @Test func staysDownWithoutAutoReconnect() async {
        await session.connect()
        session.connection.autoReconnect = false
        await ble.dropLink(FakeBle.deviceId)
        #expect(await eventually { session.connection.status == .disconnected(reason: "link lost") })
    }

    @Test func disconnectClearsEverything() async {
        await session.connect()
        await session.subscriptions.set(notify, true)
        await session.disconnect()
        #expect(session.connection.status == .disconnected(reason: nil))
        #expect(session.gatt.services.isEmpty)
        #expect(await ble.notifying.isEmpty)
        #expect(await ble.calls.suffix(3) == ["setNotify(false)", "disconnect", "forget"])
    }

    private var reconnectedLine: String? {
        log.entries.last { $0.text.hasPrefix("Reconnected after") }?.text
    }

    private func logged(_ text: String) -> Bool {
        log.entries.contains { $0.text == text }
    }
}
