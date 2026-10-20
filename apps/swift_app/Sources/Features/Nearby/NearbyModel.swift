import BlePocSwift
import Foundation
import Observation

/// Nearby devices: scans while the Nearby screen is visible.
@MainActor
@Observable
final class NearbyModel {
    var onlyFixtures = true
    private(set) var results: [ScanResult] = []
    private(set) var isScanning = false
    private(set) var error: String?

    private let adapter: any BleAdapter
    private let log: Log
    // Which scan is current; a cancelled scan must not stop the one that replaced it.
    @ObservationIgnored private var generation = 0

    init(adapter: any BleAdapter, log: Log) {
        self.adapter = adapter
        self.log = log
    }

    /// Scans until the calling task is cancelled (the screen went away or the filter changed).
    func scan() async {
        let names = onlyFixtures ? [Fixture.name] : []
        generation += 1
        let mine = generation
        results = []
        error = nil
        do {
            let stream = try await adapter.scanResults()
            try await log.api("startScan(withNames: \(names))") { try await adapter.startScan(names: names) }
            isScanning = true
            for await list in stream {
                results = list.sorted { $0.rssi > $1.rssi }
            }
        } catch {
            self.error = describe(error)
            log.error("Scan failed: \(describe(error))")
        }
        guard mine == generation else { return }
        isScanning = false
        // This task is being cancelled, so stop the scan from a task of its own,
        // unless a new scan has started by then.
        Task { [adapter] in
            guard mine == generation else { return }
            try? await adapter.stopScan()
        }
    }
}
