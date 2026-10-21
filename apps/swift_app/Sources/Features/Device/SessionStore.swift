import Observation

/// Holds the device the app is connected to. One at a time; lives as long as the app.
@MainActor
@Observable
final class SessionStore {
    private(set) var current: DeviceSession?

    private let ble: any DeviceLink & GattIO
    private let log: Log

    init(ble: any DeviceLink & GattIO, log: Log) {
        self.ble = ble
        self.log = log
    }

    /// Returns the session for this device, connecting a new one if needed.
    @discardableResult
    func open(remoteId: String, name: String) -> DeviceSession {
        if let current, current.remoteId == remoteId {
            if case .disconnected = current.connection.status { Task { await current.connect() } }
            return current
        }
        let old = current
        let session = DeviceSession(remoteId: remoteId, name: name, ble: ble, log: log)
        current = session
        // The old device finishes disconnecting before the new one connects, so the two never overlap.
        Task {
            await old?.disconnect()
            await session.connect()
        }
        return session
    }

    /// Disconnects and forgets the current device.
    func disconnect() async {
        guard let session = current else { return }
        current = nil
        await session.disconnect()
    }
}
