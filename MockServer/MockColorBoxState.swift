import Foundation
import TrackGradeCore

actor MockColorBoxState {
    private let configuration: MockColorBoxConfiguration
    private let systemInfoValue: ColorBoxSystemInfo
    private var firmwareInfoValue: ColorBoxFirmwareInfo
    private var pipelineStateValue: ColorBoxPipelineState
    private var presetStore: [Int: ColorBoxPresetSummary]
    private var presetPipelineStore: [Int: ColorBoxPipelineState]
    private var libraryControlValue: MockLibraryControlState
    private var previewPNGDataValue: Data
    private var lastUploadedLUT: Data

    init(configuration: MockColorBoxConfiguration) {
        self.configuration = configuration
        self.systemInfoValue = ColorBoxSystemInfo(
            productName: "AJA ColorBox",
            modelName: "ColorBox",
            serialNumber: "1SC001145",
            deviceUUID: UUID(uuidString: "11111111-2222-3333-4444-555555555555") ?? UUID(),
            hostName: "ColorBox-1SC001145"
        )
        self.firmwareInfoValue = ColorBoxFirmwareInfo(
            version: configuration.firmwareVersion,
            build: configuration.firmwareBuild
        )
        self.pipelineStateValue = ColorBoxPipelineState(
            bypassEnabled: false,
            falseColorEnabled: false,
            dynamicLUTMode: "static",
            lastRecalledPresetSlot: nil
        )
        self.presetStore = [
            1: ColorBoxPresetSummary(slot: 1, name: "Factory Neutral"),
            2: ColorBoxPresetSummary(slot: 2, name: "Corporate LED"),
        ]
        self.presetPipelineStore = [
            1: self.pipelineStateValue,
            2: self.pipelineStateValue,
        ]
        self.libraryControlValue = MockLibraryControlState(
            library: "systemPreset",
            entry: 0,
            action: "Idle",
            data: "",
            errorMessage: ""
        )
        self.previewPNGDataValue = Self.previewPNGData()
        self.lastUploadedLUT = Data()
    }

    func systemInfo() async throws -> ColorBoxSystemInfo {
        try await applyLatency()
        return systemInfoValue
    }

    func firmwareInfo() async throws -> ColorBoxFirmwareInfo {
        try await applyLatency()
        return firmwareInfoValue
    }

    func pipelineState() async throws -> ColorBoxPipelineState {
        try await applyLatency()
        return pipelineStateValue
    }

    func configureDynamicLUTNode(mode: String) async throws -> ColorBoxPipelineState {
        try await applyLatency()
        pipelineStateValue = ColorBoxPipelineState(
            bypassEnabled: pipelineStateValue.bypassEnabled,
            falseColorEnabled: pipelineStateValue.falseColorEnabled,
            dynamicLUTMode: mode,
            lastRecalledPresetSlot: pipelineStateValue.lastRecalledPresetSlot
        )
        return pipelineStateValue
    }

    func storeDynamicLUTUpload(
        data: Data,
        sequenceID: String?
    ) async throws -> ColorBoxDynamicLUTUploadResponse {
        try await applyLatency()
        lastUploadedLUT = data
        return ColorBoxDynamicLUTUploadResponse(
            accepted: true,
            byteCount: data.count,
            sequenceID: sequenceID
        )
    }

    func setBypass(_ enabled: Bool) async throws -> ColorBoxPipelineState {
        try await applyLatency()
        pipelineStateValue = ColorBoxPipelineState(
            bypassEnabled: enabled,
            falseColorEnabled: pipelineStateValue.falseColorEnabled,
            dynamicLUTMode: pipelineStateValue.dynamicLUTMode,
            lastRecalledPresetSlot: pipelineStateValue.lastRecalledPresetSlot
        )
        return pipelineStateValue
    }

    func setFalseColor(_ enabled: Bool) async throws -> ColorBoxPipelineState {
        try await applyLatency()
        pipelineStateValue = ColorBoxPipelineState(
            bypassEnabled: pipelineStateValue.bypassEnabled,
            falseColorEnabled: enabled,
            dynamicLUTMode: pipelineStateValue.dynamicLUTMode,
            lastRecalledPresetSlot: pipelineStateValue.lastRecalledPresetSlot
        )
        return pipelineStateValue
    }

    func presets() async throws -> [ColorBoxPresetSummary] {
        try await applyLatency()
        return presetStore.values.sorted { $0.slot < $1.slot }
    }

    func savePreset(slot: Int, name: String) async throws -> [ColorBoxPresetSummary] {
        try await applyLatency()
        presetStore[slot] = ColorBoxPresetSummary(slot: slot, name: name)
        presetPipelineStore[slot] = pipelineStateValue
        return presetStore.values.sorted { $0.slot < $1.slot }
    }

    func recallPreset(slot: Int) async throws -> ColorBoxPipelineState {
        try await applyLatency()
        pipelineStateValue = ColorBoxPipelineState(
            bypassEnabled: pipelineStateValue.bypassEnabled,
            falseColorEnabled: pipelineStateValue.falseColorEnabled,
            dynamicLUTMode: pipelineStateValue.dynamicLUTMode,
            lastRecalledPresetSlot: slot
        )
        return pipelineStateValue
    }

    func deletePreset(slot: Int) async throws -> [ColorBoxPresetSummary] {
        try await applyLatency()
        presetStore.removeValue(forKey: slot)
        presetPipelineStore.removeValue(forKey: slot)
        return presetStore.values.sorted { $0.slot < $1.slot }
    }

    func systemPresetLibraryEntries(slotCount: Int = 10) async throws -> [MockLibraryEntryState] {
        try await applyLatency()
        return (1 ... slotCount).map { slot in
            guard let preset = presetStore[slot] else {
                return MockLibraryEntryState(userName: nil, fileName: nil)
            }

            return MockLibraryEntryState(
                userName: preset.name,
                fileName: "\(preset.name).preset"
            )
        }
    }

    func libraryControl() async throws -> MockLibraryControlState {
        try await applyLatency()
        return libraryControlValue
    }

    func applyLibraryControl(
        library: String,
        entry: Int,
        action: String,
        data: String
    ) async throws {
        try await applyLatency()
        libraryControlValue = MockLibraryControlState(
            library: library,
            entry: entry,
            action: action,
            data: data,
            errorMessage: ""
        )

        guard library == "systemPreset" else {
            libraryControlValue = libraryControlValue.withError("Unsupported library in mock server.")
            return
        }

        switch action {
        case "StoreEntry":
            let existingName = presetStore[entry]?.name ?? "Preset \(entry)"
            presetStore[entry] = ColorBoxPresetSummary(slot: entry, name: existingName)
            presetPipelineStore[entry] = pipelineStateValue
        case "SetUserName":
            let normalizedName = data.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedName = normalizedName.isEmpty ? "Preset \(entry)" : normalizedName
            presetStore[entry] = ColorBoxPresetSummary(slot: entry, name: resolvedName)
        case "RecallEntry":
            guard let storedState = presetPipelineStore[entry] else {
                libraryControlValue = libraryControlValue.withError("Preset \(entry) does not exist in the mock server.")
                return
            }
            pipelineStateValue = ColorBoxPipelineState(
                bypassEnabled: storedState.bypassEnabled,
                falseColorEnabled: storedState.falseColorEnabled,
                dynamicLUTMode: storedState.dynamicLUTMode,
                lastRecalledPresetSlot: entry
            )
        case "DeleteEntry":
            presetStore.removeValue(forKey: entry)
            presetPipelineStore.removeValue(forKey: entry)
        default:
            libraryControlValue = libraryControlValue.withError("Unsupported library control action in mock server.")
        }
    }

    func previewImageData() async throws -> Data {
        try await applyLatency()
        return previewPNGDataValue
    }

    private func applyLatency() async throws {
        guard configuration.latencyMilliseconds > 0 else {
            return
        }

        try await Task.sleep(nanoseconds: configuration.latencyMilliseconds * 1_000_000)
    }

    private static func previewPNGData() -> Data {
        Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9sW8h6sAAAAASUVORK5CYII=") ?? Data()
    }
}

struct MockLibraryEntryState: Sendable, Equatable {
    let userName: String?
    let fileName: String?
}

struct MockLibraryControlState: Sendable, Equatable {
    let library: String
    let entry: Int
    let action: String
    let data: String
    let errorMessage: String

    func withError(_ message: String) -> MockLibraryControlState {
        MockLibraryControlState(
            library: library,
            entry: entry,
            action: action,
            data: data,
            errorMessage: message
        )
    }
}
