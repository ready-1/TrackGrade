import Foundation
import TrackGradeCore

actor MockColorBoxState {
    private let configuration: MockColorBoxConfiguration
    private let systemInfoValue: ColorBoxSystemInfo
    private var firmwareInfoValue: ColorBoxFirmwareInfo
    private var pipelineStateValue: ColorBoxPipelineState
    private var presetStore: [Int: ColorBoxPresetSummary]
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
        return presetStore.values.sorted { $0.slot < $1.slot }
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
