import SwiftUI

/// The dialog for one operation of a characteristic.
struct CharacteristicSheet: View {
    @Bindable var state: CharacteristicState
    let operation: GattOperation
    let session: DeviceSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(state.ref.characteristic).font(.caption.monospaced()).foregroundStyle(.secondary)
                    LabeledContent("Service", value: Fixture.label(state.ref.service))
                }

                switch operation {
                case .read: readSection
                case .write: writeSection(withoutResponse: false)
                case .writeWithoutResponse: writeSection(withoutResponse: true)
                case .notify, .indicate: subscribeSection
                }

                if let busy = state.busy {
                    Section { Label(busy, systemImage: "hourglass") }
                }
                if let error = state.error {
                    Section { Text(error).foregroundStyle(.red).font(.callout).textSelection(.enabled) }
                }
            }
            .disabled(!session.isConnected)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        if let name = Fixture.knownName(state.ref.characteristic) {
                            Text(name).font(.headline)
                        }
                        OperationChip(operation: operation)
                    }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private var readSection: some View {
        Section("Latest") {
            if let value = state.latest, let time = state.latestTime, let source = state.latestSource {
                Text(state.show(value)).font(.body.monospaced()).textSelection(.enabled)
                Text("\(source.rawValue) at \(time.formatted(date: .omitted, time: .standard))")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("No value yet").foregroundStyle(.secondary)
            }
            Button("Read") { Task { await session.read(state) } }
        }
    }

    private func writeSection(withoutResponse: Bool) -> some View {
        Section("Value") {
            Picker("Format", selection: $state.inputFormat) {
                ForEach(ValueFormat.allCases) { Text($0 == .hex ? "hex" : "text").tag($0) }
            }
            .pickerStyle(.segmented)
            TextField(state.inputFormat == .hex ? "01 02 0a" : "text", text: $state.input)
                .font(.body.monospaced())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Write") { Task { await session.write(state, withoutResponse: withoutResponse) } }
                .disabled(state.input.isEmpty)
        }
    }

    private var subscribeSection: some View {
        Section {
            LabeledContent("Subscribed", value: state.subscribed ? "on" : "off")
            LabeledContent("Received", value: "\(state.receivedCount)")
            if let value = state.latest, state.latestSource == .received, let time = state.latestTime {
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.show(value)).font(.body.monospaced()).textSelection(.enabled)
                    Text("received at \(time.formatted(date: .omitted, time: .standard))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text("Nothing received yet").foregroundStyle(.secondary)
            }
            if state.subscribed {
                Button("Unsubscribe", role: .destructive) { Task { await session.setSubscribed(state, false) } }
            } else {
                Button("Subscribe") { Task { await session.setSubscribed(state, true) } }
            }
        } footer: {
            Text("Stays on when you leave the device; ends on Unsubscribe or Disconnect.")
        }
    }
}
