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

/// The link to one device: status, RSSI, MTU, and a watcher per link that reports link loss.
@MainActor
@Observable
final class Connection {
    private(set) var status = ConnectionStatus.disconnected(reason: nil)
    var autoReconnect = true
    private(set) var rssi: Int32?
    private(set) var mtu: Int32?
    /// Called when a live link drops; set by `DeviceSession`.
    @ObservationIgnored var onLost: (@MainActor () async -> Void)?

    private let remoteId: String
    private let link: any DeviceLink
    @ObservationIgnored private var watcher: Task<Void, Never>?
    @ObservationIgnored private var connectedAt: ContinuousClock.Instant?

    init(remoteId: String, link: any DeviceLink) {
        self.remoteId = remoteId
        self.link = link
    }

    var isConnected: Bool { status == .connected }

    /// Also starts or stops the uptime clock behind "Link lost after X s".
    func update(_ status: ConnectionStatus) {
        self.status = status
        connectedAt = status == .connected ? .now : nil
    }

    func connect() async throws {
        try await Log.api("connect(timeout: 10)") { try await link.connect(remoteId, timeout: 10) }
    }

    func readMtu() async {
        mtu = try? await link.mtu(remoteId)
    }

    /// Drops the link only; the handle and watcher stay until `close()`.
    func disconnect() async throws {
        try await Log.api("disconnect()") { try await link.disconnect(remoteId) }
    }

    /// Stops watching and forgets the device handle, so the next session starts fresh.
    func close() async {
        watcher?.cancel()
        watcher = nil
        await link.forget(remoteId)
    }

    func refreshRssi() async {
        do {
            rssi = try await Log.api("readRssi()") { try await link.readRssi(remoteId) }
        } catch {
            Log.error("RSSI failed: \(describe(error))")
        }
    }

    /// One watcher per link: replaces the previous link's watcher. `close()` cancels it.
    func watch() {
        watcher?.cancel()
        watcher = Task { [weak self] in
            guard let self else { return }
            do {
                let updates = try await link.connectionStates(remoteId)
                // Emits the current state first; only a drop from `connected` counts as link loss.
                for await state in updates where state == .disconnected {
                    if status == .connected { await linkLost() }
                }
            } catch {
                Log.error("Connection state unavailable: \(describe(error))")
            }
        }
    }

    private func linkLost() async {
        let up = connectedAt.map { (ContinuousClock.now - $0).seconds } ?? 0
        connectedAt = nil
        Log.event("Link lost after \(up.oneDecimal) s")
        await onLost?()
    }
}
