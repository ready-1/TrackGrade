import SwiftUI
import UIKit

enum PresetsFeatureStyle {
    case card
    case drawer
}

struct PresetsFeatureView: View {
    @Bindable var model: TrackGradeAppModel
    let device: ManagedColorBoxDevice
    let style: PresetsFeatureStyle

    @State private var activeEditorRequest: PresetEditorRequest?
    @State private var pendingRecallPreset: ColorBoxPresetSummary?
    @State private var pendingDeletionPreset: ColorBoxPresetSummary?

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
        .sheet(item: $activeEditorRequest) { request in
            SavePresetSheet(
                deviceName: device.name,
                request: request,
                onSave: { mode, slot, name in
                    Task {
                        switch mode {
                        case .save, .overwrite:
                            await model.savePreset(
                                id: device.id,
                                slot: slot,
                                name: name
                            )
                        case .rename:
                            await model.renamePreset(
                                id: device.id,
                                slot: slot,
                                name: name
                            )
                        }
                    }
                }
            )
        }
        .confirmationDialog(
            pendingRecallPreset == nil ? "Recall Preset" : "Recall \(pendingRecallPreset?.name ?? "Preset")?",
            isPresented: Binding(
                get: { pendingRecallPreset != nil },
                set: { isPresented in
                    if isPresented == false {
                        pendingRecallPreset = nil
                    }
                }
            ),
            presenting: pendingRecallPreset
        ) { preset in
            Button("Recall Slot \(preset.slot)") {
                Task {
                    await model.recallPreset(
                        id: device.id,
                        slot: preset.slot
                    )
                }
                pendingRecallPreset = nil
            }
            Button("Cancel", role: .cancel) {
                pendingRecallPreset = nil
            }
        } message: { preset in
            Text("Apply \(preset.name) from slot \(preset.slot) on the ColorBox?")
        }
        .confirmationDialog(
            pendingDeletionPreset == nil ? "Delete Preset" : "Delete \(pendingDeletionPreset?.name ?? "Preset")?",
            isPresented: Binding(
                get: { pendingDeletionPreset != nil },
                set: { isPresented in
                    if isPresented == false {
                        pendingDeletionPreset = nil
                    }
                }
            ),
            presenting: pendingDeletionPreset
        ) { preset in
            Button("Delete Slot \(preset.slot)", role: .destructive) {
                Task {
                    await model.deletePreset(
                        id: device.id,
                        slot: preset.slot
                    )
                }
                pendingDeletionPreset = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeletionPreset = nil
            }
        } message: { preset in
            Text("Remove \(preset.name) from slot \(preset.slot) on the ColorBox?")
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
            VStack(alignment: .leading, spacing: 2) {
                Text("Presets")
                    .font(style == .card ? .title3.weight(.bold) : .headline.weight(.semibold))
                    .foregroundStyle(foregroundStyle)

                Text("Tap to recall with confirmation. Long-press a tile to rename or overwrite.")
                    .font(.caption)
                    .foregroundStyle(style == .drawer ? Color.white.opacity(0.58) : .secondary)
            }

            Spacer()

            Button("Save Preset") {
                activeEditorRequest = defaultSaveRequest
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
            PresetThumbnailView(
                imageData: model.presetThumbnailData(for: device.id, slot: preset.slot),
                cornerRadius: 18
            )
            .frame(height: 82)
            .accessibilityIdentifier("preset-slot-\(preset.slot)-thumbnail")

            Text("Slot \(preset.slot)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(preset.name)
                .font(.headline)
                .lineLimit(2)

            HStack(spacing: 10) {
                recallButton(for: preset)
                actionsMenu(for: preset)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
        )
        .contextMenu {
            presetContextMenu(for: preset)
        }
        .accessibilityIdentifier("preset-slot-\(preset.slot)")
    }

    private func drawerPresetTile(
        for preset: ColorBoxPresetSummary
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            PresetThumbnailView(
                imageData: model.presetThumbnailData(for: device.id, slot: preset.slot),
                cornerRadius: 14
            )
            .frame(height: 68)
            .accessibilityIdentifier("preset-slot-\(preset.slot)-thumbnail")

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
                actionsMenu(for: preset)
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
        .contextMenu {
            presetContextMenu(for: preset)
        }
        .accessibilityIdentifier("preset-slot-\(preset.slot)")
    }

    private func recallButton(
        for preset: ColorBoxPresetSummary
    ) -> some View {
        Button("Recall") {
            pendingRecallPreset = preset
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier("preset-slot-\(preset.slot)-recall")
    }

    private func actionsMenu(
        for preset: ColorBoxPresetSummary
    ) -> some View {
        Menu {
            presetContextMenu(for: preset)
        } label: {
            Label("Actions", systemImage: "ellipsis.circle")
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("preset-slot-\(preset.slot)-actions")
    }

    @ViewBuilder
    private func presetContextMenu(
        for preset: ColorBoxPresetSummary
    ) -> some View {
        Button("Rename") {
            activeEditorRequest = renameRequest(for: preset)
        }

        Button("Overwrite From Current Grade") {
            activeEditorRequest = overwriteRequest(for: preset)
        }

        Button("Delete", role: .destructive) {
            pendingDeletionPreset = preset
        }
    }

    private var defaultSaveRequest: PresetEditorRequest {
        let slot = nextAvailableSlot
        return PresetEditorRequest(
            mode: .save,
            slot: slot,
            name: "TrackGrade Preset \(slot)",
            previewFrameData: device.previewFrameData
        )
    }

    private func renameRequest(
        for preset: ColorBoxPresetSummary
    ) -> PresetEditorRequest {
        PresetEditorRequest(
            mode: .rename,
            slot: preset.slot,
            name: preset.name,
            previewFrameData: model.presetThumbnailData(for: device.id, slot: preset.slot)
        )
    }

    private func overwriteRequest(
        for preset: ColorBoxPresetSummary
    ) -> PresetEditorRequest {
        PresetEditorRequest(
            mode: .overwrite,
            slot: preset.slot,
            name: preset.name,
            previewFrameData: device.previewFrameData ?? model.presetThumbnailData(for: device.id, slot: preset.slot)
        )
    }

    private var nextAvailableSlot: Int {
        let usedSlots = Set(device.presets.map(\.slot))
        return (1 ... 10).first(where: { usedSlots.contains($0) == false }) ?? 1
    }
}

private struct PresetEditorRequest: Identifiable {
    enum Mode: String {
        case save
        case rename
        case overwrite
    }

    let mode: Mode
    let slot: Int
    let name: String
    let previewFrameData: Data?

    var id: String {
        "\(mode.rawValue)-\(slot)"
    }

    var title: String {
        switch mode {
        case .save:
            return "Save Preset"
        case .rename:
            return "Rename Preset"
        case .overwrite:
            return "Overwrite Preset"
        }
    }

    var actionTitle: String {
        switch mode {
        case .save:
            return "Save"
        case .rename:
            return "Rename"
        case .overwrite:
            return "Overwrite"
        }
    }

    var allowsSlotEditing: Bool {
        mode == .save
    }

    var helperText: String {
        switch mode {
        case .save:
            return "Store the current dynamic grade on the ColorBox."
        case .rename:
            return "Update the user-visible preset name on the ColorBox."
        case .overwrite:
            return "Replace the ColorBox preset slot with the current grade and thumbnail."
        }
    }
}

private struct SavePresetSheet: View {
    @Environment(\.dismiss) private var dismiss

    let deviceName: String
    let request: PresetEditorRequest
    let onSave: (PresetEditorRequest.Mode, Int, String) -> Void

    @State private var slot: Int
    @State private var name: String

    init(
        deviceName: String,
        request: PresetEditorRequest,
        onSave: @escaping (PresetEditorRequest.Mode, Int, String) -> Void
    ) {
        self.deviceName = deviceName
        self.request = request
        self.onSave = onSave
        _slot = State(initialValue: request.slot)
        _name = State(initialValue: request.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(request.title) {
                    if request.allowsSlotEditing {
                        Stepper(value: $slot, in: 1 ... 10) {
                            Text("Slot \(slot)")
                        }
                    } else {
                        LabeledContent("Slot", value: "\(slot)")
                    }

                    TextField("Preset name", text: $name)
                        .accessibilityIdentifier("preset-name-field")
                }

                Section("Preview") {
                    PresetThumbnailView(
                        imageData: request.previewFrameData,
                        cornerRadius: 18
                    )
                    .frame(height: 112)

                    Text(request.helperText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(request.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(request.actionTitle) {
                        let resolvedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(
                            request.mode,
                            slot,
                            resolvedName.isEmpty ? "TrackGrade Preset \(slot)" : resolvedName
                        )
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct PresetThumbnailView: View {
    let imageData: Data?
    let cornerRadius: CGFloat

    var body: some View {
        Group {
            if let imageData,
               let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.orange.opacity(0.22),
                                    Color.white.opacity(0.08),
                                    Color.blue.opacity(0.18),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    VStack(spacing: 6) {
                        Image(systemName: "photo")
                            .font(.title3.weight(.semibold))
                        Text("No thumbnail")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white.opacity(0.82))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }
}
