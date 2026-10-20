/// Notify / indicate value streams, one per subscribed characteristic. No UI reads it.
@MainActor
final class Subscriptions {
    private let io: any GattIO
    private let log: Log
    // What the user subscribed to; kept across a reconnect and resumed after it.
    private var wanted: [CharacteristicRef: Characteristic] = [:]
    private var streams: [CharacteristicRef: Task<Void, Never>] = [:]

    init(io: any GattIO, log: Log) {
        self.io = io
        self.log = log
    }

    /// "NOTIFY, INDICATE"
    var names: [String] { wanted.values.map(\.name).sorted() }

    func set(_ characteristic: Characteristic, _ on: Bool) async {
        let name = characteristic.name
        try? await characteristic.perform(busy: on ? "Subscribing…" : "Unsubscribing…") {
            if on {
                try await enable(characteristic)
                wanted[characteristic.ref] = characteristic
                characteristic.markSubscribed(true)
                log.event("\(name) subscribed")
            } else {
                stop(characteristic)
                wanted[characteristic.ref] = nil
                characteristic.markSubscribed(false)
                _ = try await log.api("setNotifyValue(false) \(name)") { try await io.setNotify(characteristic.ref, false) }
                log.event("\(name) unsubscribed")
            }
        }
    }

    /// Re-applies every subscription on a new link. Fails unless every one is back.
    func resume() async throws {
        for characteristic in wanted.values.sorted(by: { $0.name < $1.name }) {
            try await enable(characteristic)
        }
    }

    /// Cancels the streams but keeps the subscriptions, for a reconnect to resume.
    func pause() {
        for task in streams.values { task.cancel() }
        streams.removeAll()
    }

    /// Turns notify / indicate off on the device; only over a live link, otherwise it would time out.
    func unsubscribeAll() async {
        for characteristic in wanted.values.sorted(by: { $0.name < $1.name }) {
            do {
                _ = try await log.api("setNotifyValue(false) \(characteristic.name)") {
                    try await io.setNotify(characteristic.ref, false)
                }
            } catch {
                log.error("\(characteristic.name): unsubscribe failed: \(describe(error))")
            }
        }
    }

    /// Ends every subscription and its stream, without telling the device.
    func dropAll() {
        pause()
        for characteristic in wanted.values { characteristic.markSubscribed(false) }
        wanted.removeAll()
    }

    /// Listens first, then enables notify / indicate, so no value is missed.
    private func enable(_ characteristic: Characteristic) async throws {
        stop(characteristic)
        do {
            let values = try await io.values(characteristic.ref)
            streams[characteristic.ref] = Task {
                for await value in values {
                    characteristic.record(value, .received)
                    log.value("\(characteristic.name) received \(characteristic.show(value))")
                }
            }
            _ = try await log.api("setNotifyValue(true) \(characteristic.name)") {
                try await io.setNotify(characteristic.ref, true)
            }
        } catch {
            stop(characteristic)
            throw error
        }
    }

    private func stop(_ characteristic: Characteristic) {
        streams.removeValue(forKey: characteristic.ref)?.cancel()
    }
}
