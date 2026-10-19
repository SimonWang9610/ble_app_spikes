/// The fixture's name and UUIDs (docs/test-plan.md), used for the default scan filter and labels.
enum Fixture {
    static let name = "HM-BLE-FIXTURE"

    private static let labels = [
        "f0e10000-5a3e-4c1a-9d2b-1b2c3d4e5f60": "DATA",
        "f0e10001-5a3e-4c1a-9d2b-1b2c3d4e5f60": "VALUE",
        "f0e10002-5a3e-4c1a-9d2b-1b2c3d4e5f60": "INFO",
        "f0e10100-5a3e-4c1a-9d2b-1b2c3d4e5f60": "STREAM",
        "f0e10101-5a3e-4c1a-9d2b-1b2c3d4e5f60": "NOTIFY",
        "f0e10102-5a3e-4c1a-9d2b-1b2c3d4e5f60": "INDICATE",
    ]

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
