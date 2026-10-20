import BlePocSwift
import Foundation
import Observation

struct ServiceGroup: Identifiable {
    let uuid: String
    let characteristics: [Characteristic]
    var id: String { uuid }
}

/// What the device offers, as one tile per service. Keeps the characteristic objects across
/// rediscovery, so values and subscriptions survive a reconnect.
@MainActor
@Observable
final class Gatt {
    private(set) var services: [ServiceGroup] = []

    private let remoteId: String
    private let link: any DeviceLink
    private let log: Log
    private let make: (CharacteristicRef, CharacteristicProperties) -> Characteristic
    @ObservationIgnored private var characteristics: [CharacteristicRef: Characteristic] = [:]

    /// `make` builds a characteristic model the first time discovery finds it.
    init(remoteId: String, link: any DeviceLink, log: Log,
         make: @escaping (CharacteristicRef, CharacteristicProperties) -> Characteristic) {
        self.remoteId = remoteId
        self.link = link
        self.log = log
        self.make = make
    }

    func discover() async throws -> [BluetoothService] {
        try await log.api("discoverServices()") { try await link.discoverServices(remoteId) }
    }

    /// Shows the fixture services. Fails if a subscribed characteristic is gone, so a reconnect
    /// doesn't count as done.
    func apply(_ all: [BluetoothService]) throws {
        let found = Fixture.services(of: all)
        let refs = Set(found.flatMap { group in group.characteristics.map { ref(group, $0) } })
        let missing = characteristics.values
            .filter { $0.subscribed && !refs.contains($0.ref) }
            .map(\.name).sorted()
        if !missing.isEmpty {
            throw MissingCharacteristics(names: missing)
        }
        services = found.map { group in
            ServiceGroup(uuid: group.serviceUuid, characteristics: group.characteristics.map { model(group, $0) })
        }
        let count = found.reduce(0) { $0 + $1.characteristics.count }
        let hidden = all.count - found.count
        log.event("Found \(found.count) services, \(count) characteristics"
                  + (hidden == 0 ? "" : " (\(hidden) non-fixture services hidden)"))
    }

    func characteristic(_ ref: CharacteristicRef) -> Characteristic? {
        characteristics[ref]
    }

    /// Drops every characteristic model; the next connect starts from scratch.
    func clear() {
        services = []
        characteristics.removeAll()
    }

    private func ref(_ group: BluetoothService, _ info: CharacteristicInfo) -> CharacteristicRef {
        CharacteristicRef(remoteId: remoteId, service: group.serviceUuid, characteristic: info.characteristicUuid)
    }

    private func model(_ group: BluetoothService, _ info: CharacteristicInfo) -> Characteristic {
        let ref = ref(group, info)
        if let existing = characteristics[ref] { return existing }
        let created = make(ref, info.properties)
        characteristics[ref] = created
        return created
    }
}

private struct MissingCharacteristics: LocalizedError {
    let names: [String]
    var errorDescription: String? { "not found after discovery: \(names.joined(separator: ", "))" }
}
