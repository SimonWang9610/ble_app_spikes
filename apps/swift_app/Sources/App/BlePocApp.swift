import SwiftUI

@main
struct BlePocApp: App {
    // App-wide state, created once. `@State` keeps the same instances across body re-evaluations.
    @State private var log: Log
    @State private var adapter: AdapterModel
    @State private var nearby: NearbyModel
    @State private var sessions: SessionStore

    init() {
        // One service behind every BLE interface; each model gets only the one it uses.
        let ble = BleService()
        let log = Log()
        _log = State(initialValue: log)
        _adapter = State(initialValue: AdapterModel(adapter: ble, log: log))
        _nearby = State(initialValue: NearbyModel(adapter: ble, log: log))
        _sessions = State(initialValue: SessionStore(ble: ble, log: log))
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
