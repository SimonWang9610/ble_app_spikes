import BlePocSwift
import Foundation
import Observation

enum ConnectionStatus: Equatable {
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case disconnecting
    case disconnected(reason: String?)

    var text: String {
        switch self {
        case .connecting: "Connecting…"
        case .connected: "Connected"
        case let .reconnecting(attempt): "Link lost, reconnecting (attempt \(attempt))…"
        case .disconnecting: "Disconnecting…"
        case let .disconnected(reason): reason.map { "Disconnected: \($0)" } ?? "Disconnected"
        }
    }
}

struct ServiceGroup: Identifiable {
    let uuid: String
    let characteristics: [CharacteristicState]
    var id: String { uuid }
}

/// One characteristic as the user sees it. Its own `@Observable` object, so a ticking row redraws alone.
/// Only `DeviceSession` (same file) changes it; views read it and bind the write form.
@MainActor
@Observable
final class CharacteristicState: Identifiable {
    enum Source: String { case read, received, written }

    let ref: CharacteristicRef
    let properties: CharacteristicProperties
    fileprivate(set) var latest: Data?
    fileprivate(set) var latestTime: Date?
    fileprivate(set) var latestSource: Source?
    /// What the user asked for; re-applied after a reconnect.
    fileprivate(set) var subscribed = false
    fileprivate(set) var receivedCount = 0
    fileprivate(set) var busy: String?
    fileprivate(set) var error: String?

    // Write form, bound to the dialog's controls.
    var input = ""
    var inputFormat = ValueFormat.hex
    var withoutResponse: Bool

    init(ref: CharacteristicRef, properties: CharacteristicProperties) {
        self.ref = ref
        self.properties = properties
        withoutResponse = !properties.write && properties.writeWithoutResponse
    }

    nonisolated var id: CharacteristicRef { ref }
    var name: String { Fixture.shortName(ref.characteristic) }
    var canSubscribe: Bool { properties.notify || properties.indicate }
    var canWrite: Bool { properties.write || properties.writeWithoutResponse }

    /// "2a 00 00 00 = 42" for notify / indicate counters, "68 69 "hi"" for text, hex otherwise.
    func show(_ value: Data) -> String {
        value.display(asCounter: canSubscribe)
    }
}

/// One connected device. Owns the connection, auto-reconnect and subscriptions, and outlives the
/// Device screen: going back keeps everything until Disconnect.
@MainActor
@Observable
final class DeviceSession {
    private static let reconnectDelays: [Double] = [1, 2, 4, 8, 10]
    private static let reconnectLimit: Double = 60

    let remoteId: String
    let name: String
    private(set) var status = ConnectionStatus.disconnected(reason: nil)
    var autoReconnect = true
    private(set) var rssi: Int32?
    private(set) var mtu: Int32?
    private(set) var services: [ServiceGroup] = []

    private let service: BleService
    private let log: DeviceLog
    // Tasks the session owns; not UI state.
    @ObservationIgnored private var watcher: Task<Void, Never>?
    @ObservationIgnored private var reconnecting: Task<Void, Never>?
    @ObservationIgnored private var valueStreams: [CharacteristicRef: Task<Void, Never>] = [:]
    @ObservationIgnored private var states: [CharacteristicRef: CharacteristicState] = [:]

    init(remoteId: String, name: String, service: BleService, log: DeviceLog) {
        self.remoteId = remoteId
        self.name = name.isEmpty ? remoteId : name
        self.service = service
        self.log = log
    }

    var isConnected: Bool { status == .connected }

    // MARK: Connection

    func connect() async {
        status = .connecting
        log.event("Connecting to \(name)")
        do {
            try await establish()
            status = .connected
            log.event("Connected")
        } catch {
            status = .disconnected(reason: describe(error))
            log.error("Connect failed: \(describe(error))")
        }
    }

    func disconnect() async {
        reconnecting?.cancel()
        status = .disconnecting
        clearSubscriptions()
        do {
            try await log.api("disconnect()") { try await service.disconnect(remoteId) }
        } catch {
            log.error("Disconnect failed: \(describe(error))")
        }
        endWatching()
        status = .disconnected(reason: nil)
        log.event("Disconnected")
    }

    /// Ends the session's tasks; the store calls it when the session is replaced.
    func endWatching() {
        watcher?.cancel()
        watcher = nil
        reconnecting?.cancel()
        for task in valueStreams.values { task.cancel() }
        valueStreams.removeAll()
    }

    func refreshRssi() async {
        do {
            rssi = try await log.api("readRssi()") { try await service.readRssi(remoteId) }
        } catch {
            log.error("RSSI failed: \(describe(error))")
        }
    }

    /// Connect, discover, then re-apply the user's subscriptions.
    private func establish() async throws {
        try await log.api("connect(timeout: 10)") { try await service.connect(remoteId, timeout: 10) }
        startWatching()
        let found = try await log.api("discoverServices()") { try await service.discoverServices(remoteId) }
        apply(found)
        mtu = try? await service.mtu(remoteId)
        let count = found.reduce(0) { $0 + $1.characteristics.count }
        log.event("Found \(found.count) services, \(count) characteristics")
        for state in states.values where state.subscribed {
            try await enableValues(state)
        }
    }

    /// Keeps the characteristic objects across rediscovery, so values and subscriptions survive.
    private func apply(_ found: [BluetoothService]) {
        services = found.map { service in
            ServiceGroup(uuid: service.serviceUuid, characteristics: service.characteristics.map { info in
                let ref = CharacteristicRef(
                    remoteId: remoteId, service: service.serviceUuid, characteristic: info.characteristicUuid)
                if let state = states[ref] { return state }
                let state = CharacteristicState(ref: ref, properties: info.properties)
                states[ref] = state
                return state
            })
        }
    }

    // MARK: Link loss

    private func startWatching() {
        guard watcher == nil else { return }
        watcher = Task { [weak self] in
            guard let self else { return }
            do {
                // Emits the current state first; only a drop from `connected` counts as link loss.
                for await state in try await service.connectionStates(remoteId) where state == .disconnected {
                    if status == .connected { linkLost() }
                }
            } catch {
                log.error("Connection state unavailable: \(describe(error))")
            }
        }
    }

    private func linkLost() {
        log.event("Link lost")
        for state in states.values where state.subscribed {
            valueStreams.removeValue(forKey: state.ref)?.cancel()
        }
        guard autoReconnect else {
            clearSubscriptions()
            status = .disconnected(reason: "link lost")
            return
        }
        reconnecting = Task { await reconnect() }
    }

    private func reconnect() async {
        let start = ContinuousClock.now
        var attempt = 0
        while !Task.isCancelled {
            attempt += 1
            status = .reconnecting(attempt: attempt)
            log.event("Reconnecting, attempt \(attempt)")
            do {
                try await establish()
                let seconds = (ContinuousClock.now - start).seconds
                let resumed = states.values.filter(\.subscribed).map(\.name).sorted()
                status = .connected
                log.event("Reconnected after \(seconds.formatted(.number.precision(.fractionLength(1)))) s"
                          + (resumed.isEmpty ? "" : ", resumed \(resumed.joined(separator: ", "))"))
                return
            } catch is CancellationError {
                return
            } catch {
                log.error("Reconnect attempt \(attempt) failed: \(describe(error))")
            }
            let delay = Self.reconnectDelays[min(attempt - 1, Self.reconnectDelays.count - 1)]
            let elapsed = (ContinuousClock.now - start).seconds
            if elapsed + delay > Self.reconnectLimit {
                clearSubscriptions()
                status = .disconnected(reason: "gave up reconnecting after \(Int(Self.reconnectLimit)) s")
                log.error("Gave up reconnecting")
                return
            }
            try? await Task.sleep(for: .seconds(delay))
        }
    }

    private func clearSubscriptions() {
        for state in states.values where state.subscribed {
            state.subscribed = false
            valueStreams.removeValue(forKey: state.ref)?.cancel()
        }
    }

    // MARK: Characteristic actions

    func read(_ state: CharacteristicState) async {
        await perform(state, busy: "Reading…") {
            let value = try await log.api("read \(state.name)") { try await service.read(state.ref) }
            state.update(value, .read)
            log.value("\(state.name) read \(state.show(value))")
        }
    }

    func write(_ state: CharacteristicState) async {
        await perform(state, busy: "Writing…") {
            let value = try Data(state.input, format: state.inputFormat)
            let withoutResponse = state.withoutResponse
            try await log.api("write \(state.name) withoutResponse: \(withoutResponse)") {
                try await service.write(state.ref, value, withoutResponse: withoutResponse)
            }
            state.update(value, .written)
            log.value("\(state.name) wrote \(state.show(value))")
        }
    }

    func setSubscribed(_ state: CharacteristicState, _ on: Bool) async {
        await perform(state, busy: on ? "Subscribing…" : "Unsubscribing…") {
            if on {
                try await enableValues(state)
                state.subscribed = true
                log.event("\(state.name) subscribed")
            } else {
                stopValues(state)
                state.subscribed = false
                _ = try await log.api("setNotifyValue(false) \(state.name)") { try await service.setNotify(state.ref, false) }
                log.event("\(state.name) unsubscribed")
            }
        }
    }

    /// Listens first, then enables notify / indicate, so no value is missed.
    private func enableValues(_ state: CharacteristicState) async throws {
        valueStreams.removeValue(forKey: state.ref)?.cancel()
        let values = try await service.values(state.ref)
        valueStreams[state.ref] = Task { [weak self] in
            for await value in values {
                state.update(value, .received)
                state.receivedCount += 1
                self?.log.value("\(state.name) received \(state.show(value))")
            }
        }
        do {
            _ = try await log.api("setNotifyValue(true) \(state.name)") { try await service.setNotify(state.ref, true) }
        } catch {
            stopValues(state)
            throw error
        }
    }

    private func stopValues(_ state: CharacteristicState) {
        valueStreams.removeValue(forKey: state.ref)?.cancel()
    }

    private func perform(_ state: CharacteristicState, busy: String, _ body: () async throws -> Void) async {
        state.busy = busy
        state.error = nil
        do {
            try await body()
        } catch {
            state.error = describe(error)
            log.error("\(state.name): \(describe(error))")
        }
        state.busy = nil
    }
}

private extension CharacteristicState {
    func update(_ value: Data, _ source: Source) {
        latest = value
        latestTime = .now
        latestSource = source
    }
}

private extension Duration {
    var seconds: Double { Double(components.seconds) + Double(components.attoseconds) / 1e18 }
}
