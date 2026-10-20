import Observation

/// One connected device. Orders its parts (connection, discovery, subscriptions, reconnect) and
/// outlives the Device screen: going back keeps everything until Disconnect.
@MainActor
@Observable
final class DeviceSession {
    let remoteId: String
    let name: String
    let connection: Connection
    let gatt: Gatt
    let subscriptions: Subscriptions
    private let log: Log

    @ObservationIgnored private lazy var reconnector = Reconnector(session: self, log: log)

    /// `ble` is only handed on: the link to Connection and Gatt, characteristic IO to the rest.
    init(remoteId: String, name: String, ble: any DeviceLink & GattIO, log: Log) {
        self.remoteId = remoteId
        self.name = name.isEmpty ? remoteId : name
        self.log = log
        connection = Connection(remoteId: remoteId, link: ble, log: log)
        gatt = Gatt(remoteId: remoteId, link: ble, log: log) { ref, properties in
            Characteristic(ref: ref, properties: properties, io: ble, log: log)
        }
        subscriptions = Subscriptions(io: ble, log: log)
        connection.onLost = { [weak self] in await self?.linkLost() }
    }

    func connect() async {
        connection.update(.connecting)
        log.event("Connecting to \(name)")
        do {
            try await establish()
            await subscriptions.autoSubscribe(gatt.services.flatMap(\.characteristics)) { disconnectBegan }
            if settle(.connected) { log.event("Connected") }
        } catch is CancellationError {
        } catch {
            settle(.disconnected(reason: describe(error)))
            log.error("Connect failed: \(describe(error))")
        }
    }

    /// Stops reconnecting, unsubscribes, disconnects, then forgets the device (D23).
    func disconnect() async {
        reconnector.stop()
        let live = connection.isConnected
        connection.update(.disconnecting)
        if live { await subscriptions.unsubscribeAll() }
        subscriptions.dropAll()
        do {
            try await connection.disconnect()
        } catch {
            log.error("Disconnect failed: \(describe(error))")
        }
        await connection.close()
        gatt.clear()
        connection.update(.disconnected(reason: nil))
        log.event("Disconnected")
    }

    /// Connect, discover, then re-apply the user's subscriptions. Fails unless every one is back.
    /// Throws `CancellationError` if Disconnect began while connecting or discovering.
    func establish() async throws {
        try await connection.connect()
        await connection.readMtu()
        let services = try await gatt.discover()
        guard !disconnectBegan else { throw CancellationError() }
        connection.watch()
        try gatt.apply(services)
        try await subscriptions.resume()
    }

    /// Disconnect sets `.disconnecting` before its first await, and only it ends a connect or
    /// reconnect in `.disconnecting` / `.disconnected`.
    private var disconnectBegan: Bool {
        switch connection.status {
        case .disconnecting, .disconnected: true
        case .connecting, .connected, .reconnecting: false
        }
    }

    /// Reports how a connect or reconnect ended, unless Disconnect already did.
    @discardableResult
    private func settle(_ status: ConnectionStatus) -> Bool {
        guard !disconnectBegan else { return false }
        connection.update(status)
        return true
    }

    // MARK: Reconnect

    func reconnecting(_ attempt: Int) {
        connection.update(.reconnecting(attempt: attempt))
    }

    func reconnected(after seconds: Double) {
        guard settle(.connected) else { return }
        let resumed = subscriptions.names
        log.event("Reconnected after \(seconds.oneDecimal) s"
                  + (resumed.isEmpty ? "" : ", resumed \(resumed.joined(separator: ", "))"))
    }

    func dropAttempt() async {
        subscriptions.pause()
        do {
            try await connection.disconnect()
        } catch {
            log.error("Cleanup disconnect failed: \(describe(error))")
        }
    }

    func gaveUp(reason: String) {
        subscriptions.dropAll()
        settle(.disconnected(reason: reason))
    }

    /// Runs while the link was `connected`, so Disconnect hasn't begun.
    private func linkLost() async {
        subscriptions.pause()
        guard connection.autoReconnect else {
            subscriptions.dropAll()
            connection.update(.disconnected(reason: "link lost"))
            return
        }
        reconnector.start()
    }
}
