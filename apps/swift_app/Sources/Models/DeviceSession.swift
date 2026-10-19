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

    init(ref: CharacteristicRef, properties: CharacteristicProperties) {
        self.ref = ref
        self.properties = properties
    }

    nonisolated var id: CharacteristicRef { ref }
    var name: String { Fixture.shortName(ref.characteristic) }
    var canSubscribe: Bool { properties.notify || properties.indicate }

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
    // Bumped by Disconnect; work started under an older run stops at its next await.
    @ObservationIgnored private var run = 0
    @ObservationIgnored private var connectedAt: ContinuousClock.Instant?

    init(remoteId: String, name: String, service: BleService, log: DeviceLog) {
        self.remoteId = remoteId
        self.name = name.isEmpty ? remoteId : name
        self.service = service
        self.log = log
    }

    var isConnected: Bool { status == .connected }

    // MARK: Connection

    func connect() async {
        let token = run
        status = .connecting
        log.event("Connecting to \(name)")
        do {
            try await establish(token)
            markConnected()
            log.event("Connected")
        } catch {
            guard isCurrent(token) else { return }
            status = .disconnected(reason: describe(error))
            log.error("Connect failed: \(describe(error))")
        }
    }

    func disconnect() async {
        run += 1
        reconnecting?.cancel()
        reconnecting = nil
        // Unsubscribing only works over a live link; while reconnecting it would just time out.
        let live = status == .connected
        status = .disconnecting
        for state in states.values where live && state.subscribed {
            do {
                _ = try await log.api("setNotifyValue(false) \(state.name)") { try await service.setNotify(state.ref, false) }
            } catch {
                log.error("\(state.name): unsubscribe failed: \(describe(error))")
            }
        }
        clearSubscriptions()
        do {
            try await log.api("disconnect()") { try await service.disconnect(remoteId) }
        } catch {
            log.error("Disconnect failed: \(describe(error))")
        }
        watcher?.cancel()
        watcher = nil
        await service.forget(remoteId)
        connectedAt = nil
        status = .disconnected(reason: nil)
        log.event("Disconnected")
    }

    func refreshRssi() async {
        do {
            rssi = try await log.api("readRssi()") { try await service.readRssi(remoteId) }
        } catch {
            log.error("RSSI failed: \(describe(error))")
        }
    }

    private func isCurrent(_ token: Int) -> Bool {
        token == run && !Task.isCancelled
    }

    private func check(_ token: Int) throws {
        guard isCurrent(token) else { throw CancellationError() }
    }

    private func markConnected() {
        status = .connected
        connectedAt = .now
    }

    /// Connect, discover, then re-apply the user's subscriptions. Fails unless every one is back.
    private func establish(_ token: Int) async throws {
        try await log.api("connect(timeout: 10)") { try await service.connect(remoteId, timeout: 10) }
        try check(token)
        startWatching(token)
        let found = try await log.api("discoverServices()") { try await service.discoverServices(remoteId) }
        try check(token)
        let subscribed = states.values.filter(\.subscribed)
        let foundRefs = Set(found.flatMap { service in
            service.characteristics.map {
                CharacteristicRef(remoteId: remoteId, service: service.serviceUuid, characteristic: $0.characteristicUuid)
            }
        })
        let missing = subscribed.filter { !foundRefs.contains($0.ref) }.map(\.name).sorted()
        if !missing.isEmpty {
            throw SessionError(message: "not found after discovery: \(missing.joined(separator: ", "))")
        }
        apply(found)
        mtu = try? await service.mtu(remoteId)
        try check(token)
        let count = found.reduce(0) { $0 + $1.characteristics.count }
        log.event("Found \(found.count) services, \(count) characteristics")
        for state in subscribed {
            try await enableValues(state, token)
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

    /// One watcher per link: replaces the previous link's watcher.
    private func startWatching(_ token: Int) {
        watcher?.cancel()
        watcher = Task { [weak self] in
            guard let self else { return }
            do {
                let updates = try await service.connectionStates(remoteId)
                guard isCurrent(token) else { return }
                // Emits the current state first; only a drop from `connected` counts as link loss.
                for await state in updates where state == .disconnected {
                    if isCurrent(token), status == .connected { linkLost() }
                }
            } catch {
                guard isCurrent(token) else { return }
                log.error("Connection state unavailable: \(describe(error))")
            }
        }
    }

    private func linkLost() {
        let up = connectedAt.map { (ContinuousClock.now - $0).seconds } ?? 0
        connectedAt = nil
        log.event("Link lost after \(up.oneDecimal) s")
        stopAllValues()
        guard autoReconnect else {
            clearSubscriptions()
            status = .disconnected(reason: "link lost")
            return
        }
        let token = run
        reconnecting = Task { await reconnect(token) }
    }

    private func reconnect(_ token: Int) async {
        let start = ContinuousClock.now
        var attempt = 0
        while isCurrent(token) {
            attempt += 1
            status = .reconnecting(attempt: attempt)
            log.event("Reconnecting, attempt \(attempt)")
            do {
                try await establish(token)
                let seconds = (ContinuousClock.now - start).seconds
                let resumed = states.values.filter(\.subscribed).map(\.name).sorted()
                markConnected()
                log.event("Reconnected after \(seconds.oneDecimal) s"
                          + (resumed.isEmpty ? "" : ", resumed \(resumed.joined(separator: ", "))"))
                return
            } catch {
                guard isCurrent(token) else { return }
                log.error("Reconnect attempt \(attempt) failed: \(describe(error))")
            }
            // Close the half-open link so nothing of this attempt survives into the next one.
            stopAllValues()
            do {
                try await log.api("disconnect()") { try await service.disconnect(remoteId) }
            } catch {
                log.error("Cleanup disconnect failed: \(describe(error))")
            }
            guard isCurrent(token) else { return }
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
        stopAllValues()
        for state in states.values { state.subscribed = false }
    }

    private func stopAllValues() {
        for task in valueStreams.values { task.cancel() }
        valueStreams.removeAll()
    }

    // MARK: Characteristic actions

    func read(_ state: CharacteristicState) async {
        await perform(state, busy: "Reading…") {
            let value = try await log.api("read \(state.name)") { try await service.read(state.ref) }
            state.update(value, .read)
            log.value("\(state.name) read \(state.show(value))")
        }
    }

    func write(_ state: CharacteristicState, withoutResponse: Bool) async {
        await perform(state, busy: "Writing…") {
            let value = try Data(state.input, format: state.inputFormat)
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
                try await enableValues(state, run)
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
    private func enableValues(_ state: CharacteristicState, _ token: Int) async throws {
        valueStreams.removeValue(forKey: state.ref)?.cancel()
        let values = try await service.values(state.ref)
        try check(token)
        valueStreams[state.ref] = Task { [weak self] in
            for await value in values {
                state.update(value, .received)
                state.receivedCount += 1
                self?.log.value("\(state.name) received \(state.show(value))")
            }
        }
        do {
            _ = try await log.api("setNotifyValue(true) \(state.name)") { try await service.setNotify(state.ref, true) }
            try check(token)
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
        } catch is CancellationError {
            // Disconnect began; nothing to report.
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

private extension Double {
    /// "7.3"
    var oneDecimal: String { formatted(.number.precision(.fractionLength(1))) }
}

private struct SessionError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
