#if DEBUG
import SwiftUI

/// The app's models on a `FakeBle`, for previews.
@MainActor
struct PreviewModels {
    let ble = FakeBle()
    let log = Log()
    let adapter: AdapterModel
    let nearby: NearbyModel
    let sessions: SessionStore

    init() {
        adapter = AdapterModel(adapter: ble, log: log)
        nearby = NearbyModel(adapter: ble, log: log)
        sessions = SessionStore(ble: ble, log: log)
    }

    /// A session to the fake device; it connects right after the preview appears.
    func session() -> DeviceSession {
        sessions.open(remoteId: FakeBle.deviceId, name: Fixture.name)
    }
}

extension View {
    func environment(_ models: PreviewModels) -> some View {
        environment(models.log)
            .environment(models.adapter)
            .environment(models.nearby)
            .environment(models.sessions)
    }
}
#endif
