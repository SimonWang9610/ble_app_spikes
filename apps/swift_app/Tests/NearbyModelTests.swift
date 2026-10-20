import Testing
@testable import BlePocSwiftApp

@MainActor
struct NearbyModelTests {
    private let ble = FakeBle()
    private let nearby: NearbyModel

    init() {
        nearby = NearbyModel(adapter: ble, log: Log())
    }

    @Test func scansForFixturesByDefault() async {
        let scan = Task { await nearby.scan() }
        #expect(await eventually { !nearby.results.isEmpty })
        #expect(nearby.results.map(\.remoteId) == [FakeBle.deviceId])
        #expect(nearby.isScanning)
        scan.cancel()
    }

    @Test func listsAllDevicesStrongestFirst() async {
        nearby.onlyFixtures = false
        let scan = Task { await nearby.scan() }
        #expect(await eventually { nearby.results.count == 2 })
        #expect(nearby.results.map(\.rssi) == [-52, -80])
        scan.cancel()
    }

    @Test func stopsScanningWhenCancelled() async {
        let scan = Task { await nearby.scan() }
        #expect(await eventually { nearby.isScanning })
        scan.cancel()
        await scan.value
        #expect(!nearby.isScanning)
        #expect(await scanStopped())
    }

    /// The stop runs on a task of its own after the scan ends.
    private func scanStopped() async -> Bool {
        for _ in 0..<200 {
            if await ble.calls.last == "stopScan" { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return false
    }
}
