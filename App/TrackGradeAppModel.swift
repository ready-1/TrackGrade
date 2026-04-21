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

@MainActor
@Observable
final class TrackGradeAppModel {
    var knownDevices: [StoredColorBoxDevice] = []
    var discoveredDevices: [DiscoveredColorBoxDevice] = []
    var snapshots: [ManagedColorBoxDevice] = []
    var selectedDeviceID: UUID?
    var isShowingAddDeviceSheet = false
    var activeAuthPrompt: AuthenticationPrompt?
    var errorMessage: String?

    private let credentialStore = TrackGradeKeychainStore()
    private let deviceManager = DeviceManager()
    private let discovery = TrackGradeDeviceDiscovery()
    private var hasStarted = false
    private var modelContext: ModelContext?
    private var snapshotTask: Task<Void, Never>?
    private var suppressedBannerUntil: Date?

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
        discovery.onDevicesChanged = { [weak self] devices in
            self?.discoveredDevices = devices
        }
        discovery.start()
        startSnapshotObservation()
        await reloadStoredDevices()
    }

    func refreshDiscovery() {
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
            try modelContext.save()
            knownDevices = try fetchKnownDevices()
            await deviceManager.removeDevice(id: id)

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
        do {
            let snapshot = try await deviceManager.refreshDevice(id: id)
            handleAuthenticationPromptIfNeeded(for: snapshot)
        } catch {
            errorMessage = "Failed to refresh the device: \(error.localizedDescription)"
        }
    }

    func configurePipeline(id: UUID) async {
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
        do {
            let snapshot = try await deviceManager.deletePreset(id: id, slot: slot)
            handleAuthenticationPromptIfNeeded(for: snapshot)
        } catch {
            errorMessage = "Failed to delete the preset: \(error.localizedDescription)"
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

    private func fetchKnownDevices() throws -> [StoredColorBoxDevice] {
        guard let modelContext else {
            return []
        }

        let descriptor = FetchDescriptor<StoredColorBoxDevice>(
            sortBy: [SortDescriptor(\.name)]
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
}
