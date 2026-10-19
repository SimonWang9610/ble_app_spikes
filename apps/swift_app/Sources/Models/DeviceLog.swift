import Foundation
import Observation

struct LogEntry: Identifiable {
    enum Kind { case event, value, error, api }

    let id: Int
    let time: Date
    let kind: Kind
    let text: String
}

/// What happened to the device, in plain words ("Link lost", "NOTIFY received 42").
/// Raw binding calls are kept too, but only shown when "API calls" is switched on.
@MainActor
@Observable
final class DeviceLog {
    private static let limit = 500

    private(set) var entries: [LogEntry] = []
    var showApiCalls = false
    @ObservationIgnored private var nextId = 0

    var visible: [LogEntry] {
        showApiCalls ? entries : entries.filter { $0.kind != .api }
    }

    func event(_ text: String) { add(.event, text) }
    func value(_ text: String) { add(.value, text) }
    func error(_ text: String) { add(.error, text) }

    /// Runs one binding call and logs it as an API line.
    func api<T>(_ call: String, _ body: () async throws -> T) async throws -> T {
        add(.api, call)
        do {
            let result = try await body()
            add(.api, "\(call) ok")
            return result
        } catch {
            add(.api, "\(call) ✗ \(describe(error))")
            throw error
        }
    }

    func clear() {
        entries.removeAll()
    }

    private func add(_ kind: LogEntry.Kind, _ text: String) {
        entries.append(LogEntry(id: nextId, time: .now, kind: kind, text: text))
        nextId += 1
        if entries.count > Self.limit { entries.removeFirst(entries.count - Self.limit) }
    }
}
