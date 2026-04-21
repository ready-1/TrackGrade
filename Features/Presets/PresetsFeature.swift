import SwiftUI

struct PresetsFeatureView: View {
    @Bindable var model: TrackGradeAppModel
    let device: ManagedColorBoxDevice

    @State private var isShowingSaveSheet = false

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Presets")
                    .font(.title3.weight(.bold))

                Spacer()

                Button("Save Preset") {
                    isShowingSaveSheet = true
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("save-preset-button")
            }

            if device.presets.isEmpty {
                Text("No device presets were returned yet.")
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(device.presets) { preset in
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Slot \(preset.slot)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(preset.name)
                                .font(.headline)
                            HStack(spacing: 10) {
                                Button("Recall") {
                                    Task {
                                        await model.recallPreset(
                                            id: device.id,
                                            slot: preset.slot
                                        )
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("preset-slot-\(preset.slot)-recall")

                                Button("Delete", role: .destructive) {
                                    Task {
                                        await model.deletePreset(
                                            id: device.id,
                                            slot: preset.slot
                                        )
                                    }
                                }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("preset-slot-\(preset.slot)-delete")
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                        )
                        .accessibilityIdentifier("preset-slot-\(preset.slot)")
                    }
                }
            }
        }
        .cardStyle()
        .sheet(isPresented: $isShowingSaveSheet) {
            SavePresetSheet(
                deviceName: device.name,
                onSave: { slot, name in
                    Task {
                        await model.savePreset(
                            id: device.id,
                            slot: slot,
                            name: name
                        )
                    }
                }
            )
        }
    }
}

private struct SavePresetSheet: View {
    @Environment(\.dismiss) private var dismiss

    let deviceName: String
    let onSave: (Int, String) -> Void

    @State private var slot = 1
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Save preset for \(deviceName)") {
                    Stepper(value: $slot, in: 1 ... 10) {
                        Text("Slot \(slot)")
                    }
                    TextField("Preset name", text: $name)
                        .accessibilityIdentifier("preset-name-field")
                }
            }
            .navigationTitle("Save Preset")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(slot, name.isEmpty ? "TrackGrade Preset \(slot)" : name)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
