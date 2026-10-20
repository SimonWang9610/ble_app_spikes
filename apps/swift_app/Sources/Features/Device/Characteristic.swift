import BlePocSwift
import Foundation
import Observation

/// One characteristic as the user sees it. Its own `@Observable` object, so a ticking row redraws alone.
/// Lives as long as the session; Disconnect drops it. The write form stays in the dialog.
@MainActor
@Observable
final class Characteristic: Identifiable {
    enum Source: String { case read, received, written }

    let ref: CharacteristicRef
    let properties: CharacteristicProperties
    private(set) var latest: Data?
    private(set) var latestTime: Date?
    private(set) var latestSource: Source?
    /// What the user asked for; re-applied after a reconnect.
    private(set) var subscribed = false
    private(set) var receivedCount = 0
    private(set) var busy: String?
    private(set) var error: String?

    private let io: any GattIO

    init(ref: CharacteristicRef, properties: CharacteristicProperties, io: any GattIO) {
        self.ref = ref
        self.properties = properties
        self.io = io
    }

    nonisolated var id: CharacteristicRef { ref }
    var name: String { Fixture.shortName(ref.characteristic) }
    var canSubscribe: Bool { properties.notify || properties.indicate }

    /// "2a 00 00 00 = 42" for notify / indicate counters, "68 69 "hi"" for text, hex otherwise.
    func show(_ value: Data) -> String {
        value.display(asCounter: canSubscribe)
    }

    func read() async {
        try? await perform(busy: "Reading…") {
            let value = try await Log.api("read \(name)") { try await io.read(ref) }
            record(value, .read)
            Log.value("\(name) read \(show(value))")
        }
    }

    /// Throws, so the dialog can show how its own write went.
    func write(_ value: Data, withoutResponse: Bool) async throws {
        try await perform(busy: "Writing…") {
            try await Log.api("write \(name) withoutResponse: \(withoutResponse)") {
                try await io.write(ref, value, withoutResponse: withoutResponse)
            }
            record(value, .written)
            Log.value("\(name) wrote \(show(value))")
        }
    }

    /// Shows busy and error around one action.
    func perform(busy: String, _ body: () async throws -> Void) async throws {
        self.busy = busy
        error = nil
        defer { self.busy = nil }
        do {
            try await body()
        } catch {
            self.error = describe(error)
            Log.error("\(name): \(describe(error))")
            throw error
        }
    }

    func record(_ value: Data, _ source: Source) {
        latest = value
        latestTime = .now
        latestSource = source
        if source == .received { receivedCount += 1 }
    }

    func markSubscribed(_ on: Bool) {
        subscribed = on
    }
}
