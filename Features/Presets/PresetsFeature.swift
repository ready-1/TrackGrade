import SwiftUI

enum PresetsFeatureStyle {
    case card
    case drawer
}

struct PresetsFeatureView: View {
    @Bindable var model: TrackGradeAppModel
    let device: ManagedColorBoxDevice
    let style: PresetsFeatureStyle

    @State private var isShowingSaveSheet = false

    private let cardColumns = [
        GridItem(.adaptive(minimum: 150), spacing: 12)
    ]

    init(
        model: TrackGradeAppModel,
        device: ManagedColorBoxDevice,
        style: PresetsFeatureStyle = .card
    ) {
        self.model = model
        self.device = device
        self.style = style
    }

    var body: some View {
        Group {
            switch style {
            case .card:
                cardContent
            case .drawer:
                drawerContent
            }
        }
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

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            header(foregroundStyle: .primary)

            if device.presets.isEmpty {
                Text("No device presets were returned yet.")
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: cardColumns, alignment: .leading, spacing: 12) {
                    ForEach(device.presets) { preset in
                        cardPresetTile(for: preset)
                    }
                }
            }
        }
        .cardStyle()
    }

    private var drawerContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            header(foregroundStyle: .white)

            if device.presets.isEmpty {
                Text("No device presets were returned yet.")
                    .font(.footnote)
                    .foregroundStyle(Color.white.opacity(0.68))
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                    ],
                    spacing: 10
                ) {
                    ForEach(device.presets) { preset in
                        drawerPresetTile(for: preset)
                    }
                }
            }
        }
        .padding(16)
        .surfacePanelStyle(cornerRadius: 24)
    }

    private func header(foregroundStyle: Color) -> some View {
        HStack {
            Text("Presets")
                .font(style == .card ? .title3.weight(.bold) : .headline.weight(.semibold))
                .foregroundStyle(foregroundStyle)

            Spacer()

            Button("Save Preset") {
                isShowingSaveSheet = true
            }
            .buttonStyle(.borderedProminent)
            .tint(style == .drawer ? .orange : .accentColor)
            .accessibilityIdentifier("save-preset-button")
        }
    }

    private func cardPresetTile(
        for preset: ColorBoxPresetSummary
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Slot \(preset.slot)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(preset.name)
                .font(.headline)

            HStack(spacing: 10) {
                recallButton(for: preset)
                deleteButton(for: preset, iconOnly: false)
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

    private func drawerPresetTile(
        for preset: ColorBoxPresetSummary
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Slot \(preset.slot)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.62))

            Text(preset.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                recallButton(for: preset)
                    .tint(.orange)
                deleteButton(for: preset, iconOnly: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
        .accessibilityIdentifier("preset-slot-\(preset.slot)")
    }

    private func recallButton(
        for preset: ColorBoxPresetSummary
    ) -> some View {
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
    }

    private func deleteButton(
        for preset: ColorBoxPresetSummary,
        iconOnly: Bool
    ) -> some View {
        Group {
            if iconOnly {
                Button(role: .destructive) {
                    Task {
                        await model.deletePreset(
                            id: device.id,
                            slot: preset.slot
                        )
                    }
                } label: {
                    Image(systemName: "trash")
                }
            } else {
                Button("Delete", role: .destructive) {
                    Task {
                        await model.deletePreset(
                            id: device.id,
                            slot: preset.slot
                        )
                    }
                }
            }
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("preset-slot-\(preset.slot)-delete")
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
