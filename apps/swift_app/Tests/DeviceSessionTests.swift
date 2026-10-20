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
        #expect(await eventually { log.entries.contains { $0.text.hasPrefix("Reconnected after") } })
        #expect(session.connection.status == .connected)
        #expect(await ble.notifying == [FakeBle.notify])
        #expect(notify.subscribed)
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
        #expect(await ble.calls.suffix(2) == ["disconnect", "forget"])
    }
}
