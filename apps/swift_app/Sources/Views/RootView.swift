import SwiftUI

/// The navigation stack on top, the log panel always visible below it.
struct RootView: View {
    @Environment(AdapterModel.self) private var adapter
    @Environment(SessionStore.self) private var sessions
    // Navigation is view state: the stack of device ids on top of Nearby.
    @State private var path: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            NavigationStack(path: $path) {
                NearbyView(path: $path)
                    .navigationDestination(for: String.self) { remoteId in
                        if let session = sessions.current, session.remoteId == remoteId {
                            DeviceView(session: session)
                        } else {
                            ContentUnavailableView("Not connected", systemImage: "antenna.radiowaves.left.and.right.slash")
                        }
                    }
            }
            LogPanel()
        }
        // Lives as long as the root view, i.e. the app.
        .task { await adapter.observe() }
    }
}
