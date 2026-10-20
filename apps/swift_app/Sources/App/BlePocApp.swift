import SwiftUI

@main
struct BlePocApp: App {
    // App-wide state, created once. `@State` keeps the same instances across body re-evaluations.
    @State private var adapter: AdapterModel
    @State private var nearby: NearbyModel
    @State private var sessions: SessionStore

    init() {
        // One service behind every BLE interface; each model gets only the one it uses.
        let ble = BleService()
        _adapter = State(initialValue: AdapterModel(adapter: ble))
        _nearby = State(initialValue: NearbyModel(adapter: ble))
        _sessions = State(initialValue: SessionStore(ble: ble))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(adapter)
                .environment(nearby)
                .environment(sessions)
        }
    }
}
