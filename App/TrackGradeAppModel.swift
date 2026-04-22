import Foundation
import Observation
import SwiftData

struct AuthenticationPrompt: Identifiable, Equatable {
    let deviceID: UUID
    let deviceName: String
    let username: String

    var id: UUID {
        deviceID
    }
}

private struct GradeHistoryState {
    var undo: [ColorBoxGradeControlState] = []
    var redo: [ColorBoxGradeControlState] = []
}

private struct BeforeAfterSession {
    let focusDeviceID: UUID
    let originalBypassByDeviceID: [UUID: Bool]
}

enum GangSyncState: Sendable, Equatable {
    case synced
    case drift
    case waiting
}

struct GangStatusSummary: Sendable, Equatable {
    let peerCount: Int
    let state: GangSyncState

    var totalDeviceCount: Int {
        peerCount + 1
    }
}

@MainActor
@Observable
final class TrackGradeAppModel {
    var knownDevices: [StoredColorBoxDevice] = []
    var discoveredDevices: [DiscoveredColorBoxDevice] = []
    var snapshots: [ManagedColorBoxDevice] = []
    var gradeSnapshots: [StoredGradeSnapshot] = []
    var librarySectionsByDeviceID: [UUID: [ColorBoxLibrarySection]] = [:]
    var selectedDeviceID: UUID?
    var isShowingAddDeviceSheet = false
    var activeAuthPrompt: AuthenticationPrompt?
    var errorMessage: String?

    private let credentialStore = TrackGradeKeychainStore()
    private let deviceManager = DeviceManager()
    private let discovery = TrackGradeDeviceDiscovery()
    private let launchConfiguration = TrackGradeLaunchConfiguration.current
    private var hasStarted = false
    private var modelContext: ModelContext?
    private var snapshotTask: Task<Void, Never>?
    private var suppressedBannerUntil: Date?
    private var fixturePresetGrades: [UUID: [Int: ColorBoxGradeControlState]] = [:]
    private var gradeHistory: [UUID: GradeHistoryState] = [:]
    private var activeBeforeAfterSession: BeforeAfterSession?
    private let maximumUndoDepth = 50

    var selectedSnapshot: ManagedColorBoxDevice? {
        guard let selectedDeviceID else {
            return nil
        }

        return snapshots.first { $0.id == selectedDeviceID }
    }

    var selectedDeviceRecord: StoredColorBoxDevice? {
        guard let selectedDeviceID else {
            return nil
        }

        return knownDevices.first { $0.id == selectedDeviceID }
    }

    var selectedDeviceSnapshots: [StoredGradeSnapshot] {
        guard let selectedDeviceID else {
            return []
        }

        return snapshots(for: selectedDeviceID)
    }

    var gangedPeerCount: Int {
        knownDevices.filter(\.isGanged).count
    }

    func snapshots(for deviceID: UUID) -> [StoredGradeSnapshot] {
        return gradeSnapshots
            .filter { $0.deviceID == deviceID && $0.kind == .standard }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func librarySections(
        for deviceID: UUID
    ) -> [ColorBoxLibrarySection] {
        librarySectionsByDeviceID[deviceID] ?? []
    }

    func isBeforeAfterActive(
        _ deviceID: UUID
    ) -> Bool {
        activeBeforeAfterSession?.originalBypassByDeviceID.keys.contains(deviceID) == true
    }

    func beforeAfterStatusText(
        for deviceID: UUID
    ) -> String {
        let isBypassed = snapshots.first { $0.id == deviceID }?.pipelineState?.bypassEnabled ?? false
        return isBypassed ? "Showing Before" : "Showing After"
    }

    var canUndoSelectedGrade: Bool {
        guard let selectedDeviceID else {
            return false
        }

        return gradeHistory[selectedDeviceID]?.undo.isEmpty == false
    }

    var canRedoSelectedGrade: Bool {
        guard let selectedDeviceID else {
            return false
        }

        return gradeHistory[selectedDeviceID]?.redo.isEmpty == false
    }

    var visibleConnectionBanner: String? {
        guard let selectedSnapshot else {
            return nil
        }

        if let suppressedBannerUntil, suppressedBannerUntil > .now {
            return nil
        }

        switch selectedSnapshot.connectionState {
        case .degraded:
            return "Connection lost to \(selectedSnapshot.name). Retrying..."
        case .error:
            return selectedSnapshot.lastErrorDescription ?? "Unable to reach \(selectedSnapshot.name)."
        default:
            return nil
        }
    }

    func isDeviceGanged(_ deviceID: UUID) -> Bool {
        knownDevices.first { $0.id == deviceID }?.isGanged ?? false
    }

    func gangStatusSummary(
        for focusDeviceID: UUID
    ) -> GangStatusSummary? {
        let peerIDs = knownDevices
            .filter { $0.isGanged && $0.id != focusDeviceID }
            .map(\.id)

        guard peerIDs.isEmpty == false else {
            return nil
        }

        guard let focusSnapshot = snapshots.first(where: { $0.id == focusDeviceID }),
              focusSnapshot.connectionState == .connected,
              let focusPipelineState = focusSnapshot.pipelineState else {
            return GangStatusSummary(peerCount: peerIDs.count, state: .waiting)
        }

        let peerSnapshots = peerIDs.compactMap { peerID in
            snapshots.first { $0.id == peerID }
        }

        guard peerSnapshots.count == peerIDs.count else {
            return GangStatusSummary(peerCount: peerIDs.count, state: .waiting)
        }

        if peerSnapshots.contains(where: {
            $0.connectionState != .connected || $0.pipelineState == nil
        }) {
            return GangStatusSummary(peerCount: peerIDs.count, state: .waiting)
        }

        let isDrifted = peerSnapshots.contains { peerSnapshot in
            guard let peerPipelineState = peerSnapshot.pipelineState else {
                return true
            }

            return peerPipelineState.bypassEnabled != focusPipelineState.bypassEnabled
                || peerPipelineState.falseColorEnabled != focusPipelineState.falseColorEnabled
                || peerPipelineState.dynamicLUTMode != focusPipelineState.dynamicLUTMode
                || peerPipelineState.lastRecalledPresetSlot != focusPipelineState.lastRecalledPresetSlot
                || peerPipelineState.gradeControl != focusPipelineState.gradeControl
        }

        return GangStatusSummary(
            peerCount: peerIDs.count,
            state: isDrifted ? .drift : .synced
        )
    }

    func start(modelContext: ModelContext) async {
        guard hasStarted == false else {
            return
        }

        hasStarted = true
        self.modelContext = modelContext
        if launchConfiguration.usesUITestFixture {
            loadUITestFixture()
            return
        }
        discovery.onDevicesChanged = { [weak self] devices in
            self?.discoveredDevices = devices
        }
        discovery.start()
        startSnapshotObservation()
        await reloadStoredDevices()
        await reloadStoredSnapshots()
    }

    func refreshDiscovery() {
        guard launchConfiguration.usesUITestFixture == false else {
            return
        }
        discovery.restart()
    }

    func addKnownDevice(
        name: String,
        address: String,
        username: String,
        password: String
    ) async {
        guard let modelContext else {
            return
        }

        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedAddress.isEmpty == false else {
            errorMessage = "A device address is required."
            return
        }

        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedUsername = normalizedUsername(from: username)
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let credentialReference = normalizedPassword.isEmpty ? nil : UUID().uuidString
        let credentials = normalizedPassword.isEmpty
            ? nil
            : ColorBoxCredentials(
                username: normalizedUsername,
                password: normalizedPassword
            )

        do {
            if let credentialReference, let credentials {
                try credentialStore.save(
                    credentials: credentials,
                    reference: credentialReference
                )
            }

            let storedDevice = StoredColorBoxDevice(
                name: normalizedName.isEmpty ? trimmedAddress : normalizedName,
                address: trimmedAddress,
                username: normalizedUsername,
                credentialReference: credentialReference
            )
            modelContext.insert(storedDevice)
            try modelContext.save()

            knownDevices = try fetchKnownDevices()
            _ = try await deviceManager.registerDevice(
                id: storedDevice.id,
                name: storedDevice.name,
                address: storedDevice.address,
                credentials: credentials
            )
            selectedDeviceID = storedDevice.id
            isShowingAddDeviceSheet = false
        } catch {
            errorMessage = "Failed to save the device: \(error.localizedDescription)"
        }
    }

    func addDiscoveredDevice(_ device: DiscoveredColorBoxDevice) async {
        await addKnownDevice(
            name: device.serviceName,
            address: device.address,
            username: "admin",
            password: ""
        )
    }

    func removeDevice(id: UUID) async {
        guard let modelContext,
              let record = knownDevices.first(where: { $0.id == id }) else {
            return
        }

        do {
            if let credentialReference = record.credentialReference {
                try credentialStore.delete(reference: credentialReference)
            }

            modelContext.delete(record)
            let relatedSnapshots = try modelContext.fetch(
                FetchDescriptor<StoredGradeSnapshot>(
                    predicate: #Predicate { $0.deviceID == id }
                )
            )
            for snapshot in relatedSnapshots {
                modelContext.delete(snapshot)
            }
            try modelContext.save()
            knownDevices = try fetchKnownDevices()
            gradeSnapshots = try fetchStoredSnapshots()
            librarySectionsByDeviceID[id] = nil
            await deviceManager.removeDevice(id: id)
            gradeHistory[id] = nil
            if activeBeforeAfterSession?.originalBypassByDeviceID.keys.contains(id) == true {
                activeBeforeAfterSession = nil
            }

            if selectedDeviceID == id {
                selectedDeviceID = knownDevices.first?.id
            }
        } catch {
            errorMessage = "Failed to delete the device: \(error.localizedDescription)"
        }
    }

    func setGangMembership(
        deviceID: UUID,
        isEnabled: Bool
    ) async {
        guard let record = knownDevices.first(where: { $0.id == deviceID }) else {
            return
        }

        record.isGanged = isEnabled

        do {
            if let modelContext {
                try modelContext.save()
                knownDevices = try fetchKnownDevices()
            }
        } catch {
            errorMessage = "Failed to update gang membership: \(error.localizedDescription)"
        }
    }

    func clearGangMembership() async {
        let gangedRecords = knownDevices.filter(\.isGanged)
        guard gangedRecords.isEmpty == false else {
            return
        }

        for record in gangedRecords {
            record.isGanged = false
        }

        do {
            if let modelContext {
                try modelContext.save()
                knownDevices = try fetchKnownDevices()
            }
        } catch {
            errorMessage = "Failed to clear the current gang: \(error.localizedDescription)"
        }
    }

    func promptForAuthentication(deviceID: UUID) {
        guard let record = knownDevices.first(where: { $0.id == deviceID }) else {
            return
        }

        activeAuthPrompt = AuthenticationPrompt(
            deviceID: deviceID,
            deviceName: record.name,
            username: record.username
        )
    }

    func saveCredentials(
        deviceID: UUID,
        username: String,
        password: String
    ) async {
        guard let modelContext,
              let record = knownDevices.first(where: { $0.id == deviceID }) else {
            return
        }

        let normalizedUsername = normalizedUsername(from: username)
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            if normalizedPassword.isEmpty {
                if let credentialReference = record.credentialReference {
                    try credentialStore.delete(reference: credentialReference)
                }
                record.credentialReference = nil
            } else {
                let credentialReference = record.credentialReference ?? UUID().uuidString
                try credentialStore.save(
                    credentials: ColorBoxCredentials(
                        username: normalizedUsername,
                        password: normalizedPassword
                    ),
                    reference: credentialReference
                )
                record.credentialReference = credentialReference
            }

            record.username = normalizedUsername
            try modelContext.save()

            let credentials = normalizedPassword.isEmpty
                ? nil
                : ColorBoxCredentials(
                    username: normalizedUsername,
                    password: normalizedPassword
                )

            _ = try await deviceManager.registerDevice(
                id: record.id,
                name: record.name,
                address: record.address,
                credentials: credentials
            )
            activeAuthPrompt = nil
            await retryConnection(for: record.id)
        } catch {
            errorMessage = "Failed to update credentials: \(error.localizedDescription)"
        }
    }

    func connectSelectedDevice() async {
        guard let selectedDeviceID else {
            return
        }

        await connect(to: selectedDeviceID)
    }

    func connect(to deviceID: UUID) async {
        if launchConfiguration.usesUITestFixture {
            updateFixtureDevice(id: deviceID) { snapshot in
                snapshot.connectionState = .connected
                snapshot.lastErrorDescription = nil
            }
            return
        }

        do {
            let snapshot = try await deviceManager.connect(id: deviceID)
            handleAuthenticationPromptIfNeeded(for: snapshot)
        } catch {
            errorMessage = "Failed to connect: \(error.localizedDescription)"
        }
    }

    func retryConnection(for deviceID: UUID) async {
        suppressedBannerUntil = nil
        await connect(to: deviceID)
    }

    func refreshDevice(id: UUID) async {
        if launchConfiguration.usesUITestFixture {
            updateFixtureDevice(id: id) { snapshot in
                snapshot.connectionState = .connected
                snapshot.lastErrorDescription = nil
            }
            return
        }

        do {
            let snapshot = try await deviceManager.refreshDevice(id: id)
            handleAuthenticationPromptIfNeeded(for: snapshot)
        } catch {
            errorMessage = "Failed to refresh the device: \(error.localizedDescription)"
        }
    }

    func configurePipeline(id: UUID) async {
        let targetIDs = broadcastTargetIDs(for: id)
        if launchConfiguration.usesUITestFixture {
            updateFixtureDevices(ids: targetIDs) { snapshot in
                let current = snapshot.pipelineState
                snapshot.pipelineState = ColorBoxPipelineState(
                    bypassEnabled: current?.bypassEnabled ?? false,
                    falseColorEnabled: current?.falseColorEnabled ?? false,
                    dynamicLUTMode: "dynamic",
                    gradeControl: current?.gradeControl ?? .identity,
                    lastRecalledPresetSlot: current?.lastRecalledPresetSlot
                )
            }
            return
        }

        await performManagedDeviceCommand(
            targetIDs: targetIDs,
            failurePrefix: "Failed to configure the ColorBox pipeline"
        ) { targetID in
            try await self.deviceManager.configurePipelineForTrackGrade(id: targetID)
        }
    }

    func setBypass(
        id: UUID,
        enabled: Bool
    ) async {
        let targetIDs = broadcastTargetIDs(for: id)
        if launchConfiguration.usesUITestFixture {
            updateFixtureDevices(ids: targetIDs) { snapshot in
                let current = snapshot.pipelineState
                snapshot.pipelineState = ColorBoxPipelineState(
                    bypassEnabled: enabled,
                    falseColorEnabled: current?.falseColorEnabled ?? false,
                    dynamicLUTMode: current?.dynamicLUTMode ?? "dynamic",
                    gradeControl: current?.gradeControl ?? .identity,
                    lastRecalledPresetSlot: current?.lastRecalledPresetSlot
                )
            }
            return
        }

        await performManagedDeviceCommand(
            targetIDs: targetIDs,
            failurePrefix: "Failed to update bypass"
        ) { targetID in
            try await self.deviceManager.setBypass(id: targetID, enabled: enabled)
        }
    }

    func toggleBeforeAfter(
        id: UUID
    ) async {
        if isBeforeAfterActive(id) {
            await restoreBeforeAfter()
        } else {
            await activateBeforeAfter(id: id)
        }
    }

    func setFalseColor(
        id: UUID,
        enabled: Bool
    ) async {
        let targetIDs = broadcastTargetIDs(for: id)
        if launchConfiguration.usesUITestFixture {
            updateFixtureDevices(ids: targetIDs) { snapshot in
                let current = snapshot.pipelineState
                snapshot.pipelineState = ColorBoxPipelineState(
                    bypassEnabled: current?.bypassEnabled ?? false,
                    falseColorEnabled: enabled,
                    dynamicLUTMode: current?.dynamicLUTMode ?? "dynamic",
                    gradeControl: current?.gradeControl ?? .identity,
                    lastRecalledPresetSlot: current?.lastRecalledPresetSlot
                )
                snapshot.supportsFalseColor = true
            }
            return
        }

        await performManagedDeviceCommand(
            targetIDs: targetIDs,
            failurePrefix: "Failed to update false color"
        ) { targetID in
            try await self.deviceManager.setFalseColor(id: targetID, enabled: enabled)
        }
    }

    func updateGradeControl(
        id: UUID,
        gradeControl: ColorBoxGradeControlState
    ) async {
        let targetIDs = broadcastTargetIDs(for: id)
        if launchConfiguration.usesUITestFixture {
            updateFixtureDevices(ids: targetIDs) { snapshot in
                let current = snapshot.pipelineState
                snapshot.pipelineState = ColorBoxPipelineState(
                    bypassEnabled: current?.bypassEnabled ?? false,
                    falseColorEnabled: current?.falseColorEnabled ?? false,
                    dynamicLUTMode: current?.dynamicLUTMode ?? "dynamic",
                    gradeControl: gradeControl,
                    lastRecalledPresetSlot: current?.lastRecalledPresetSlot
                )
            }
            return
        }

        await performManagedDeviceCommand(
            targetIDs: targetIDs,
            failurePrefix: "Failed to update the dynamic 3D LUT controls"
        ) { targetID in
            try await self.deviceManager.updateGradeControl(
                id: targetID,
                gradeControl: gradeControl
            )
        }
    }

    func refreshPreview(id: UUID) async {
        if launchConfiguration.usesUITestFixture {
            updateFixtureDevice(id: id) { snapshot in
                snapshot.previewByteCount = snapshot.previewFrameData?.count ?? 0
            }
            return
        }

        do {
            let snapshot = try await deviceManager.refreshPreview(id: id)
            handleAuthenticationPromptIfNeeded(for: snapshot)
        } catch {
            errorMessage = "Failed to refresh the preview frame: \(error.localizedDescription)"
        }
    }

    func refreshLibrary(id: UUID) async {
        if launchConfiguration.usesUITestFixture {
            if librarySectionsByDeviceID[id] == nil {
                librarySectionsByDeviceID[id] = TrackGradeUITestFixture.fixtureLibrarySections()
            }
            return
        }

        do {
            let sections = try await deviceManager.fetchLibraries(id: id)
            librarySectionsByDeviceID[id] = sections
        } catch {
            errorMessage = "Failed to refresh the device library: \(error.localizedDescription)"
        }
    }

    func savePreset(
        id: UUID,
        slot: Int,
        name: String
    ) async {
        if launchConfiguration.usesUITestFixture {
            let gradeControl = snapshots.first { $0.id == id }?.pipelineState?.gradeControl ?? .identity
            var storedGrades = fixturePresetGrades[id] ?? [:]
            storedGrades[slot] = gradeControl
            fixturePresetGrades[id] = storedGrades

            updateFixtureDevice(id: id) { snapshot in
                let summary = ColorBoxPresetSummary(slot: slot, name: name)
                if let existingIndex = snapshot.presets.firstIndex(where: { $0.slot == slot }) {
                    snapshot.presets[existingIndex] = summary
                } else {
                    snapshot.presets.append(summary)
                    snapshot.presets.sort { $0.slot < $1.slot }
                }
            }
            return
        }

        do {
            let snapshot = try await deviceManager.savePreset(
                id: id,
                slot: slot,
                name: name
            )
            handleAuthenticationPromptIfNeeded(for: snapshot)
        } catch {
            errorMessage = "Failed to save the preset: \(error.localizedDescription)"
        }
    }

    func recallPreset(
        id: UUID,
        slot: Int
    ) async {
        let targetIDs = broadcastTargetIDs(for: id)
        if launchConfiguration.usesUITestFixture {
            for targetID in targetIDs {
                let storedGrade = fixturePresetGrades[targetID]?[slot]
                updateFixtureDevice(id: targetID) { snapshot in
                    let current = snapshot.pipelineState
                    snapshot.pipelineState = ColorBoxPipelineState(
                        bypassEnabled: current?.bypassEnabled ?? false,
                        falseColorEnabled: current?.falseColorEnabled ?? false,
                        dynamicLUTMode: current?.dynamicLUTMode ?? "dynamic",
                        gradeControl: storedGrade ?? current?.gradeControl ?? .identity,
                        lastRecalledPresetSlot: slot
                    )
                }
            }
            return
        }

        await performManagedDeviceCommand(
            targetIDs: targetIDs,
            failurePrefix: "Failed to recall the preset"
        ) { targetID in
            try await self.deviceManager.recallPreset(id: targetID, slot: slot)
        }
    }

    func deletePreset(
        id: UUID,
        slot: Int
    ) async {
        if launchConfiguration.usesUITestFixture {
            var storedGrades = fixturePresetGrades[id] ?? [:]
            storedGrades[slot] = nil
            fixturePresetGrades[id] = storedGrades

            updateFixtureDevice(id: id) { snapshot in
                snapshot.presets.removeAll { $0.slot == slot }
            }
            return
        }

        do {
            let snapshot = try await deviceManager.deletePreset(id: id, slot: slot)
            handleAuthenticationPromptIfNeeded(for: snapshot)
        } catch {
            errorMessage = "Failed to delete the preset: \(error.localizedDescription)"
        }
    }

    func recordCommittedGradeChange(
        id: UUID,
        from previous: ColorBoxGradeControlState,
        to next: ColorBoxGradeControlState
    ) {
        guard previous != next else {
            return
        }

        var history = gradeHistory[id] ?? GradeHistoryState()
        history.undo.append(previous)
        if history.undo.count > maximumUndoDepth {
            history.undo.removeFirst(history.undo.count - maximumUndoDepth)
        }
        history.redo.removeAll()
        gradeHistory[id] = history
    }

    func undoSelectedGrade() async {
        guard let selectedDeviceID else {
            return
        }

        await undoGrade(id: selectedDeviceID)
    }

    func redoSelectedGrade() async {
        guard let selectedDeviceID else {
            return
        }

        await redoGrade(id: selectedDeviceID)
    }

    func saveSnapshot(
        id: UUID,
        customName: String? = nil
    ) async {
        guard let device = snapshots.first(where: { $0.id == id }),
              let gradeControl = device.pipelineState?.gradeControl else {
            return
        }

        let snapshotName = customName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? customName!.trimmingCharacters(in: .whitespacesAndNewlines)
            : defaultSnapshotName(for: device)

        let record = StoredGradeSnapshot(
            deviceID: id,
            deviceName: device.name,
            name: snapshotName,
            kind: .standard,
            previewFrameData: device.previewFrameData,
            gradeControl: gradeControl
        )

        do {
            if let modelContext {
                modelContext.insert(record)
                try modelContext.save()
                gradeSnapshots = try fetchStoredSnapshots()
            } else {
                gradeSnapshots.insert(record, at: 0)
            }
        } catch {
            errorMessage = "Failed to save the snapshot: \(error.localizedDescription)"
        }
    }

    func deleteSnapshot(id snapshotID: UUID) async {
        do {
            if let existingIndex = gradeSnapshots.firstIndex(where: { $0.id == snapshotID }) {
                let record = gradeSnapshots[existingIndex]
                if let modelContext {
                    modelContext.delete(record)
                    try modelContext.save()
                    gradeSnapshots = try fetchStoredSnapshots()
                } else {
                    gradeSnapshots.remove(at: existingIndex)
                }
            }
        } catch {
            errorMessage = "Failed to delete the snapshot: \(error.localizedDescription)"
        }
    }

    func recallSnapshot(id snapshotID: UUID) async {
        guard let record = gradeSnapshots.first(where: { $0.id == snapshotID }) else {
            return
        }

        await applyStoredGrade(
            deviceID: record.deviceID,
            gradeControl: record.gradeControl
        )
    }

    func captureScratchSlot(
        id: UUID,
        slot: ABScratchSlot
    ) async {
        guard let device = snapshots.first(where: { $0.id == id }),
              let gradeControl = device.pipelineState?.gradeControl else {
            return
        }

        do {
            if let existing = scratchSnapshot(for: id, slot: slot) {
                existing.name = "Scratch \(slot.displayName)"
                existing.deviceName = device.name
                existing.previewFrameData = device.previewFrameData
                existing.updatedAt = .now
                existing.gradeControl = gradeControl

                if let modelContext {
                    try modelContext.save()
                    gradeSnapshots = try fetchStoredSnapshots()
                }
            } else {
                let scratchRecord = StoredGradeSnapshot(
                    deviceID: id,
                    deviceName: device.name,
                    name: "Scratch \(slot.displayName)",
                    kind: slot.snapshotKind,
                    previewFrameData: device.previewFrameData,
                    gradeControl: gradeControl
                )

                if let modelContext {
                    modelContext.insert(scratchRecord)
                    try modelContext.save()
                    gradeSnapshots = try fetchStoredSnapshots()
                } else {
                    gradeSnapshots.insert(scratchRecord, at: 0)
                }
            }
        } catch {
            errorMessage = "Failed to store scratch slot \(slot.displayName): \(error.localizedDescription)"
        }
    }

    func recallScratchSlot(
        id: UUID,
        slot: ABScratchSlot
    ) async {
        guard let record = scratchSnapshot(for: id, slot: slot) else {
            return
        }

        await applyStoredGrade(
            deviceID: id,
            gradeControl: record.gradeControl
        )
    }

    func scratchSnapshot(
        for deviceID: UUID,
        slot: ABScratchSlot
    ) -> StoredGradeSnapshot? {
        gradeSnapshots.first {
            $0.deviceID == deviceID && $0.kind == slot.snapshotKind
        }
    }

    func dismissConnectionBanner() {
        suppressedBannerUntil = .now.addingTimeInterval(60)
    }

    private func startSnapshotObservation() {
        snapshotTask?.cancel()
        snapshotTask = Task { [weak self] in
            guard let self else {
                return
            }

            let stream = await deviceManager.snapshotStream()
            for await snapshots in stream {
                await MainActor.run {
                    self.snapshots = snapshots
                    if self.selectedDeviceID == nil {
                        self.selectedDeviceID = snapshots.first?.id ?? self.knownDevices.first?.id
                    }
                    if let selectedSnapshot = self.selectedSnapshot {
                        self.handleAuthenticationPromptIfNeeded(for: selectedSnapshot)
                    }
                }
            }
        }
    }

    private func reloadStoredDevices() async {
        do {
            knownDevices = try fetchKnownDevices()
            for record in knownDevices {
                let credentials = try loadCredentials(for: record)
                _ = try await deviceManager.registerDevice(
                    id: record.id,
                    name: record.name,
                    address: record.address,
                    credentials: credentials
                )
            }
            if selectedDeviceID == nil {
                selectedDeviceID = knownDevices.first?.id
            }
        } catch {
            errorMessage = "Failed to load saved devices: \(error.localizedDescription)"
        }
    }

    private func reloadStoredSnapshots() async {
        do {
            gradeSnapshots = try fetchStoredSnapshots()
        } catch {
            errorMessage = "Failed to load saved snapshots: \(error.localizedDescription)"
        }
    }

    private func fetchKnownDevices() throws -> [StoredColorBoxDevice] {
        guard let modelContext else {
            return []
        }

        let descriptor = FetchDescriptor<StoredColorBoxDevice>(
            sortBy: [SortDescriptor(\.name)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func fetchStoredSnapshots() throws -> [StoredGradeSnapshot] {
        guard let modelContext else {
            return gradeSnapshots
        }

        let descriptor = FetchDescriptor<StoredGradeSnapshot>(
            sortBy: [
                SortDescriptor(\.updatedAt, order: .reverse),
                SortDescriptor(\.createdAt, order: .reverse),
            ]
        )
        return try modelContext.fetch(descriptor)
    }

    private func loadCredentials(
        for record: StoredColorBoxDevice
    ) throws -> ColorBoxCredentials? {
        guard let credentialReference = record.credentialReference else {
            return nil
        }

        return try credentialStore.load(reference: credentialReference)
    }

    private func normalizedUsername(from username: String) -> String {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "admin" : trimmed
    }

    private func loadUITestFixture() {
        let fixture = TrackGradeUITestFixture.make()
        do {
            try seedUITestPersistence(using: fixture)
            knownDevices = try fetchKnownDevices()
            gradeSnapshots = try fetchStoredSnapshots()
        } catch {
            knownDevices = fixture.knownDevices
            gradeSnapshots = fixture.snapshotsData
            errorMessage = "Failed to seed the UI test fixture store: \(error.localizedDescription)"
        }
        snapshots = fixture.snapshots
        selectedDeviceID = fixture.snapshots.first?.id
        fixturePresetGrades = fixture.presetGrades
        librarySectionsByDeviceID = fixture.librarySections
        gradeHistory.removeAll()
    }

    private func seedUITestPersistence(
        using fixture: TrackGradeUITestFixture
    ) throws {
        guard let modelContext else {
            return
        }

        let existingDevices = try modelContext.fetch(FetchDescriptor<StoredColorBoxDevice>())
        for device in existingDevices {
            modelContext.delete(device)
        }

        let existingSnapshots = try modelContext.fetch(FetchDescriptor<StoredGradeSnapshot>())
        for snapshot in existingSnapshots {
            modelContext.delete(snapshot)
        }

        for device in fixture.knownDevices {
            let record = StoredColorBoxDevice(
                id: device.id,
                name: device.name,
                address: device.address,
                username: device.username,
                credentialReference: device.credentialReference,
                isGanged: device.isGanged,
                createdAt: device.createdAt
            )
            modelContext.insert(record)
        }

        for snapshot in fixture.snapshotsData {
            let record = StoredGradeSnapshot(
                id: snapshot.id,
                deviceID: snapshot.deviceID,
                deviceName: snapshot.deviceName,
                name: snapshot.name,
                kind: snapshot.kind,
                createdAt: snapshot.createdAt,
                updatedAt: snapshot.updatedAt,
                previewFrameData: snapshot.previewFrameData,
                gradeControl: snapshot.gradeControl
            )
            modelContext.insert(record)
        }

        try modelContext.save()
    }

    private func updateFixtureDevice(
        id: UUID,
        mutate: (inout ManagedColorBoxDevice) -> Void
    ) {
        guard let index = snapshots.firstIndex(where: { $0.id == id }) else {
            return
        }

        mutate(&snapshots[index])
    }

    private func updateFixtureDevices(
        ids: [UUID],
        mutate: (inout ManagedColorBoxDevice) -> Void
    ) {
        for id in ids {
            updateFixtureDevice(id: id, mutate: mutate)
        }
    }

    private func handleAuthenticationPromptIfNeeded(
        for snapshot: ManagedColorBoxDevice
    ) {
        guard let errorDescription = snapshot.lastErrorDescription?.lowercased() else {
            return
        }

        let requiresCredentials = errorDescription.contains("401")
            || errorDescription.contains("unauthorized")

        if requiresCredentials {
            promptForAuthentication(deviceID: snapshot.id)
        } else if activeAuthPrompt?.deviceID == snapshot.id,
                  snapshot.connectionState == .connected {
            activeAuthPrompt = nil
        }
    }

    private func defaultSnapshotName(
        for device: ManagedColorBoxDevice
    ) -> String {
        let timeStamp = Date.now.formatted(
            Date.FormatStyle()
                .month(.abbreviated)
                .day(.twoDigits)
                .hour(.twoDigits(amPM: .abbreviated))
                .minute(.twoDigits)
        )

        return "\(device.name) \(timeStamp)"
    }

    private func applyStoredGrade(
        deviceID: UUID,
        gradeControl: ColorBoxGradeControlState
    ) async {
        let currentGrade = snapshots.first { $0.id == deviceID }?.pipelineState?.gradeControl
            ?? .identity
        recordCommittedGradeChange(
            id: deviceID,
            from: currentGrade,
            to: gradeControl
        )
        selectedDeviceID = deviceID
        await updateGradeControl(
            id: deviceID,
            gradeControl: gradeControl
        )
    }

    private func broadcastTargetIDs(
        for focusDeviceID: UUID
    ) -> [UUID] {
        var targetIDs = [focusDeviceID]
        targetIDs.append(
            contentsOf: knownDevices
                .filter { $0.isGanged && $0.id != focusDeviceID }
                .map(\.id)
        )

        var seen = Set<UUID>()
        return targetIDs.filter { seen.insert($0).inserted }
    }

    private func activateBeforeAfter(
        id: UUID
    ) async {
        if activeBeforeAfterSession != nil {
            await restoreBeforeAfter()
        }

        let targetIDs = broadcastTargetIDs(for: id)
        let originalBypassByDeviceID = Dictionary(
            uniqueKeysWithValues: targetIDs.map { targetID in
                let isBypassed = snapshots.first { $0.id == targetID }?.pipelineState?.bypassEnabled ?? false
                return (targetID, isBypassed)
            }
        )
        let session = BeforeAfterSession(
            focusDeviceID: id,
            originalBypassByDeviceID: originalBypassByDeviceID
        )
        let desiredBypassByDeviceID = originalBypassByDeviceID.mapValues { !$0 }

        if launchConfiguration.usesUITestFixture {
            applyFixtureBypassStates(desiredBypassByDeviceID)
            activeBeforeAfterSession = session
            return
        }

        let successfulIDs = await applyBypassStates(
            desiredBypassByDeviceID,
            failurePrefix: "Failed to start Before/After compare"
        )

        guard successfulIDs.count == desiredBypassByDeviceID.count else {
            let rollbackStates: [UUID: Bool] = .init(
                uniqueKeysWithValues: successfulIDs.compactMap { successfulID in
                    guard let originalBypass = originalBypassByDeviceID[successfulID] else {
                        return nil
                    }

                    return (successfulID, originalBypass)
                }
            )

            if rollbackStates.isEmpty == false {
                _ = await applyBypassStates(
                    rollbackStates,
                    failurePrefix: "Failed to restore bypass after Before/After error"
                )
            }
            return
        }

        activeBeforeAfterSession = session
    }

    private func restoreBeforeAfter() async {
        guard let session = activeBeforeAfterSession else {
            return
        }

        if launchConfiguration.usesUITestFixture {
            applyFixtureBypassStates(session.originalBypassByDeviceID)
            activeBeforeAfterSession = nil
            return
        }

        let successfulIDs = await applyBypassStates(
            session.originalBypassByDeviceID,
            failurePrefix: "Failed to restore Before/After state"
        )

        guard successfulIDs.count == session.originalBypassByDeviceID.count else {
            return
        }

        activeBeforeAfterSession = nil
    }

    private func applyFixtureBypassStates(
        _ bypassByDeviceID: [UUID: Bool]
    ) {
        for (deviceID, isBypassed) in bypassByDeviceID {
            updateFixtureDevice(id: deviceID) { snapshot in
                let current = snapshot.pipelineState
                snapshot.pipelineState = ColorBoxPipelineState(
                    bypassEnabled: isBypassed,
                    falseColorEnabled: current?.falseColorEnabled ?? false,
                    dynamicLUTMode: current?.dynamicLUTMode ?? "dynamic",
                    gradeControl: current?.gradeControl ?? .identity,
                    lastRecalledPresetSlot: current?.lastRecalledPresetSlot
                )
            }
        }
    }

    private func applyBypassStates(
        _ bypassByDeviceID: [UUID: Bool],
        failurePrefix: String
    ) async -> Set<UUID> {
        var failures: [String] = []
        var successfulIDs = Set<UUID>()

        await withTaskGroup(of: (UUID, Result<ManagedColorBoxDevice, Error>).self) { group in
            for (targetID, isBypassed) in bypassByDeviceID {
                group.addTask {
                    do {
                        return (
                            targetID,
                            .success(try await self.deviceManager.setBypass(id: targetID, enabled: isBypassed))
                        )
                    } catch {
                        return (targetID, .failure(error))
                    }
                }
            }

            for await (targetID, result) in group {
                switch result {
                case let .success(snapshot):
                    successfulIDs.insert(targetID)
                    handleAuthenticationPromptIfNeeded(for: snapshot)
                case let .failure(error):
                    failures.append(error.localizedDescription)
                }
            }
        }

        if failures.isEmpty == false {
            errorMessage = failures.count == 1
                ? "\(failurePrefix): \(failures[0])"
                : "\(failurePrefix): \(failures.count) devices reported errors."
        }

        return successfulIDs
    }

    private func performManagedDeviceCommand(
        targetIDs: [UUID],
        failurePrefix: String,
        operation: @escaping @Sendable (UUID) async throws -> ManagedColorBoxDevice
    ) async {
        var failures: [String] = []

        await withTaskGroup(of: Result<ManagedColorBoxDevice, Error>.self) { group in
            for targetID in targetIDs {
                group.addTask {
                    do {
                        return .success(try await operation(targetID))
                    } catch {
                        return .failure(error)
                    }
                }
            }

            for await result in group {
                switch result {
                case let .success(snapshot):
                    handleAuthenticationPromptIfNeeded(for: snapshot)
                case let .failure(error):
                    failures.append(error.localizedDescription)
                }
            }
        }

        if failures.isEmpty == false {
            errorMessage = failures.count == 1
                ? "\(failurePrefix): \(failures[0])"
                : "\(failurePrefix): \(failures.count) devices reported errors."
        }
    }

    private func undoGrade(id: UUID) async {
        guard var history = gradeHistory[id],
              let previous = history.undo.popLast() else {
            return
        }

        let current = snapshots.first { $0.id == id }?.pipelineState?.gradeControl ?? .identity
        history.redo.append(current)
        gradeHistory[id] = history
        await updateGradeControl(id: id, gradeControl: previous)
    }

    private func redoGrade(id: UUID) async {
        guard var history = gradeHistory[id],
              let next = history.redo.popLast() else {
            return
        }

        let current = snapshots.first { $0.id == id }?.pipelineState?.gradeControl ?? .identity
        history.undo.append(current)
        if history.undo.count > maximumUndoDepth {
            history.undo.removeFirst(history.undo.count - maximumUndoDepth)
        }
        gradeHistory[id] = history
        await updateGradeControl(id: id, gradeControl: next)
    }
}
