import Foundation
import TrackGradeCore

actor MockColorBoxState {
    private let configuration: MockColorBoxConfiguration
    private let systemInfoValue: ColorBoxSystemInfo
    private var firmwareInfoValue: ColorBoxFirmwareInfo
    private var pipelineStateValue: ColorBoxPipelineState
    private var previewSourceValue: ColorBoxPreviewSource
    private var persistedDynamicGradeValue: ColorBoxGradeControlState
    private var presetStore: [Int: ColorBoxPresetSummary]
    private var presetPipelineStore: [Int: ColorBoxPipelineState]
    private var libraryControlValue: MockLibraryControlState
    private let libraryEntriesByKind: [ColorBoxLibraryKind: [MockLibraryEntryState]]
    private var previewPNGDataValue: Data
    private var lastUploadedLUT: Data
    private var lastUploadedSequenceIDValue: String?
    private var dynamicLUTUploadCountValue: Int

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
            gradeControl: .identity,
            lastRecalledPresetSlot: nil
        )
        self.previewSourceValue = .output
        self.persistedDynamicGradeValue = .identity
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
        self.libraryEntriesByKind = [
            .oneDLUT: [
                MockLibraryEntryState(userName: "709 Clamp", fileName: "709-clamp.cube"),
                MockLibraryEntryState(userName: "Legalize", fileName: "legalize.cube"),
            ],
            .threeDLUT: [
                MockLibraryEntryState(userName: "Stage Neutral", fileName: "stage-neutral-33.cube"),
                MockLibraryEntryState(userName: "Warm LED", fileName: "warm-led-33.cube"),
            ],
            .matrix: [
                MockLibraryEntryState(userName: "LED Matrix A", fileName: "led-matrix-a.mtx"),
            ],
            .image: [
                MockLibraryEntryState(userName: "Framing Guide", fileName: "framing-guide.png"),
            ],
            .overlay: [
                MockLibraryEntryState(userName: "Lower Third", fileName: "lower-third.png"),
            ],
        ]
        self.previewPNGDataValue = Self.previewPNGData()
        self.lastUploadedLUT = Data()
        self.lastUploadedSequenceIDValue = nil
        self.dynamicLUTUploadCountValue = 0
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
            previewSource: previewSourceValue,
            dynamicLUTMode: mode,
            gradeControl: pipelineStateValue.gradeControl,
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
        lastUploadedSequenceIDValue = sequenceID
        dynamicLUTUploadCountValue += 1
        return ColorBoxDynamicLUTUploadResponse(
            accepted: true,
            byteCount: data.count,
            sequenceID: sequenceID
        )
    }

    func saveDynamicLutRequest() async throws {
        try await applyLatency()
        persistedDynamicGradeValue = pipelineStateValue.gradeControl
    }

    func setBypass(_ enabled: Bool) async throws -> ColorBoxPipelineState {
        try await applyLatency()
        pipelineStateValue = ColorBoxPipelineState(
            bypassEnabled: enabled,
            falseColorEnabled: pipelineStateValue.falseColorEnabled,
            previewSource: previewSourceValue,
            dynamicLUTMode: pipelineStateValue.dynamicLUTMode,
            gradeControl: pipelineStateValue.gradeControl,
            lastRecalledPresetSlot: pipelineStateValue.lastRecalledPresetSlot
        )
        return pipelineStateValue
    }

    func previewSource() async throws -> ColorBoxPreviewSource {
        try await applyLatency()
        return previewSourceValue
    }

    func setPreviewSource(_ source: ColorBoxPreviewSource) async throws -> ColorBoxPipelineState {
        try await applyLatency()
        previewSourceValue = source
        pipelineStateValue = ColorBoxPipelineState(
            bypassEnabled: pipelineStateValue.bypassEnabled,
            falseColorEnabled: pipelineStateValue.falseColorEnabled,
            previewSource: source,
            dynamicLUTMode: pipelineStateValue.dynamicLUTMode,
            gradeControl: pipelineStateValue.gradeControl,
            lastRecalledPresetSlot: pipelineStateValue.lastRecalledPresetSlot
        )
        return pipelineStateValue
    }

    func setFalseColor(_ enabled: Bool) async throws -> ColorBoxPipelineState {
        try await applyLatency()
        pipelineStateValue = ColorBoxPipelineState(
            bypassEnabled: pipelineStateValue.bypassEnabled,
            falseColorEnabled: enabled,
            previewSource: previewSourceValue,
            dynamicLUTMode: pipelineStateValue.dynamicLUTMode,
            gradeControl: pipelineStateValue.gradeControl,
            lastRecalledPresetSlot: pipelineStateValue.lastRecalledPresetSlot
        )
        return pipelineStateValue
    }

    func updateGradeControl(
        _ gradeControl: ColorBoxGradeControlState
    ) async throws -> ColorBoxPipelineState {
        try await applyLatency()
        pipelineStateValue = ColorBoxPipelineState(
            bypassEnabled: pipelineStateValue.bypassEnabled,
            falseColorEnabled: pipelineStateValue.falseColorEnabled,
            previewSource: previewSourceValue,
            dynamicLUTMode: "dynamic",
            gradeControl: gradeControl,
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
            gradeControl: pipelineStateValue.gradeControl,
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

    func libraryEntries(
        for kind: ColorBoxLibraryKind
    ) async throws -> [MockLibraryEntryState] {
        try await applyLatency()
        return libraryEntriesByKind[kind] ?? []
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
            let storedGradeControl = pipelineStateValue.dynamicLUTMode == "dynamic"
                ? persistedDynamicGradeValue
                : pipelineStateValue.gradeControl
            presetPipelineStore[entry] = ColorBoxPipelineState(
                bypassEnabled: pipelineStateValue.bypassEnabled,
                falseColorEnabled: pipelineStateValue.falseColorEnabled,
                previewSource: previewSourceValue,
                dynamicLUTMode: pipelineStateValue.dynamicLUTMode,
                gradeControl: storedGradeControl,
                lastRecalledPresetSlot: pipelineStateValue.lastRecalledPresetSlot
            )
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
                previewSource: previewSourceValue,
                dynamicLUTMode: storedState.dynamicLUTMode,
                gradeControl: storedState.gradeControl,
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

    func lastUploadedLUTText() -> String? {
        String(data: lastUploadedLUT, encoding: .utf8)
    }

    func lastUploadedSequenceID() -> String? {
        lastUploadedSequenceIDValue
    }

    func dynamicLUTUploadCount() -> Int {
        dynamicLUTUploadCountValue
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
