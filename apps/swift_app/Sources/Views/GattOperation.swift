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
        case .read: Color(hex: 0x007AFF)
        case .write: Color(hex: 0xAF52DE)
        case .writeWithoutResponse: Color(hex: 0x5856D6)
        case .notify: Color(hex: 0x34C759)
        case .indicate: Color(hex: 0x30B0C7)
        }
    }

    var isSubscription: Bool { self == .notify || self == .indicate }

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
    let state: CharacteristicState
    let operation: GattOperation
    let id: String

    @MainActor init(state: CharacteristicState, operation: GattOperation) {
        self.state = state
        self.operation = operation
        id = "\(state.ref.service)/\(state.ref.characteristic)/\(operation)"
    }
}

@MainActor
extension ServiceGroup {
    /// Characteristics in discovery order, then operations read → write → write without response → notify → indicate.
    var rows: [OperationRow] {
        characteristics.flatMap { state in
            GattOperation.allCases
                .filter { $0.isSupported(by: state.properties) }
                .map { OperationRow(state: state, operation: $0) }
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

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255)
    }
}
