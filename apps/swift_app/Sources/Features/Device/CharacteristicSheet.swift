import SwiftUI

/// The dialog for one operation of a characteristic.
struct CharacteristicSheet: View {
    let characteristic: Characteristic
    let operation: GattOperation
    let session: DeviceSession
    @Environment(\.dismiss) private var dismiss
    // The write form and how this dialog's last write went: view state, not in the model.
    @State private var input = ""
    @State private var format = ValueFormat.hex
    @State private var lastWrite: WriteResult?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(characteristic.ref.characteristic).font(.caption.monospaced()).foregroundStyle(.secondary)
                    LabeledContent("Service", value: Fixture.label(characteristic.ref.service))
                }

                switch operation {
                case .read: readSection
                case .write: writeSection(withoutResponse: false)
                case .writeWithoutResponse: writeSection(withoutResponse: true)
                case .notify, .indicate: subscribeSection
                }

                if let busy = characteristic.busy {
                    Section { Label(busy, systemImage: "hourglass") }
                }
                // A write's error shows under its Write button instead.
                if !operation.isWrite, let error = characteristic.error {
                    Section { Text(error).foregroundStyle(.red).font(.callout).textSelection(.enabled) }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .disabled(!session.connection.isConnected)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        if let name = Fixture.knownName(characteristic.ref.characteristic) {
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
            if let value = characteristic.latest, let time = characteristic.latestTime, let source = characteristic.latestSource {
                Text(characteristic.show(value)).font(.body.monospaced()).textSelection(.enabled)
                Text("\(source.rawValue) at \(time, format: Date.FormatStyle(date: .omitted, time: .standard))")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("No value yet").foregroundStyle(.secondary)
            }
            Button("Read") { Task { await characteristic.read() } }
        }
    }

    private func writeSection(withoutResponse: Bool) -> some View {
        Section("Value") {
            Picker("Format", selection: $format) {
                ForEach(ValueFormat.allCases) { Text($0 == .hex ? "hex" : "text").tag($0) }
            }
            .pickerStyle(.segmented)
            TextField(format == .hex ? "01 02 0a" : "text", text: $input)
                .font(.body.monospaced())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Write") { Task { await write(withoutResponse: withoutResponse) } }
                .disabled(input.isEmpty || characteristic.busy != nil)
            if let lastWrite {
                Text(lastWrite.text)
                    .font(.callout)
                    .foregroundStyle(lastWrite.failed ? .red : .green)
                    .textSelection(.enabled)
            }
        }
    }

    private var subscribeSection: some View {
        Section {
            LabeledContent("Subscribed", value: characteristic.subscribed ? "on" : "off")
            LabeledContent("Received", value: "\(characteristic.receivedCount)")
            if let value = characteristic.latest, characteristic.latestSource == .received, let time = characteristic.latestTime {
                VStack(alignment: .leading, spacing: 3) {
                    Text(characteristic.show(value)).font(.body.monospaced()).textSelection(.enabled)
                    Text("received at \(time, format: Date.FormatStyle(date: .omitted, time: .standard))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text("Nothing received yet").foregroundStyle(.secondary)
            }
            if characteristic.subscribed {
                Button("Unsubscribe", role: .destructive) { Task { await session.subscriptions.set(characteristic, false) } }
            } else {
                Button("Subscribe") { Task { await session.subscriptions.set(characteristic, true) } }
            }
        } footer: {
            Text("Stays on when you leave the device; ends on Unsubscribe or Disconnect.")
        }
    }

    private func write(withoutResponse: Bool) async {
        do {
            let value = try Data(input, format: format)
            try await characteristic.write(value, withoutResponse: withoutResponse)
            let time = Date.now.formatted(Date.ISO8601FormatStyle(timeZone: .current).time(includingFractionalSeconds: false))
            let shown = characteristic.show(value)
            lastWrite = WriteResult(
                text: withoutResponse ? "Sent \(time) · \(shown) (no acknowledgement)" : "✓ Acknowledged \(time) · \(shown)",
                failed: false)
        } catch is CancellationError {
            // Disconnect began; nothing to report.
        } catch {
            lastWrite = WriteResult(text: describe(error), failed: true)
        }
    }
}

private struct WriteResult {
    let text: String
    let failed: Bool
}

#if DEBUG
#Preview("Write") {
    let models = PreviewModels()
    let characteristic = Characteristic(
        ref: FakeBle.value,
        properties: .init(read: true, write: true, writeWithoutResponse: true, notify: false, indicate: false),
        io: models.ble, log: models.log)
    CharacteristicSheet(characteristic: characteristic, operation: .write, session: models.session())
        .environment(models)
}
#endif
