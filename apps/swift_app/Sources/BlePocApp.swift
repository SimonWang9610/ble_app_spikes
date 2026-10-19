import SwiftUI

@main
struct BlePocApp: App {
    // App-wide state, created once. `@State` keeps the same instances across body re-evaluations.
    @State private var log: DeviceLog
    @State private var adapter: AdapterModel
    @State private var nearby: NearbyModel
    @State private var sessions: SessionStore

    init() {
        let service = BleService()
        let log = DeviceLog()
        _log = State(initialValue: log)
        _adapter = State(initialValue: AdapterModel(service: service, log: log))
        _nearby = State(initialValue: NearbyModel(service: service, log: log))
        _sessions = State(initialValue: SessionStore(service: service, log: log))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(log)
                .environment(adapter)
                .environment(nearby)
                .environment(sessions)
        }
    }
}
