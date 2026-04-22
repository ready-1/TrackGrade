import Foundation

public actor DeviceManager {
    private struct SnapshotSubscriber: Sendable {
        let id: UUID
        let continuation: AsyncStream<[ManagedColorBoxDevice]>.Continuation
    }

    private struct StoredDevice: Sendable {
        var snapshot: ManagedColorBoxDevice
        let endpoint: ColorBoxEndpoint
        let credentials: ColorBoxCredentials?
        var hasConnectedOnce: Bool
    }

    private var devices: [UUID: StoredDevice] = [:]
    private var dynamicLUTUploadQueues: [UUID: DynamicLUTUploadQueue] = [:]
    private var reconnectTasks: [UUID: Task<Void, Never>] = [:]
    private var snapshotSubscribers: [UUID: SnapshotSubscriber] = [:]
    private let urlSession: URLSession
    private let retryPolicy: ConnectionRetryPolicy

    public init(
        urlSession: URLSession = .shared,
        retryPolicy: ConnectionRetryPolicy = .default
    ) {
        self.urlSession = urlSession
        self.retryPolicy = retryPolicy
    }

    @discardableResult
    public func registerDevice(
        id: UUID = UUID(),
        name: String,
        address: String,
        credentials: ColorBoxCredentials? = nil
    ) throws -> UUID {
        let endpoint = try ColorBoxEndpoint.resolve(address)
        reconnectTasks[id]?.cancel()
        let snapshot = ManagedColorBoxDevice(
            id: id,
            name: name,
            address: address
        )
        dynamicLUTUploadQueues[id] = nil
        devices[id] = StoredDevice(
            snapshot: snapshot,
            endpoint: endpoint,
            credentials: credentials,
            hasConnectedOnce: false
        )
        broadcastSnapshots()
        return id
    }

    public func removeDevice(id: UUID) {
        reconnectTasks[id]?.cancel()
        reconnectTasks[id] = nil
        dynamicLUTUploadQueues[id] = nil
        devices[id] = nil
        broadcastSnapshots()
    }

    public func deviceSnapshot(id: UUID) -> ManagedColorBoxDevice? {
        devices[id]?.snapshot
    }

    public func allDeviceSnapshots() -> [ManagedColorBoxDevice] {
        devices.values.map(\.snapshot).sorted { $0.name < $1.name }
    }

    public func snapshotStream() -> AsyncStream<[ManagedColorBoxDevice]> {
        let subscriberID = UUID()

        return AsyncStream { continuation in
            snapshotSubscribers[subscriberID] = SnapshotSubscriber(
                id: subscriberID,
                continuation: continuation
            )
            continuation.yield(allDeviceSnapshots())
            continuation.onTermination = { _ in
                Task {
                    await self.removeSnapshotSubscriber(id: subscriberID)
                }
            }
        }
    }

    @discardableResult
    public func connect(id: UUID) async throws -> ManagedColorBoxDevice {
        try updateConnectionState(for: id, to: .connecting)
        return try await refreshDevice(id: id)
    }

    @discardableResult
    public func refreshDevice(id: UUID) async throws -> ManagedColorBoxDevice {
        do {
            let storedDevice = try requireDevice(id: id)
            let client = makeClient(for: storedDevice)

            async let systemInfo = client.fetchSystemInfo()
            async let firmwareInfo = client.fetchFirmwareInfo()
            async let pipelineState = client.fetchPipelineState()
            async let presets = client.listPresets()
            async let previewFrame = client.fetchPreviewFrame()

            var refreshed = storedDevice.snapshot
            refreshed.systemInfo = try await systemInfo
            refreshed.firmwareInfo = try await firmwareInfo
            refreshed.pipelineState = try await pipelineState
            refreshed.supportsFalseColor = inferredFalseColorSupport(from: refreshed.firmwareInfo)
            refreshed.presets = try await presets
            let previewData = try await previewFrame
            refreshed.previewFrameData = previewData
            refreshed.previewByteCount = previewData.count
            refreshed.connectionState = .connected
            refreshed.lastErrorDescription = nil

            var updated = storedDevice
            updated.snapshot = refreshed
            updated.hasConnectedOnce = true
            devices[id] = updated
            reconnectTasks[id]?.cancel()
            reconnectTasks[id] = nil
            broadcastSnapshots()

            return refreshed
        } catch {
            return try await handleFailure(id: id, error: error)
        }
    }

    @discardableResult
    public func configurePipelineForTrackGrade(id: UUID) async throws -> ManagedColorBoxDevice {
        do {
            let storedDevice = try requireDevice(id: id)
            let pipelineState = try await makeClient(for: storedDevice).configureDynamicLUTNode()
            return try await updatePipelineState(id: id, pipelineState: pipelineState)
        } catch {
            return try await handleFailure(id: id, error: error)
        }
    }

    @discardableResult
    public func setBypass(id: UUID, enabled: Bool) async throws -> ManagedColorBoxDevice {
        do {
            let storedDevice = try requireDevice(id: id)
            let pipelineState = try await makeClient(for: storedDevice).setBypass(enabled)
            return try await updatePipelineState(id: id, pipelineState: pipelineState)
        } catch {
            return try await handleFailure(id: id, error: error)
        }
    }

    @discardableResult
    public func setFalseColor(id: UUID, enabled: Bool) async throws -> ManagedColorBoxDevice {
        do {
            let storedDevice = try requireDevice(id: id)
            let pipelineState = try await makeClient(for: storedDevice).setFalseColor(enabled)
            return try await updatePipelineState(
                id: id,
                pipelineState: pipelineState,
                supportsFalseColor: true
            )
        } catch let error as ColorBoxAPIError {
            if case let .unsupportedFeature(message) = error {
                try markFalseColorUnsupported(
                    id: id,
                    message: message
                )
                throw error
            }
            return try await handleFailure(id: id, error: error)
        } catch {
            return try await handleFailure(id: id, error: error)
        }
    }

    @discardableResult
    public func updateGradeControl(
        id: UUID,
        gradeControl: ColorBoxGradeControlState
    ) async throws -> ManagedColorBoxDevice {
        do {
            let storedDevice = try requireDevice(id: id)
            let pipelineState = try await makeClient(for: storedDevice).updateGradeControl(gradeControl)
            return try await updatePipelineState(id: id, pipelineState: pipelineState)
        } catch {
            return try await handleFailure(id: id, error: error)
        }
    }

    @discardableResult
    public func savePreset(
        id: UUID,
        slot: Int,
        name: String
    ) async throws -> ManagedColorBoxDevice {
        do {
            let storedDevice = try requireDevice(id: id)
            let presets = try await makeClient(for: storedDevice).savePreset(slot: slot, name: name)
            return try updatePresets(id: id, presets: presets)
        } catch {
            return try await handleFailure(id: id, error: error)
        }
    }

    @discardableResult
    public func recallPreset(id: UUID, slot: Int) async throws -> ManagedColorBoxDevice {
        do {
            let storedDevice = try requireDevice(id: id)
            let pipelineState = try await makeClient(for: storedDevice).recallPreset(slot: slot)
            return try await updatePipelineState(id: id, pipelineState: pipelineState)
        } catch {
            return try await handleFailure(id: id, error: error)
        }
    }

    @discardableResult
    public func deletePreset(id: UUID, slot: Int) async throws -> ManagedColorBoxDevice {
        do {
            let storedDevice = try requireDevice(id: id)
            let presets = try await makeClient(for: storedDevice).deletePreset(slot: slot)
            return try updatePresets(id: id, presets: presets)
        } catch {
            return try await handleFailure(id: id, error: error)
        }
    }

    @discardableResult
    public func refreshPreview(id: UUID) async throws -> ManagedColorBoxDevice {
        do {
            let storedDevice = try requireDevice(id: id)
            let previewFrame = try await makeClient(for: storedDevice).fetchPreviewFrame()
            var updated = storedDevice
            updated.snapshot.previewFrameData = previewFrame
            updated.snapshot.previewByteCount = previewFrame.count
            updated.snapshot.connectionState = .connected
            updated.snapshot.lastErrorDescription = nil
            updated.hasConnectedOnce = true
            devices[id] = updated
            reconnectTasks[id]?.cancel()
            reconnectTasks[id] = nil
            broadcastSnapshots()
            return updated.snapshot
        } catch {
            return try await handleFailure(id: id, error: error)
        }
    }

    public func fetchLibraries(
        id: UUID
    ) async throws -> [ColorBoxLibrarySection] {
        do {
            let storedDevice = try requireDevice(id: id)
            let libraries = try await makeClient(for: storedDevice).listLibraries()
            var updated = storedDevice
            updated.snapshot.connectionState = .connected
            updated.snapshot.lastErrorDescription = nil
            updated.hasConnectedOnce = true
            devices[id] = updated
            reconnectTasks[id]?.cancel()
            reconnectTasks[id] = nil
            broadcastSnapshots()
            return libraries
        } catch {
            _ = try await handleFailure(id: id, error: error)
            throw error
        }
    }

    @discardableResult
    public func enqueueDynamicLUTUpload(
        id: UUID,
        cubeText: String
    ) async throws -> Int {
        let storedDevice = try requireDevice(id: id)
        let uploadQueue = dynamicLUTUploadQueue(
            for: id,
            storedDevice: storedDevice
        )
        return await uploadQueue.enqueue(cubeText: cubeText)
    }

    public func flushDynamicLUTUploads(
        id: UUID
    ) async throws {
        let storedDevice = try requireDevice(id: id)
        let uploadQueue = dynamicLUTUploadQueue(
            for: id,
            storedDevice: storedDevice
        )
        await uploadQueue.flush()

        if let error = await uploadQueue.lastError() {
            throw error
        }
    }

    private func makeClient(for storedDevice: StoredDevice) -> ColorBoxAPIClient {
        ColorBoxAPIClient(
            endpoint: storedDevice.endpoint,
            credentials: storedDevice.credentials,
            urlSession: urlSession
        )
    }

    private func dynamicLUTUploadQueue(
        for id: UUID,
        storedDevice: StoredDevice
    ) -> DynamicLUTUploadQueue {
        if let existingQueue = dynamicLUTUploadQueues[id] {
            return existingQueue
        }

        let client = makeClient(for: storedDevice)
        let queue = DynamicLUTUploadQueue { cubeText, sequenceID in
            try await client.uploadDynamicLUT(
                cubeText: cubeText,
                sequenceID: sequenceID
            )
        }
        dynamicLUTUploadQueues[id] = queue
        return queue
    }

    private func updateConnectionState(
        for id: UUID,
        to state: ConnectionState
    ) throws {
        var storedDevice = try requireDevice(id: id)
        storedDevice.snapshot.connectionState = state
        storedDevice.snapshot.lastErrorDescription = nil
        devices[id] = storedDevice
        broadcastSnapshots()
    }

    private func updatePipelineState(
        id: UUID,
        pipelineState: ColorBoxPipelineState,
        supportsFalseColor: Bool? = nil
    ) async throws -> ManagedColorBoxDevice {
        let currentSnapshot = try requireDevice(id: id)
        var updated = currentSnapshot
        updated.snapshot.pipelineState = pipelineState
        updated.snapshot.supportsFalseColor = supportsFalseColor ?? updated.snapshot.supportsFalseColor
        updated.snapshot.connectionState = .connected
        updated.snapshot.lastErrorDescription = nil
        updated.hasConnectedOnce = true
        devices[id] = updated
        reconnectTasks[id]?.cancel()
        reconnectTasks[id] = nil
        broadcastSnapshots()

        return updated.snapshot
    }

    private func markFalseColorUnsupported(
        id: UUID,
        message: String
    ) throws {
        var storedDevice = try requireDevice(id: id)
        storedDevice.snapshot.supportsFalseColor = false
        storedDevice.snapshot.connectionState = .connected
        storedDevice.snapshot.lastErrorDescription = message

        if let pipelineState = storedDevice.snapshot.pipelineState {
            storedDevice.snapshot.pipelineState = ColorBoxPipelineState(
                bypassEnabled: pipelineState.bypassEnabled,
                falseColorEnabled: false,
                dynamicLUTMode: pipelineState.dynamicLUTMode,
                gradeControl: pipelineState.gradeControl,
                lastRecalledPresetSlot: pipelineState.lastRecalledPresetSlot
            )
        }

        devices[id] = storedDevice
        reconnectTasks[id]?.cancel()
        reconnectTasks[id] = nil
        broadcastSnapshots()
    }

    private func updatePresets(
        id: UUID,
        presets: [ColorBoxPresetSummary]
    ) throws -> ManagedColorBoxDevice {
        var storedDevice = try requireDevice(id: id)
        storedDevice.snapshot.presets = presets
        storedDevice.snapshot.connectionState = .connected
        storedDevice.snapshot.lastErrorDescription = nil
        storedDevice.hasConnectedOnce = true
        devices[id] = storedDevice
        reconnectTasks[id]?.cancel()
        reconnectTasks[id] = nil
        broadcastSnapshots()
        return storedDevice.snapshot
    }

    private func handleFailure(
        id: UUID,
        error: Error
    ) async throws -> ManagedColorBoxDevice {
        var storedDevice = try requireDevice(id: id)
        storedDevice.snapshot.lastErrorDescription = String(describing: error)

        if storedDevice.hasConnectedOnce {
            storedDevice.snapshot.connectionState = .degraded
            devices[id] = storedDevice
            broadcastSnapshots()
            startReconnectLoopIfNeeded(for: id)
        } else {
            storedDevice.snapshot.connectionState = .error
            devices[id] = storedDevice
            broadcastSnapshots()
        }

        return storedDevice.snapshot
    }

    private func startReconnectLoopIfNeeded(for id: UUID) {
        guard reconnectTasks[id] == nil else {
            return
        }

        reconnectTasks[id] = Task { [retryPolicy] in
            for delay in retryPolicy.delays {
                if Task.isCancelled {
                    return
                }

                let nanoseconds = UInt64(delay * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)

                if Task.isCancelled {
                    return
                }

                do {
                    _ = try await self.refreshDevice(id: id)
                    return
                } catch {
                    continue
                }
            }

            self.markRetryExhausted(for: id)
        }
    }

    private func markRetryExhausted(for id: UUID) {
        guard var storedDevice = devices[id] else {
            return
        }

        storedDevice.snapshot.connectionState = .error
        devices[id] = storedDevice
        reconnectTasks[id] = nil
        broadcastSnapshots()
    }

    private func removeSnapshotSubscriber(id: UUID) {
        snapshotSubscribers[id] = nil
    }

    private func broadcastSnapshots() {
        let snapshots = allDeviceSnapshots()
        for subscriber in snapshotSubscribers.values {
            subscriber.continuation.yield(snapshots)
        }
    }

    private func requireDevice(id: UUID) throws -> StoredDevice {
        guard let storedDevice = devices[id] else {
            throw DeviceManagerError.unknownDevice(id)
        }

        return storedDevice
    }

    private func inferredFalseColorSupport(
        from firmwareInfo: ColorBoxFirmwareInfo?
    ) -> Bool? {
        guard let firmwareInfo else {
            return nil
        }

        if firmwareInfo.version == "3.0.0.24" {
            return false
        }

        if firmwareInfo.version.hasPrefix("mock-") {
            return true
        }

        return nil
    }
}

public enum DeviceManagerError: Error, LocalizedError, Sendable, Equatable {
    case unknownDevice(UUID)

    public var errorDescription: String? {
        switch self {
        case let .unknownDevice(id):
            return "Unknown device identifier: \(id.uuidString)"
        }
    }
}
