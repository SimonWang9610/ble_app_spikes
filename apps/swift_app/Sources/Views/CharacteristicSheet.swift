import SwiftUI

/// The dialog for one characteristic: only the actions its properties allow.
struct CharacteristicSheet: View {
    @Bindable var state: CharacteristicState
    let session: DeviceSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(state.ref.characteristic).font(.caption.monospaced()).foregroundStyle(.secondary)
                    LabeledContent("Service", value: Fixture.label(state.ref.service))
                    LabeledContent("Properties", value: state.properties.summary)
                }

                Section("Latest") {
                    if let value = state.latest, let time = state.latestTime, let source = state.latestSource {
                        Text(state.show(value)).font(.body.monospaced()).textSelection(.enabled)
                        Text("\(source.rawValue) at \(time.formatted(date: .omitted, time: .standard))"
                             + (state.receivedCount > 0 ? ", \(state.receivedCount) received" : ""))
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("No value yet").foregroundStyle(.secondary)
                    }
                }

                if state.properties.read {
                    Section {
                        Button("Read") { Task { await session.read(state) } }
                    }
                }

                if state.canWrite {
                    Section("Write") {
                        Picker("Format", selection: $state.inputFormat) {
                            ForEach(ValueFormat.allCases) { Text($0 == .hex ? "hex" : "text").tag($0) }
                        }
                        .pickerStyle(.segmented)
                        TextField(state.inputFormat == .hex ? "01 02 0a" : "text", text: $state.input)
                            .font(.body.monospaced())
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if state.properties.write && state.properties.writeWithoutResponse {
                            Toggle("Without response", isOn: $state.withoutResponse)
                        }
                        Button("Write") { Task { await session.write(state) } }
                            .disabled(state.input.isEmpty)
                    }
                }

                if state.canSubscribe {
                    Section {
                        if state.subscribed {
                            Button("Unsubscribe", role: .destructive) { Task { await session.setSubscribed(state, false) } }
                        } else {
                            Button("Subscribe") { Task { await session.setSubscribed(state, true) } }
                        }
                    } footer: {
                        Text("Stays on when you leave the device; ends on Unsubscribe or Disconnect.")
                    }
                }

                if let busy = state.busy {
                    Section { Label(busy, systemImage: "hourglass") }
                }
                if let error = state.error {
                    Section { Text(error).foregroundStyle(.red).font(.callout).textSelection(.enabled) }
                }
            }
            .disabled(!session.isConnected)
            .navigationTitle(state.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}
