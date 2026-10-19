import Observation

/// Holds the device the app is connected to. One at a time; lives as long as the app.
@MainActor
@Observable
final class SessionStore {
    private(set) var current: DeviceSession?

    private let service: BleService
    private let log: DeviceLog

    init(service: BleService, log: DeviceLog) {
        self.service = service
        self.log = log
    }

    /// Returns the session for this device, connecting a new one if needed.
    func open(remoteId: String, name: String) -> DeviceSession {
        if let current, current.remoteId == remoteId {
            if case .disconnected = current.status { Task { await current.connect() } }
            return current
        }
        if let old = current {
            Task { await old.disconnect() }
        }
        let session = DeviceSession(remoteId: remoteId, name: name, service: service, log: log)
        current = session
        Task { await session.connect() }
        return session
    }

    /// Disconnects and forgets the current device.
    func disconnect() async {
        guard let session = current else { return }
        current = nil
        await session.disconnect()
    }
}
