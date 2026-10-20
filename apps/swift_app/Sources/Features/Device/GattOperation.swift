import BlePocSwift
import SwiftUI

/// One thing a characteristic can do; each gets its own row and dialog.
enum GattOperation: CaseIterable {
    case read, write, writeWithoutResponse, notify, indicate

    var label: String {
        switch self {
        case .read: "read"
        case .write: "write"
        case .writeWithoutResponse: "write without response"
        case .notify: "notify"
        case .indicate: "indicate"
        }
    }

    var color: Color {
        switch self {
        case .read: .blue
        case .write: .purple
        case .writeWithoutResponse: .indigo
        case .notify: .green
        case .indicate: .teal
        }
    }

    var isSubscription: Bool { self == .notify || self == .indicate }
    var isWrite: Bool { self == .write || self == .writeWithoutResponse }

    func isSupported(by properties: CharacteristicProperties) -> Bool {
        switch self {
        case .read: properties.read
        case .write: properties.write
        case .writeWithoutResponse: properties.writeWithoutResponse
        case .notify: properties.notify
        case .indicate: properties.indicate
        }
    }
}

/// A (characteristic, operation) pair: one row in the device screen and the dialog it opens.
struct OperationRow: Identifiable {
    let characteristic: Characteristic
    let operation: GattOperation
    let id: String

    @MainActor init(characteristic: Characteristic, operation: GattOperation) {
        self.characteristic = characteristic
        self.operation = operation
        id = "\(characteristic.ref.service)/\(characteristic.ref.characteristic)/\(operation)"
    }
}

@MainActor
extension ServiceGroup {
    /// Characteristics in discovery order, then operations read → write → write without response → notify → indicate.
    var rows: [OperationRow] {
        characteristics.flatMap { characteristic in
            GattOperation.allCases
                .filter { $0.isSupported(by: characteristic.properties) }
                .map { OperationRow(characteristic: characteristic, operation: $0) }
        }
    }
}

/// Colored label on a light tint of the same color.
struct OperationChip: View {
    let operation: GattOperation

    var body: some View {
        Text(operation.label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(operation.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(operation.color.opacity(0.15), in: Capsule())
    }
}
