import Foundation

public actor DynamicLUTUploadQueue {
    public struct DeliveredUpload: Equatable, Sendable {
        public let sequenceID: Int
        public let byteCount: Int

        public init(
            sequenceID: Int,
            byteCount: Int
        ) {
            self.sequenceID = sequenceID
            self.byteCount = byteCount
        }
    }

    private struct PendingUpload: Sendable {
        let cubeText: String
        let sequenceID: Int
    }

    private let uploadHandler: @Sendable (String, Int) async throws -> ColorBoxDynamicLUTUploadResponse
    private var nextSequenceID = 1
    private var pendingUpload: PendingUpload?
    private var isUploading = false
    private var flushContinuations: [CheckedContinuation<Void, Never>] = []
    private var lastDeliveredUploadValue: DeliveredUpload?
    private var lastErrorValue: Error?

    public init(
        uploadHandler: @escaping @Sendable (String, Int) async throws -> ColorBoxDynamicLUTUploadResponse
    ) {
        self.uploadHandler = uploadHandler
    }

    @discardableResult
    public func enqueue(
        cubeText: String
    ) -> Int {
        let sequenceID = nextSequenceID
        nextSequenceID += 1
        pendingUpload = PendingUpload(
            cubeText: cubeText,
            sequenceID: sequenceID
        )
        startNextUploadIfNeeded()
        return sequenceID
    }

    public func flush() async {
        guard isUploading || pendingUpload != nil else {
            return
        }

        await withCheckedContinuation { continuation in
            flushContinuations.append(continuation)
        }
    }

    public func lastDeliveredUpload() -> DeliveredUpload? {
        lastDeliveredUploadValue
    }

    public func lastError() -> Error? {
        lastErrorValue
    }

    private func startNextUploadIfNeeded() {
        guard isUploading == false, let nextUpload = pendingUpload else {
            resolveFlushContinuationsIfIdle()
            return
        }

        pendingUpload = nil
        isUploading = true

        Task {
            let result: Result<ColorBoxDynamicLUTUploadResponse, Error>
            do {
                let response = try await self.uploadHandler(
                    nextUpload.cubeText,
                    nextUpload.sequenceID
                )
                result = .success(response)
            } catch {
                result = .failure(error)
            }
            self.handleUploadResult(
                result,
                for: nextUpload
            )
        }
    }

    private func handleUploadResult(
        _ result: Result<ColorBoxDynamicLUTUploadResponse, Error>,
        for upload: PendingUpload
    ) {
        isUploading = false

        switch result {
        case let .success(response):
            lastDeliveredUploadValue = DeliveredUpload(
                sequenceID: upload.sequenceID,
                byteCount: response.byteCount
            )
            lastErrorValue = nil
        case let .failure(error):
            lastErrorValue = error
        }

        startNextUploadIfNeeded()
    }

    private func resolveFlushContinuationsIfIdle() {
        guard isUploading == false, pendingUpload == nil else {
            return
        }

        let continuations = flushContinuations
        flushContinuations.removeAll()
        continuations.forEach { $0.resume() }
    }
}
