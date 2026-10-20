import BlePocSwift

/// The fixture's name and UUIDs (docs/test-plan.md), used for the default scan filter and labels.
enum Fixture {
    static let name = "HM-BLE-FIXTURE"

    private static let labels = [
        "f0e10000-5a3e-4c1a-9d2b-1b2c3d4e5f60": "DATA",
        "f0e10001-5a3e-4c1a-9d2b-1b2c3d4e5f60": "VALUE",
        "5a7e0000-8c2d-4b6e-9f1a-2b3c4d5e6f70": "STREAM",
        "5a7e0001-8c2d-4b6e-9f1a-2b3c4d5e6f70": "NOTIFY",
        "5a7e0002-8c2d-4b6e-9f1a-2b3c4d5e6f70": "INDICATE",
    ]

    /// Only the fixture's services when the device has any (a Mac also exposes its own), else all.
    static func services(of services: [BluetoothService]) -> [BluetoothService] {
        let own = services.filter { labels[$0.serviceUuid] != nil }
        return own.isEmpty ? services : own
    }

    /// "VALUE" for fixture UUIDs, nil otherwise.
    static func knownName(_ uuid: String) -> String? {
        labels[uuid]
    }

    /// "VALUE" for fixture UUIDs, "f0e1ffff…" otherwise.
    static func shortName(_ uuid: String) -> String {
        labels[uuid] ?? "\(uuid.prefix(8))…"
    }

    /// "VALUE (f0e10001…)" for fixture UUIDs, the UUID otherwise.
    static func label(_ uuid: String) -> String {
        guard let name = labels[uuid] else { return uuid }
        return "\(name) (\(uuid.prefix(8))…)"
    }
}
