import BlePocSwift
import Testing
@testable import BlePocSwiftApp

struct FixtureTests {
    private let value = FakeBle.value.characteristic
    private let foreign = BluetoothService(
        remoteId: FakeBle.deviceId, serviceUuid: "0000180a-0000-1000-8000-00805f9b34fb", isPrimary: true,
        characteristics: [])

    @Test func names() {
        #expect(Fixture.knownName(value) == "VALUE")
        #expect(Fixture.knownName("1234") == nil)
        #expect(Fixture.shortName(value) == "VALUE")
        #expect(Fixture.shortName("0000180a-0000") == "0000180a…")
        #expect(Fixture.label(value) == "VALUE (f0e10001…)")
    }

    @Test func keepsOnlyFixtureServicesWhenPresent() {
        #expect(Fixture.services(of: FakeBle.fixture + [foreign]) == FakeBle.fixture)
        #expect(Fixture.services(of: [foreign]) == [foreign])
    }
}
