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

@MainActor
@Observable
final class TrackGradeAppModel {
    var knownDevices: [StoredColorBoxDevice] = []
    var discoveredDevices: [DiscoveredColorBoxDevice] = []
    var snapshots: [ManagedColorBoxDevice] = []
    var gradeSnapshots: [StoredGradeSnapshot] = []
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

        return gradeSnapshots
            .filter { $0.deviceID == selectedDeviceID && $0.kind == .standard }
            .sorted { $0.updatedAt > $1.updatedAt }
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
            await deviceManager.removeDevice(id: id)
            gradeHistory[id] = nil

            if selectedDeviceID == id {
                selectedDeviceID = knownDevices.first?.id
            }
        } catch {
            errorMessage = "Failed to delete the device: \(error.localizedDescription)"
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
        if launchConfiguration.usesUITestFixture {
            updateFixtureDevice(id: id) { snapshot in
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

        do {
            let snapshot = try await deviceManager.configurePipelineForTrackGrade(id: id)
            handleAuthenticationPromptIfNeeded(for: snapshot)
        } catch {
            errorMessage = "Failed to configure the ColorBox pipeline: \(error.localizedDescription)"
        }
    }

    func setBypass(
        id: UUID,
        enabled: Bool
    ) async {
        if launchConfiguration.usesUITestFixture {
            updateFixtureDevice(id: id) { snapshot in
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

        do {
            let snapshot = try await deviceManager.setBypass(id: id, enabled: enabled)
            handleAuthenticationPromptIfNeeded(for: snapshot)
        } catch {
            errorMessage = "Failed to update bypass: \(error.localizedDescription)"
        }
    }

    func setFalseColor(
        id: UUID,
        enabled: Bool
    ) async {
        if launchConfiguration.usesUITestFixture {
            updateFixtureDevice(id: id) { snapshot in
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

        do {
            let snapshot = try await deviceManager.setFalseColor(id: id, enabled: enabled)
            handleAuthenticationPromptIfNeeded(for: snapshot)
        } catch {
            errorMessage = "Failed to update false color: \(error.localizedDescription)"
        }
    }

    func updateGradeControl(
        id: UUID,
        gradeControl: ColorBoxGradeControlState
    ) async {
        if launchConfiguration.usesUITestFixture {
            updateFixtureDevice(id: id) { snapshot in
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

        do {
            let snapshot = try await deviceManager.updateGradeControl(
                id: id,
                gradeControl: gradeControl
            )
            handleAuthenticationPromptIfNeeded(for: snapshot)
        } catch {
            errorMessage = "Failed to update the dynamic 3D LUT controls: \(error.localizedDescription)"
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
        if launchConfiguration.usesUITestFixture {
            let storedGrade = fixturePresetGrades[id]?[slot]
            updateFixtureDevice(id: id) { snapshot in
                let current = snapshot.pipelineState
                snapshot.pipelineState = ColorBoxPipelineState(
                    bypassEnabled: current?.bypassEnabled ?? false,
                    falseColorEnabled: current?.falseColorEnabled ?? false,
                    dynamicLUTMode: current?.dynamicLUTMode ?? "dynamic",
                    gradeControl: storedGrade ?? current?.gradeControl ?? .identity,
                    lastRecalledPresetSlot: slot
                )
            }
            return
        }

        do {
            let snapshot = try await deviceManager.recallPreset(id: id, slot: slot)
            handleAuthenticationPromptIfNeeded(for: snapshot)
        } catch {
            errorMessage = "Failed to recall the preset: \(error.localizedDescription)"
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
        knownDevices = fixture.knownDevices
        snapshots = fixture.snapshots
        selectedDeviceID = fixture.snapshots.first?.id
        fixturePresetGrades = fixture.presetGrades
        gradeSnapshots = fixture.snapshotsData
        gradeHistory.removeAll()
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
