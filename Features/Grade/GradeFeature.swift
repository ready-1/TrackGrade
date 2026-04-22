import SwiftUI
import UIKit

struct GradeFeatureView: View {
    @Bindable var model: TrackGradeAppModel
    let device: ManagedColorBoxDevice
    let isShowingDeviceSidebar: Bool
    let toggleDeviceSidebar: () -> Void

    @State private var isShowingSettings = false
    @State private var isShowingControlsDrawer = false
    @AppStorage(TrackGradeSettingsKey.hapticsEnabled) private var hapticsEnabled = true

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .trailing) {
                surfaceBackground
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 12) {
                    controlBar
                    DynamicGradeControlsCard(
                        model: model,
                        device: device,
                        availableSize: proxy.size
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .padding(16)

                if isShowingControlsDrawer {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            emitButtonHaptic()
                            isShowingControlsDrawer = false
                        }

                    SecondaryControlsDrawer(
                        model: model,
                        device: device,
                        falseColorUnsupportedMessage: falseColorUnsupportedMessage,
                        closeAction: {
                            emitButtonHaptic()
                            isShowingControlsDrawer = false
                        }
                    )
                    .frame(width: drawerWidth(for: proxy.size))
                    .padding(.trailing, 20)
                    .padding(.vertical, 20)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isShowingControlsDrawer)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingSettings) {
            SettingsFeatureView(
                deviceName: device.name,
                diagnosticsReport: model.diagnosticsReport(for: device.id),
                noticesText: TrackGradeOpenSourceNotices.fullText,
                workingTransferFunction: model.workingTransferFunction(for: device.id),
                onWorkingTransferFunctionChanged: { transferFunction in
                    model.setWorkingTransferFunction(
                        deviceID: device.id,
                        transferFunction: transferFunction
                    )
                }
            )
        }
    }

    private var controlBar: some View {
        HStack(alignment: .center, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                Button {
                    emitButtonHaptic()
                    toggleDeviceSidebar()
                } label: {
                    Label(
                        isShowingDeviceSidebar ? "Hide Devices" : "Devices",
                        systemImage: "sidebar.leading"
                    )
                    .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(Color.black.opacity(0.32))
                .accessibilityIdentifier("device-sidebar-button")

                VStack(alignment: .leading, spacing: 6) {
                    Text(device.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)

                    HStack(spacing: 8) {
                        ConnectionStateBadge(state: device.connectionState)
                        if let gangSummary = model.gangStatusSummary(for: device.id) {
                            GangStatusBadge(summary: gangSummary)
                        }
                    }
                }
            }

            Spacer(minLength: 16)

            BeforeAfterCompareButton(
                isActive: model.isBeforeAfterActive(device.id),
                statusText: model.beforeAfterStatusText(for: device.id)
            ) {
                emitButtonHaptic()
                Task {
                    await model.toggleBeforeAfter(id: device.id)
                }
            }
            .accessibilityIdentifier("before-after-button")

            BypassToggleButton(
                isEnabled: device.pipelineState?.bypassEnabled ?? false,
                isDisabled: model.isBeforeAfterActive(device.id)
            ) {
                emitButtonHaptic()
                Task {
                    await model.setBypass(
                        id: device.id,
                        enabled: (device.pipelineState?.bypassEnabled ?? false) == false
                    )
                }
            }
            .accessibilityIdentifier("bypass-toggle")

            Button {
                emitButtonHaptic()
                isShowingControlsDrawer.toggle()
            } label: {
                Label("Controls", systemImage: "slider.horizontal.3")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(Color.black.opacity(0.32))
            .accessibilityIdentifier("secondary-controls-button")

            Button {
                emitButtonHaptic()
                isShowingSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape.fill")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(Color.black.opacity(0.32))
            .accessibilityIdentifier("grade-settings-button")
        }
        .padding(14)
        .surfacePanelStyle(cornerRadius: 26)
    }

    private var falseColorUnsupportedMessage: String {
        if let firmwareVersion = device.firmwareInfo?.version,
           firmwareVersion.isEmpty == false {
            return "False color is not exposed by ColorBox firmware \(firmwareVersion)."
        }

        return "False color is not exposed by this ColorBox firmware."
    }

    private func emitButtonHaptic() {
        Task { @MainActor in
            HapticsCoordinator.shared.emitButtonPress(isEnabled: hapticsEnabled)
        }
    }

    private var surfaceBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.07, green: 0.09, blue: 0.12),
                Color(red: 0.12, green: 0.15, blue: 0.19),
                Color(red: 0.18, green: 0.19, blue: 0.16),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color.orange.opacity(0.12))
                .frame(width: 280, height: 280)
                .blur(radius: 30)
                .offset(x: 110, y: -90)
        }
    }

    private func drawerWidth(for size: CGSize) -> CGFloat {
        min(380, max(320, size.width * 0.4))
    }
}

private struct BeforeAfterCompareButton: View {
    let isActive: Bool
    let statusText: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Before / After")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.88))

                HStack(spacing: 8) {
                    Image(systemName: isActive ? "rectangle.on.rectangle.circle.fill" : "rectangle.on.rectangle")
                        .font(.subheadline.weight(.semibold))
                    Text(statusText)
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isActive ? Color.orange.opacity(0.3) : Color.black.opacity(0.3))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isActive ? Color.orange.opacity(0.6) : Color.white.opacity(0.22))
            }
        }
        .frame(minHeight: 44)
        .buttonStyle(.plain)
        .accessibilityLabel("Before and After")
        .accessibilityValue(statusText)
    }
}

private struct BypassToggleButton: View {
    let isEnabled: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text("Bypass")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(isEnabled ? "On" : "Off")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isEnabled ? Color.orange.opacity(0.34) : Color.black.opacity(0.34))
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.28))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isEnabled ? Color.orange.opacity(0.55) : Color.white.opacity(0.2))
            }
        }
        .frame(minHeight: 44)
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
        .accessibilityLabel("Bypass")
        .accessibilityValue(isEnabled ? "On" : "Off")
        .accessibilityHint(isDisabled ? "Disabled while before and after compare is active." : "Toggles dynamic LUT bypass.")
    }
}

private struct GangStatusBadge: View {
    let summary: GangStatusSummary

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(backgroundColor)
        )
        .accessibilityLabel(title)
    }

    private var title: String {
        switch summary.state {
        case .synced:
            return "Gang \(summary.totalDeviceCount) synced"
        case .drift:
            return "Gang drift detected"
        case .waiting:
            return "Gang waiting"
        }
    }

    private var systemImage: String {
        switch summary.state {
        case .synced:
            return "link.badge.plus"
        case .drift:
            return "exclamationmark.triangle.fill"
        case .waiting:
            return "clock.badge.exclamationmark"
        }
    }

    private var foregroundColor: Color {
        .white
    }

    private var backgroundColor: Color {
        switch summary.state {
        case .synced:
            return Color(red: 0.09, green: 0.43, blue: 0.24)
        case .drift:
            return Color(red: 0.58, green: 0.38, blue: 0.04)
        case .waiting:
            return Color(red: 0.63, green: 0.32, blue: 0.06)
        }
    }
}

private enum GradeEditorTarget: String, Identifiable {
    case lift
    case gamma
    case gain
    case saturation

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .lift:
            return "Edit Lift"
        case .gamma:
            return "Edit Gamma"
        case .gain:
            return "Edit Gain"
        case .saturation:
            return "Edit Saturation"
        }
    }
}

private struct DynamicGradeControlsCard: View {
    @Bindable var model: TrackGradeAppModel
    let device: ManagedColorBoxDevice
    let availableSize: CGSize

    @State private var draftGrade: ColorBoxGradeControlState
    @State private var liftState: ColorBoxTrackballState
    @State private var gammaState: ColorBoxTrackballState
    @State private var gainState: ColorBoxTrackballState
    @State private var pendingUpdateTask: Task<Void, Never>?
    @State private var activeEditor: GradeEditorTarget?
    @State private var activeTouchCount = 0
    @State private var interactionOrigin: ColorBoxGradeControlState?
    @State private var isShowingPreviewOverlay = false

    @State private var ballAnchors: [TrackballSurfaceKind: ColorBoxControlPoint] = [:]
    @State private var ringAnchors: [TrackballSurfaceKind: Float] = [:]
    @State private var saturationAnchor: Float?

    @AppStorage(TrackGradeSettingsKey.liftBallSensitivity) private var liftBallSensitivity = 1.0
    @AppStorage(TrackGradeSettingsKey.liftRingSensitivity) private var liftRingSensitivity = 1.0
    @AppStorage(TrackGradeSettingsKey.gammaBallSensitivity) private var gammaBallSensitivity = 1.0
    @AppStorage(TrackGradeSettingsKey.gammaRingSensitivity) private var gammaRingSensitivity = 1.0
    @AppStorage(TrackGradeSettingsKey.gainBallSensitivity) private var gainBallSensitivity = 1.0
    @AppStorage(TrackGradeSettingsKey.gainRingSensitivity) private var gainRingSensitivity = 1.0
    @AppStorage(TrackGradeSettingsKey.saturationSensitivity) private var saturationSensitivity = 1.0
    @AppStorage(TrackGradeSettingsKey.hapticsEnabled) private var hapticsEnabled = true
    @AppStorage(TrackGradeSettingsKey.autoRefreshInterval) private var autoRefreshInterval = 0.0
    @AppStorage(TrackGradeSettingsKey.resetRequiresConfirmation) private var resetRequiresConfirmation = true

    init(
        model: TrackGradeAppModel,
        device: ManagedColorBoxDevice,
        availableSize: CGSize
    ) {
        self.model = model
        self.device = device
        self.availableSize = availableSize

        let initialGrade = device.pipelineState?.gradeControl ?? .identity
        _draftGrade = State(initialValue: initialGrade)
        _liftState = State(initialValue: ColorBoxTrackballMapping.state(for: initialGrade.lift, kind: .lift))
        _gammaState = State(initialValue: ColorBoxTrackballMapping.state(for: initialGrade.gamma, kind: .gamma))
        _gainState = State(initialValue: ColorBoxTrackballMapping.state(for: initialGrade.gain, kind: .gain))
    }

    var body: some View {
        let trackballHeight = min(188, max(152, availableSize.height * 0.235))

        VStack(alignment: .leading, spacing: 14) {
            GradeStateDisplay(
                grade: draftGrade,
                previewFrameData: device.previewFrameData,
                previewSource: device.pipelineState?.previewSource ?? .output,
                resetRequiresConfirmation: resetRequiresConfirmation,
                onEdit: { target in
                    activeEditor = target
                },
                onResetAll: {
                    emitButtonHaptic()
                    performDiscreteGradeMutation(successHaptic: true) {
                        draftGrade = .identity
                        syncSurfaceStates(from: .identity)
                    }
                },
                onTogglePreviewSource: {
                    let currentSource = device.pipelineState?.previewSource ?? .output
                    let nextSource: ColorBoxPreviewSource = currentSource == .output ? .input : .output
                    Task {
                        await model.setPreviewSource(
                            id: device.id,
                            source: nextSource
                        )
                    }
                },
                onRefreshPreview: {
                    Task {
                        await model.refreshPreview(id: device.id)
                    }
                },
                onShowPreviewOverlay: {
                    isShowingPreviewOverlay = true
                }
            )

            SaturationRollerView(
                value: Double(draftGrade.saturation),
                sensitivity: saturationSensitivity,
                onEvent: handleSaturationEvent,
                onReset: {
                    emitButtonHaptic()
                    performDiscreteGradeMutation(successHaptic: true) {
                        draftGrade.saturation = 1
                    }
                }
            )

            HStack(alignment: .top, spacing: 14) {
                TrackballClusterView(
                    title: "Lift",
                    kind: .lift,
                    state: $liftState,
                    renderedVector: draftGrade.lift,
                    ballSensitivity: liftBallSensitivity,
                    ringSensitivity: liftRingSensitivity,
                    surfaceHeight: trackballHeight,
                    onBallEvent: handleLiftBall,
                    onRingEvent: handleLiftRing,
                    onResetBall: {
                        emitButtonHaptic()
                        performDiscreteGradeMutation(successHaptic: true) {
                            liftState.ball = .zero
                            draftGrade.lift = ColorBoxTrackballMapping.vector(for: liftState, kind: .lift)
                        }
                    },
                    onResetRing: {
                        emitButtonHaptic()
                        performDiscreteGradeMutation(successHaptic: true) {
                            liftState.ring = 0
                            draftGrade.lift = ColorBoxTrackballMapping.vector(for: liftState, kind: .lift)
                        }
                    }
                )

                TrackballClusterView(
                    title: "Gamma",
                    kind: .gamma,
                    state: $gammaState,
                    renderedVector: draftGrade.gamma,
                    ballSensitivity: gammaBallSensitivity,
                    ringSensitivity: gammaRingSensitivity,
                    surfaceHeight: trackballHeight,
                    onBallEvent: handleGammaBall,
                    onRingEvent: handleGammaRing,
                    onResetBall: {
                        emitButtonHaptic()
                        performDiscreteGradeMutation(successHaptic: true) {
                            gammaState.ball = .zero
                            draftGrade.gamma = ColorBoxTrackballMapping.vector(for: gammaState, kind: .gamma)
                        }
                    },
                    onResetRing: {
                        emitButtonHaptic()
                        performDiscreteGradeMutation(successHaptic: true) {
                            gammaState.ring = 0
                            draftGrade.gamma = ColorBoxTrackballMapping.vector(for: gammaState, kind: .gamma)
                        }
                    }
                )

                TrackballClusterView(
                    title: "Gain",
                    kind: .gain,
                    state: $gainState,
                    renderedVector: draftGrade.gain,
                    ballSensitivity: gainBallSensitivity,
                    ringSensitivity: gainRingSensitivity,
                    surfaceHeight: trackballHeight,
                    onBallEvent: handleGainBall,
                    onRingEvent: handleGainRing,
                    onResetBall: {
                        emitButtonHaptic()
                        performDiscreteGradeMutation(successHaptic: true) {
                            gainState.ball = .zero
                            draftGrade.gain = ColorBoxTrackballMapping.vector(for: gainState, kind: .gain)
                        }
                    },
                    onResetRing: {
                        emitButtonHaptic()
                        performDiscreteGradeMutation(successHaptic: true) {
                            gainState.ring = 0
                            draftGrade.gain = ColorBoxTrackballMapping.vector(for: gainState, kind: .gain)
                        }
                    }
                )
            }
        }
        .padding(16)
        .surfacePanelStyle(cornerRadius: 28)
        .accessibilityValue(Text(accessibilityGradeSummary))
        .accessibilityIdentifier("dynamic-grade-card")
        .sheet(item: $activeEditor) { target in
            NumericGradeEditorSheet(
                target: target,
                grade: draftGrade,
                onSave: { updatedGrade in
                    performDiscreteGradeMutation(successHaptic: false) {
                        draftGrade = updatedGrade
                        syncSurfaceStates(from: updatedGrade)
                    }
                }
            )
        }
        .sheet(isPresented: $isShowingPreviewOverlay) {
            EnlargedPreviewOverlay(
                imageData: device.previewFrameData,
                source: device.pipelineState?.previewSource ?? .output,
                onDismiss: {
                    isShowingPreviewOverlay = false
                }
            )
        }
        .onChange(of: device.pipelineState?.gradeControl) { _, newValue in
            guard let newValue else {
                return
            }

            if newValue != draftGrade {
                activeTouchCount = 0
                interactionOrigin = nil
                draftGrade = newValue
                syncSurfaceStates(from: newValue)
            }
        }
        .onDisappear {
            pendingUpdateTask?.cancel()
        }
        .task(id: previewAutoRefreshTaskID) {
            await runPreviewAutoRefreshLoop()
        }
    }

    private var accessibilityGradeSummary: String {
        [
            "Lift \(formatted(draftGrade.lift))",
            "Gamma \(formatted(draftGrade.gamma))",
            "Gain \(formatted(draftGrade.gain))",
            "Saturation \(formatted(draftGrade.saturation))",
        ].joined(separator: ". ")
    }

    private func formatted(_ value: Float) -> String {
        String(format: "%.2f", Double(value))
    }

    private func formatted(_ vector: ColorBoxRGBVector) -> String {
        "R \(formatted(vector.red))  G \(formatted(vector.green))  B \(formatted(vector.blue))"
    }

    private var previewAutoRefreshTaskID: String {
        "\(device.id.uuidString)-\(autoRefreshInterval)"
    }

    private func handleLiftBall(
        event: SimultaneousTouchEvent,
        size: CGSize
    ) {
        handleBallEvent(
            event: event,
            kind: .lift,
            state: $liftState,
            sensitivity: liftBallSensitivity,
            size: size
        )
    }

    private func handleLiftRing(
        event: SimultaneousTouchEvent,
        size: CGSize
    ) {
        handleRingEvent(
            event: event,
            kind: .lift,
            state: $liftState,
            sensitivity: liftRingSensitivity,
            size: size
        )
    }

    private func handleGammaBall(
        event: SimultaneousTouchEvent,
        size: CGSize
    ) {
        handleBallEvent(
            event: event,
            kind: .gamma,
            state: $gammaState,
            sensitivity: gammaBallSensitivity,
            size: size
        )
    }

    private func handleGammaRing(
        event: SimultaneousTouchEvent,
        size: CGSize
    ) {
        handleRingEvent(
            event: event,
            kind: .gamma,
            state: $gammaState,
            sensitivity: gammaRingSensitivity,
            size: size
        )
    }

    private func handleGainBall(
        event: SimultaneousTouchEvent,
        size: CGSize
    ) {
        handleBallEvent(
            event: event,
            kind: .gain,
            state: $gainState,
            sensitivity: gainBallSensitivity,
            size: size
        )
    }

    private func handleGainRing(
        event: SimultaneousTouchEvent,
        size: CGSize
    ) {
        handleRingEvent(
            event: event,
            kind: .gain,
            state: $gainState,
            sensitivity: gainRingSensitivity,
            size: size
        )
    }

    private func handleBallEvent(
        event: SimultaneousTouchEvent,
        kind: TrackballSurfaceKind,
        state: Binding<ColorBoxTrackballState>,
        sensitivity: Double,
        size: CGSize
    ) {
        let travel = max(48, min(size.width, size.height) * 0.38)

        switch event {
        case .began:
            beginTouchInteraction()
            ballAnchors[kind] = state.wrappedValue.ball

        case let .changed(_, _, translation):
            guard let anchor = ballAnchors[kind] else {
                return
            }

            let previous = state.wrappedValue.ball
            let next = ColorBoxControlPoint(
                x: anchor.x + Float(translation.width / travel) * Float(sensitivity),
                y: anchor.y - Float(translation.height / travel) * Float(sensitivity)
            ).clampedToUnitDisk()

            state.wrappedValue.ball = next
            emitCenterTickIfNeeded(previous: previous, next: next)
            updateGradeFromSurfaceStates(pushImmediately: false, successHaptic: false)

        case .ended, .cancelled:
            ballAnchors[kind] = nil
            updateGradeFromSurfaceStates(pushImmediately: true, successHaptic: false)
            endTouchInteractionIfNeeded()
        }
    }

    private func handleRingEvent(
        event: SimultaneousTouchEvent,
        kind: TrackballSurfaceKind,
        state: Binding<ColorBoxTrackballState>,
        sensitivity: Double,
        size: CGSize
    ) {
        switch event {
        case .began:
            beginTouchInteraction()
            ringAnchors[kind] = state.wrappedValue.ring

        case let .changed(start, location, _):
            guard let anchor = ringAnchors[kind] else {
                return
            }

            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let startAngle = atan2(start.y - center.y, start.x - center.x)
            let currentAngle = atan2(location.y - center.y, location.x - center.x)
            let delta = wrappedAngleDelta(currentAngle - startAngle)
            let previous = state.wrappedValue.ring
            let next = (anchor + Float(delta / .pi) * Float(sensitivity)).clamped(to: -1 ... 1)

            state.wrappedValue.ring = next
            emitZeroDetentIfNeeded(previous: previous, next: next)
            updateGradeFromSurfaceStates(pushImmediately: false, successHaptic: false)

        case .ended, .cancelled:
            ringAnchors[kind] = nil
            updateGradeFromSurfaceStates(pushImmediately: true, successHaptic: false)
            endTouchInteractionIfNeeded()
        }
    }

    private func handleSaturationEvent(
        event: SimultaneousTouchEvent,
        size: CGSize
    ) {
        switch event {
        case .began:
            beginTouchInteraction()
            saturationAnchor = draftGrade.saturation

        case let .changed(_, _, translation):
            guard let saturationAnchor else {
                return
            }

            let previous = draftGrade.saturation
            let delta = Float((translation.width / max(size.width, 1)) * 2) * Float(saturationSensitivity)
            draftGrade.saturation = (saturationAnchor + delta).clamped(to: 0 ... 2)
            emitSaturationDetentIfNeeded(previous: previous, next: draftGrade.saturation)
            scheduleGradeControlUpdate()

        case let .ended(_, location, translation):
            if abs(translation.width) < 6, abs(translation.height) < 6 {
                let progress = (location.x / max(size.width, 1)).clamped(to: 0 ... 1)
                let previous = draftGrade.saturation
                draftGrade.saturation = Float(progress * 2)
                emitSaturationDetentIfNeeded(previous: previous, next: draftGrade.saturation)
            }
            saturationAnchor = nil
            pushGradeControlImmediately()
            endTouchInteractionIfNeeded()

        case .cancelled:
            saturationAnchor = nil
            pushGradeControlImmediately()
            endTouchInteractionIfNeeded()
        }
    }

    private func updateGradeFromSurfaceStates(
        pushImmediately: Bool,
        successHaptic: Bool
    ) {
        draftGrade.lift = ColorBoxTrackballMapping.vector(for: liftState, kind: .lift)
        draftGrade.gamma = ColorBoxTrackballMapping.vector(for: gammaState, kind: .gamma)
        draftGrade.gain = ColorBoxTrackballMapping.vector(for: gainState, kind: .gain)

        if pushImmediately {
            pushGradeControlImmediately(successHaptic: successHaptic)
        } else {
            scheduleGradeControlUpdate()
        }
    }

    private func syncSurfaceStates(from grade: ColorBoxGradeControlState) {
        liftState = ColorBoxTrackballMapping.state(for: grade.lift, kind: .lift)
        gammaState = ColorBoxTrackballMapping.state(for: grade.gamma, kind: .gamma)
        gainState = ColorBoxTrackballMapping.state(for: grade.gain, kind: .gain)
    }

    private func scheduleGradeControlUpdate() {
        let gradeControl = draftGrade
        pendingUpdateTask?.cancel()
        pendingUpdateTask = Task {
            try? await Task.sleep(nanoseconds: 80_000_000)
            if Task.isCancelled {
                return
            }

            await model.updateGradeControl(
                id: device.id,
                gradeControl: gradeControl
            )
        }
    }

    private func pushGradeControlImmediately(
        successHaptic: Bool = false
    ) {
        pendingUpdateTask?.cancel()
        let gradeControl = draftGrade
        Task {
            await model.updateGradeControl(
                id: device.id,
                gradeControl: gradeControl
            )
        }

        if successHaptic {
            emitSuccessHaptic()
        }
    }

    private func performDiscreteGradeMutation(
        successHaptic: Bool,
        mutation: () -> Void
    ) {
        let previous = draftGrade
        mutation()

        guard previous != draftGrade else {
            return
        }

        model.recordCommittedGradeChange(
            id: device.id,
            from: previous,
            to: draftGrade
        )
        pushGradeControlImmediately(successHaptic: successHaptic)
    }

    private func beginTouchInteraction() {
        if activeTouchCount == 0 {
            interactionOrigin = draftGrade
        }
        activeTouchCount += 1
    }

    private func endTouchInteractionIfNeeded() {
        guard activeTouchCount > 0 else {
            return
        }

        activeTouchCount -= 1

        guard activeTouchCount == 0 else {
            return
        }

        defer {
            interactionOrigin = nil
        }

        guard let interactionOrigin,
              interactionOrigin != draftGrade else {
            return
        }

        model.recordCommittedGradeChange(
            id: device.id,
            from: interactionOrigin,
            to: draftGrade
        )
    }

    private func wrappedAngleDelta(_ angle: CGFloat) -> CGFloat {
        if angle > .pi {
            return angle - (.pi * 2)
        }
        if angle < -.pi {
            return angle + (.pi * 2)
        }
        return angle
    }

    private func emitButtonHaptic() {
        Task { @MainActor in
            HapticsCoordinator.shared.emitButtonPress(isEnabled: hapticsEnabled)
        }
    }

    private func emitSuccessHaptic() {
        Task { @MainActor in
            HapticsCoordinator.shared.emitSuccess(isEnabled: hapticsEnabled)
        }
    }

    private func runPreviewAutoRefreshLoop() async {
        guard autoRefreshInterval > 0 else {
            return
        }

        let refreshInterval = UInt64(autoRefreshInterval * 1_000_000_000)
        guard refreshInterval > 0 else {
            return
        }

        while Task.isCancelled == false {
            try? await Task.sleep(nanoseconds: refreshInterval)

            if Task.isCancelled {
                break
            }

            await model.refreshPreview(id: device.id)
        }
    }

    private func emitDetentHaptic() {
        Task { @MainActor in
            HapticsCoordinator.shared.emitDetent(isEnabled: hapticsEnabled)
        }
    }

    private func emitCenterTickIfNeeded(
        previous: ColorBoxControlPoint,
        next: ColorBoxControlPoint
    ) {
        if previous.magnitude >= 0.02, next.magnitude < 0.02 {
            Task { @MainActor in
                HapticsCoordinator.shared.emitCenterTick(isEnabled: hapticsEnabled)
            }
        }
    }

    private func emitZeroDetentIfNeeded(
        previous: Float,
        next: Float
    ) {
        if abs(previous) >= 0.03, abs(next) < 0.03 {
            emitDetentHaptic()
        }
    }

    private func emitSaturationDetentIfNeeded(
        previous: Float,
        next: Float
    ) {
        if abs(previous - 1) >= 0.03, abs(next - 1) < 0.03 {
            emitDetentHaptic()
        }
    }
}

private enum TrackballSurfaceKind: String {
    case lift
    case gamma
    case gain

    var accessibilityIdentifier: String {
        "\(rawValue)-trackball"
    }
}

private struct SecondaryControlsDrawer: View {
    @Bindable var model: TrackGradeAppModel
    let device: ManagedColorBoxDevice
    let falseColorUnsupportedMessage: String
    let closeAction: () -> Void

    @State private var activePanel: DrawerPanel = .workflow
    @State private var isShowingSnapshotBrowser = false
    @State private var isShowingLibraryBrowser = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Secondary Controls")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Device actions, optional toggles, and ColorBox presets.")
                        .font(.footnote)
                        .foregroundStyle(Color.white.opacity(0.68))
                }

                Spacer()

                Button(action: closeAction) {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
            }

            Picker("Drawer Panel", selection: $activePanel) {
                ForEach(DrawerPanel.allCases) { panel in
                    Text(panel.title)
                        .tag(panel)
                }
            }
            .pickerStyle(.segmented)

            Group {
                switch activePanel {
                case .workflow:
                    GradeWorkflowBar(
                        canUndo: model.canUndoSelectedGrade,
                        canRedo: model.canRedoSelectedGrade,
                        scratchA: model.scratchSnapshot(for: device.id, slot: .a),
                        scratchB: model.scratchSnapshot(for: device.id, slot: .b),
                        onUndo: {
                            Task {
                                await model.undoSelectedGrade()
                            }
                        },
                        onRedo: {
                            Task {
                                await model.redoSelectedGrade()
                            }
                        },
                        onSaveSnapshot: {
                            Task {
                                await model.saveSnapshot(id: device.id)
                            }
                        },
                        onShowSnapshots: {
                            isShowingSnapshotBrowser = true
                        },
                        onShowLibrary: {
                            isShowingLibraryBrowser = true
                        },
                        onRecallScratch: { slot in
                            Task {
                                await model.recallScratchSlot(
                                    id: device.id,
                                    slot: slot
                                )
                            }
                        },
                        onCaptureScratch: { slot in
                            Task {
                                await model.captureScratchSlot(
                                    id: device.id,
                                    slot: slot
                                )
                            }
                        }
                    )

                case .presets:
                    PresetsFeatureView(
                        model: model,
                        device: device,
                        style: .drawer
                    )

                case .device:
                    VStack(alignment: .leading, spacing: 18) {
                        DrawerActionGrid(
                            connectAction: {
                                Task {
                                    await model.connect(to: device.id)
                                }
                            },
                            refreshAction: {
                                Task {
                                    await model.refreshDevice(id: device.id)
                                }
                            },
                            previewAction: {
                                Task {
                                    await model.refreshPreview(id: device.id)
                                }
                            },
                            configureAction: {
                                Task {
                                    await model.configurePipeline(id: device.id)
                                }
                            },
                            authAction: {
                                model.promptForAuthentication(deviceID: device.id)
                            }
                        )

                        SurfaceInfoPanel(title: "Focused Device") {
                            SurfaceMetricRow(label: "Connection", value: device.connectionState.rawValue.capitalized)
                            SurfaceMetricRow(label: "Address", value: device.address)
                            SurfaceMetricRow(label: "Product", value: device.systemInfo?.productName ?? "ColorBox")
                            SurfaceMetricRow(label: "Firmware", value: device.firmwareInfo?.version ?? "Unavailable")
                            SurfaceMetricRow(label: "Serial", value: device.systemInfo?.serialNumber ?? "Unavailable")
                        }

                        SurfaceInfoPanel(title: "Pipeline") {
                            SurfaceMetricRow(
                                label: "3D LUT Node",
                                value: device.pipelineState?.dynamicLUTMode.capitalized ?? "Unknown"
                            )
                            SurfaceMetricRow(
                                label: "Preview Tap",
                                value: (device.pipelineState?.previewSource ?? .output).displayName
                            )
                            SurfaceMetricRow(
                                label: "Last Preset",
                                value: lastPresetValue
                            )
                            SurfaceMetricRow(
                                label: "False Color",
                                value: falseColorStatus
                            )
                            SurfaceMetricRow(
                                label: "Bypass",
                                value: (device.pipelineState?.bypassEnabled ?? false) ? "On" : "Off"
                            )
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Optional Pipeline Controls")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white)

                            Toggle(
                                "False Color",
                                isOn: Binding(
                                    get: { device.pipelineState?.falseColorEnabled ?? false },
                                    set: { isEnabled in
                                        Task {
                                            await model.setFalseColor(
                                                id: device.id,
                                                enabled: isEnabled
                                            )
                                        }
                                    }
                                )
                            )
                            .tint(.orange)
                            .foregroundStyle(.white)
                            .disabled(device.supportsFalseColor == false)
                            .accessibilityIdentifier("false-color-toggle")

                            if device.supportsFalseColor == false {
                                Text(falseColorUnsupportedMessage)
                                    .font(.footnote)
                                    .foregroundStyle(Color.white.opacity(0.68))
                            }
                        }
                        .padding(16)
                        .surfacePanelStyle(cornerRadius: 24)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .surfacePanelStyle(cornerRadius: 30)
        .sheet(isPresented: $isShowingSnapshotBrowser) {
            SnapshotBrowserSheet(
                model: model,
                device: device
            )
        }
        .sheet(isPresented: $isShowingLibraryBrowser) {
            LibraryFeatureView(
                model: model,
                device: device
            )
        }
    }

    private var falseColorStatus: String {
        if device.supportsFalseColor == false {
            return "Unsupported"
        }

        return (device.pipelineState?.falseColorEnabled ?? false) ? "On" : "Off"
    }

    private var lastPresetValue: String {
        guard let slot = device.pipelineState?.lastRecalledPresetSlot else {
            return "—"
        }

        return "Slot \(slot)"
    }
}

private enum DrawerPanel: String, CaseIterable, Identifiable {
    case workflow
    case presets
    case device

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .workflow:
            return "Workflow"
        case .presets:
            return "Presets"
        case .device:
            return "Device"
        }
    }
}

private struct DrawerActionGrid: View {
    let connectAction: () -> Void
    let refreshAction: () -> Void
    let previewAction: () -> Void
    let configureAction: () -> Void
    let authAction: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            DrawerActionButton(title: "Connect", systemImage: "link", tint: .orange, action: connectAction)
            DrawerActionButton(title: "Refresh", systemImage: "arrow.clockwise", tint: .blue, action: refreshAction)
            DrawerActionButton(title: "Preview", systemImage: "photo", tint: .teal, action: previewAction)
            DrawerActionButton(title: "Configure", systemImage: "cube.transparent", tint: .mint, action: configureAction)
            DrawerActionButton(title: "Auth", systemImage: "key.fill", tint: .pink, action: authAction)
        }
    }
}

private struct DrawerActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .imageScale(.medium)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(tint.opacity(0.22))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SurfaceInfoPanel<Content: View>: View {
    let title: String
    let content: Content

    init(
        title: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 10) {
                content
            }
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .surfacePanelStyle(cornerRadius: 24)
    }
}

private struct SurfaceMetricRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.82))
                .textCase(.uppercase)
                .accessibilityHidden(true)
            Text(value)
                .font(.callout.monospaced())
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

private struct ConnectionStateBadge: View {
    let state: ConnectionState

    var body: some View {
        Text(state.rawValue.capitalized)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(badgeColor, in: Capsule())
    }

    private var badgeColor: Color {
        switch state {
        case .connected:
            return Color(red: 0.09, green: 0.43, blue: 0.24)
        case .connecting:
            return Color(red: 0.08, green: 0.28, blue: 0.55)
        case .degraded:
            return Color(red: 0.58, green: 0.38, blue: 0.04)
        case .error:
            return Color(red: 0.53, green: 0.14, blue: 0.16)
        case .disconnected:
            return Color(red: 0.28, green: 0.31, blue: 0.36)
        }
    }
}

private struct GradeStateDisplay: View {
    let grade: ColorBoxGradeControlState
    let previewFrameData: Data?
    let previewSource: ColorBoxPreviewSource
    let resetRequiresConfirmation: Bool
    let onEdit: (GradeEditorTarget) -> Void
    let onResetAll: () -> Void
    let onTogglePreviewSource: () -> Void
    let onRefreshPreview: () -> Void
    let onShowPreviewOverlay: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Grade")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)

                        Text("Tap a row for numeric entry.")
                            .font(.footnote)
                            .foregroundStyle(Color.white.opacity(0.78))
                            .accessibilityHidden(true)
                    }

                    Spacer(minLength: 8)

                    DoubleTapActionChip(
                        title: "Reset All",
                        tint: .orange,
                        requiresExplicitLabel: resetRequiresConfirmation,
                        identifier: "reset-all-chip",
                        action: onResetAll
                    )
                }

                NumericDisplayRow(
                    label: "Lift",
                    value: formatted(grade.lift),
                    identifier: "lift-state-row",
                    action: { onEdit(.lift) }
                )

                NumericDisplayRow(
                    label: "Gamma",
                    value: formatted(grade.gamma),
                    identifier: "gamma-state-row",
                    action: { onEdit(.gamma) }
                )

                NumericDisplayRow(
                    label: "Gain",
                    value: formatted(grade.gain),
                    identifier: "gain-state-row",
                    action: { onEdit(.gain) }
                )

                NumericDisplayRow(
                    label: "Sat",
                    value: formatted(grade.saturation),
                    identifier: "sat-state-row",
                    action: { onEdit(.saturation) }
                )
            }

            Spacer(minLength: 0)

            PreviewThumbnail(
                imageData: previewFrameData,
                source: previewSource,
                toggleAction: onTogglePreviewSource,
                refreshAction: onRefreshPreview,
                enlargeAction: onShowPreviewOverlay
            )
            .frame(width: 136, height: 88)
        }
        .padding(16)
        .surfacePanelStyle(cornerRadius: 24)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Grade state"))
        .accessibilityValue(Text(accessibilitySummary))
        .accessibilityIdentifier("grade-state-display")
    }

    private func formatted(_ value: Float) -> String {
        String(format: "%.2f", Double(value))
    }

    private func formatted(_ vector: ColorBoxRGBVector) -> String {
        "R \(formatted(vector.red))  G \(formatted(vector.green))  B \(formatted(vector.blue))"
    }

    private var accessibilitySummary: String {
        [
            "Lift \(formatted(grade.lift))",
            "Gamma \(formatted(grade.gamma))",
            "Gain \(formatted(grade.gain))",
            "Saturation \(formatted(grade.saturation))",
        ].joined(separator: ". ")
    }
}

private struct NumericDisplayRow: View {
    let label: String
    let value: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)

                Spacer()

                Text(value)
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(0.75)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .frame(minHeight: 40)
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(value))
        .accessibilityHint(Text("Opens the numeric editor for \(label)."))
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(.isButton)
    }
}

private struct PreviewThumbnail: View {
    let imageData: Data?
    let source: ColorBoxPreviewSource
    let toggleAction: () -> Void
    let refreshAction: () -> Void
    let enlargeAction: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if let imageData,
                   let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                        Image(systemName: "photo")
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .onTapGesture(perform: toggleAction)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.45)
                    .onEnded { _ in
                        enlargeAction()
                    }
            )

            Text("\(source.displayName) Preview")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.62), in: Capsule())
                .padding(8)
                .minimumScaleFactor(0.75)
                .accessibilityHidden(true)
                .accessibilityIdentifier("preview-source-label")

            VStack {
                HStack {
                    Spacer()

                    Button(action: enlargeAction) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption.weight(.bold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .background(Color.black.opacity(0.62), in: Circle())
                    .padding(.top, 8)
                    .accessibilityIdentifier("expand-preview-button")

                    Button(action: refreshAction) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption.weight(.bold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .background(Color.black.opacity(0.62), in: Circle())
                    .padding(8)
                    .accessibilityIdentifier("refresh-preview-button")
                }

                Spacer()
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Preview thumbnail")
        .accessibilityValue("\(source.displayName) source")
        .accessibilityHint("Tap to toggle between input and output preview. Touch and hold to enlarge. Use the refresh button to fetch a new frame.")
        .accessibilityIdentifier("grade-preview-thumbnail")
    }
}

private struct EnlargedPreviewOverlay: View {
    let imageData: Data?
    let source: ColorBoxPreviewSource
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Preview overlay active")
                    .font(.caption)
                    .foregroundStyle(.clear)
                    .accessibilityIdentifier("expanded-preview-visible")

                PreviewFeatureView(
                    imageData: imageData,
                    byteCount: imageData?.count ?? 0
                )
                .frame(maxWidth: .infinity, minHeight: 280, maxHeight: 360)

                Text("Tap the preview thumbnail to switch between input and output. This sheet stays focused on the current preview source.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .navigationTitle("\(source.displayName) Preview")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                        .accessibilityIdentifier("expanded-preview-done-button")
                }
            }
        }
        .accessibilityIdentifier("expanded-preview-overlay")
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct TrackballClusterView: View {
    let title: String
    let kind: TrackballSurfaceKind
    @Binding var state: ColorBoxTrackballState
    let renderedVector: ColorBoxRGBVector
    let ballSensitivity: Double
    let ringSensitivity: Double
    let surfaceHeight: CGFloat
    let onBallEvent: (SimultaneousTouchEvent, CGSize) -> Void
    let onRingEvent: (SimultaneousTouchEvent, CGSize) -> Void
    let onResetBall: () -> Void
    let onResetRing: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("B \(ballSensitivity, specifier: "%.2fx")  R \(ringSensitivity, specifier: "%.2fx")")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.white.opacity(0.6))
            }

            GeometryReader { proxy in
                let size = proxy.size

                ZStack {
                    Canvas { context, canvasSize in
                        drawTrackball(
                            in: &context,
                            size: canvasSize,
                            state: state,
                            renderedVector: renderedVector
                        )
                    }

                    ControlTouchSurface(
                        shape: .annulus(
                            innerRadiusFraction: 0.34,
                            outerRadiusFraction: 0.5
                        ),
                        onEvent: { event in
                            onRingEvent(event, size)
                        }
                    )

                    ControlTouchSurface(
                        shape: .circle(radiusFraction: 0.32),
                        onEvent: { event in
                            onBallEvent(event, size)
                        }
                    )
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(title) trackball"))
                .accessibilityIdentifier(kind.accessibilityIdentifier)
            }
            .frame(height: surfaceHeight)

            HStack(spacing: 10) {
                DoubleTapActionChip(
                    title: "Reset Ball",
                    tint: .cyan,
                    requiresExplicitLabel: true,
                    identifier: "\(kind.rawValue)-reset-ball-chip",
                    action: onResetBall
                )

                DoubleTapActionChip(
                    title: "Reset Ring",
                    tint: .mint,
                    requiresExplicitLabel: true,
                    identifier: "\(kind.rawValue)-reset-ring-chip",
                    action: onResetRing
                )
            }
        }
        .padding(14)
        .surfacePanelStyle(cornerRadius: 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func drawTrackball(
        in context: inout GraphicsContext,
        size: CGSize,
        state: ColorBoxTrackballState,
        renderedVector: ColorBoxRGBVector
    ) {
        let rect = CGRect(origin: .zero, size: size).insetBy(dx: 14, dy: 14)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) * 0.5
        let innerRadius = outerRadius * 0.64
        let ballRadius = innerRadius * 0.24
        let ringRadius = (outerRadius + innerRadius) * 0.5

        let outerPath = Path(ellipseIn: CGRect(
            x: center.x - outerRadius,
            y: center.y - outerRadius,
            width: outerRadius * 2,
            height: outerRadius * 2
        ))
        context.stroke(
            outerPath,
            with: .color(Color.white.opacity(0.14)),
            style: StrokeStyle(lineWidth: outerRadius - innerRadius, lineCap: .round)
        )

        let ringAngle = Angle(degrees: Double(state.ring.clamped(to: -1 ... 1)) * 150)
        let startAngle = Angle(degrees: -90)
        let endAngle = startAngle + ringAngle
        let ringRect = CGRect(
            x: center.x - ringRadius,
            y: center.y - ringRadius,
            width: ringRadius * 2,
            height: ringRadius * 2
        )
        let indicator = Path { path in
            path.addArc(
                center: CGPoint(x: ringRect.midX, y: ringRect.midY),
                radius: ringRadius,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: ringAngle.radians < 0
            )
        }

        context.stroke(
            indicator,
            with: .color(state.ring >= 0 ? .orange : .blue),
            style: StrokeStyle(lineWidth: max(14, outerRadius - innerRadius - 8), lineCap: .round)
        )

        let innerRect = CGRect(
            x: center.x - innerRadius,
            y: center.y - innerRadius,
            width: innerRadius * 2,
            height: innerRadius * 2
        )
        context.fill(
            Path(ellipseIn: innerRect),
            with: .radialGradient(
                Gradient(colors: [
                    Color.white.opacity(0.08),
                    Color.black.opacity(0.28),
                ]),
                center: center,
                startRadius: 12,
                endRadius: innerRadius
            )
        )

        let crossHair = Path { path in
            path.move(to: CGPoint(x: center.x - innerRadius, y: center.y))
            path.addLine(to: CGPoint(x: center.x + innerRadius, y: center.y))
            path.move(to: CGPoint(x: center.x, y: center.y - innerRadius))
            path.addLine(to: CGPoint(x: center.x, y: center.y + innerRadius))
        }
        context.stroke(
            crossHair,
            with: .color(Color.white.opacity(0.08)),
            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
        )

        let ball = state.ball.clampedToUnitDisk()
        let ballCenter = CGPoint(
            x: center.x + CGFloat(ball.x) * (innerRadius - ballRadius - 8),
            y: center.y - CGFloat(ball.y) * (innerRadius - ballRadius - 8)
        )
        let ballRect = CGRect(
            x: ballCenter.x - ballRadius,
            y: ballCenter.y - ballRadius,
            width: ballRadius * 2,
            height: ballRadius * 2
        )
        context.addFilter(.shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 8))
        context.fill(
            Path(ellipseIn: ballRect),
            with: .color(ballColor(for: renderedVector))
        )
        context.stroke(
            Path(ellipseIn: ballRect),
            with: .color(Color.white.opacity(0.5)),
            lineWidth: 2
        )
    }

    private func ballColor(for vector: ColorBoxRGBVector) -> Color {
        let normalized: (Float) -> Double = { value in
            Double((value + 1).clamped(to: 0 ... 2) / 2)
        }

        return Color(
            red: normalized(vector.red),
            green: normalized(vector.green),
            blue: normalized(vector.blue)
        )
    }
}

private struct SaturationRollerView: View {
    let value: Double
    let sensitivity: Double
    let onEvent: (SimultaneousTouchEvent, CGSize) -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Saturation")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(sensitivity, specifier: "%.2fx")")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.white.opacity(0.6))
                Text(String(format: "%.2f", value))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.white)

                DoubleTapActionChip(
                    title: "Reset",
                    tint: .yellow,
                    requiresExplicitLabel: true,
                    identifier: "saturation-reset-chip",
                    action: onReset
                )
            }

            GeometryReader { proxy in
                let size = proxy.size
                let progress = CGFloat((value / 2).clamped(to: 0 ... 1))

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.black.opacity(0.2))

                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .gray.opacity(0.5),
                                    .orange.opacity(0.75),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(28, size.width * progress))

                    Capsule()
                        .fill(Color.white)
                        .frame(width: 26, height: size.height - 16)
                        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                        .offset(x: max(0, (size.width - 26) * progress))

                    ControlTouchSurface(
                        shape: .rectangle,
                        onEvent: { event in
                            onEvent(event, size)
                        }
                    )
                }
                .contentShape(Rectangle())
            }
            .frame(height: 68)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Saturation roller"))
            .accessibilityIdentifier("saturation-roller")

            HStack {
                Text("0.00")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.white.opacity(0.6))
                Spacer()
                Text("2.00")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.white.opacity(0.6))
            }
        }
        .padding(14)
        .surfacePanelStyle(cornerRadius: 24)
    }
}

private struct GradeWorkflowBar: View {
    let canUndo: Bool
    let canRedo: Bool
    let scratchA: StoredGradeSnapshot?
    let scratchB: StoredGradeSnapshot?
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onSaveSnapshot: () -> Void
    let onShowSnapshots: () -> Void
    let onShowLibrary: () -> Void
    let onRecallScratch: (ABScratchSlot) -> Void
    let onCaptureScratch: (ABScratchSlot) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Workflow")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                workflowButton(
                    title: "Undo",
                    systemImage: "arrow.uturn.backward",
                    identifier: "undo-grade-button",
                    isEnabled: canUndo,
                    action: onUndo
                )
                .keyboardShortcut("z", modifiers: [.command])

                workflowButton(
                    title: "Redo",
                    systemImage: "arrow.uturn.forward",
                    identifier: "redo-grade-button",
                    isEnabled: canRedo,
                    action: onRedo
                )
                .keyboardShortcut("Z", modifiers: [.command, .shift])

                workflowButton(
                    title: "Save Snapshot",
                    systemImage: "camera.aperture",
                    identifier: "save-snapshot-button",
                    isEnabled: true,
                    action: onSaveSnapshot
                )

                workflowButton(
                    title: "Snapshots",
                    systemImage: "square.stack.3d.up",
                    identifier: "show-snapshots-button",
                    isEnabled: true,
                    action: onShowSnapshots
                )

                workflowButton(
                    title: "Library",
                    systemImage: "books.vertical",
                    identifier: "show-library-button",
                    isEnabled: true,
                    action: onShowLibrary
                )
            }

            VStack(alignment: .leading, spacing: 12) {
                ScratchSlotCard(
                    slot: .a,
                    snapshot: scratchA,
                    onRecall: { onRecallScratch(.a) },
                    onCapture: { onCaptureScratch(.a) }
                )

                ScratchSlotCard(
                    slot: .b,
                    snapshot: scratchB,
                    onRecall: { onRecallScratch(.b) },
                    onCapture: { onCaptureScratch(.b) }
                )
            }
        }
        .padding(16)
        .surfacePanelStyle(cornerRadius: 24)
    }

    private func workflowButton(
        title: String,
        systemImage: String,
        identifier: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(.white.opacity(0.14))
        .foregroundStyle(.white)
        .disabled(isEnabled == false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(.isButton)
    }
}

private struct ScratchSlotCard: View {
    let slot: ABScratchSlot
    let snapshot: StoredGradeSnapshot?
    let onRecall: () -> Void
    let onCapture: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Scratch \(slot.displayName)")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(snapshot == nil ? "Empty" : "Ready")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(snapshot == nil ? Color.white.opacity(0.45) : .green)
            }

            Text(snapshot?.name ?? "Tap recall after storing a scratch state.")
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.72))
                .lineLimit(2)

            if let snapshot {
                Text(snapshot.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.white.opacity(0.52))
            } else {
                Text("Double-tap store to capture current grade.")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.52))
            }

            HStack(spacing: 10) {
                Button(action: onRecall) {
                    Label("Recall \(slot.displayName)", systemImage: "arrow.clockwise.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(snapshot == nil)
                .accessibilityIdentifier("scratch-\(slot.rawValue)-recall")

                DoubleTapActionChip(
                    title: "Store \(slot.displayName)",
                    tint: .cyan,
                    requiresExplicitLabel: true,
                    identifier: "scratch-\(slot.rawValue)-store",
                    action: onCapture
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct SnapshotBrowserSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var model: TrackGradeAppModel
    let device: ManagedColorBoxDevice

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Snapshots are stored on the iPad for quick recall, A/B compare, and show cues.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Snapshots for \(device.name)") {
                    if model.snapshots(for: device.id).isEmpty {
                        ContentUnavailableView(
                            "No Snapshots Yet",
                            systemImage: "camera.aperture",
                            description: Text("Save a snapshot from the control surface to capture the current grade and preview frame.")
                        )
                    } else {
                        ForEach(model.snapshots(for: device.id)) { snapshot in
                            SnapshotRow(
                                snapshot: snapshot,
                                onRecall: {
                                    Task {
                                        await model.recallSnapshot(id: snapshot.id)
                                        dismiss()
                                    }
                                },
                                onDelete: {
                                    Task {
                                        await model.deleteSnapshot(id: snapshot.id)
                                    }
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Snapshots")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Current") {
                        Task {
                            await model.saveSnapshot(id: device.id)
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct SnapshotRow: View {
    let snapshot: StoredGradeSnapshot
    let onRecall: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SnapshotThumbnail(previewData: snapshot.previewFrameData)
                .frame(width: 96, height: 60)

            VStack(alignment: .leading, spacing: 6) {
                Text(snapshot.name)
                    .font(.headline)
                Text(snapshot.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(snapshotSummary)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            VStack(spacing: 8) {
                Button("Recall", action: onRecall)
                    .buttonStyle(.borderedProminent)
                Button("Delete", role: .destructive, action: onDelete)
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("snapshot-\(snapshot.id.uuidString)")
    }

    private var snapshotSummary: String {
        let grade = snapshot.gradeControl
        return String(
            format: "L %.2f %.2f %.2f  G %.2f %.2f %.2f  S %.2f",
            Double(grade.lift.red),
            Double(grade.lift.green),
            Double(grade.lift.blue),
            Double(grade.gain.red),
            Double(grade.gain.green),
            Double(grade.gain.blue),
            Double(grade.saturation)
        )
    }
}

private struct SnapshotThumbnail: View {
    let previewData: Data?

    var body: some View {
        Group {
            if let previewData,
               let image = UIImage(data: previewData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.secondary.opacity(0.12))
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct DoubleTapActionChip: View {
    let title: String
    let tint: Color
    let requiresExplicitLabel: Bool
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minHeight: 36)
                .background(
                    Capsule(style: .continuous)
                        .fill(tint.opacity(0.32))
                )
        }
        .buttonStyle(.plain)
        .accessibilityHint(requiresExplicitLabel ? "Resets this control." : "Activates \(title.lowercased()).")
        .accessibilityIdentifier(identifier)
    }
}

private struct NumericGradeEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let target: GradeEditorTarget
    let grade: ColorBoxGradeControlState
    let onSave: (ColorBoxGradeControlState) -> Void

    @State private var redValue: String
    @State private var greenValue: String
    @State private var blueValue: String
    @State private var scalarValue: String

    init(
        target: GradeEditorTarget,
        grade: ColorBoxGradeControlState,
        onSave: @escaping (ColorBoxGradeControlState) -> Void
    ) {
        self.target = target
        self.grade = grade
        self.onSave = onSave

        switch target {
        case .lift:
            _redValue = State(initialValue: Self.format(grade.lift.red))
            _greenValue = State(initialValue: Self.format(grade.lift.green))
            _blueValue = State(initialValue: Self.format(grade.lift.blue))
            _scalarValue = State(initialValue: "")
        case .gamma:
            _redValue = State(initialValue: Self.format(grade.gamma.red))
            _greenValue = State(initialValue: Self.format(grade.gamma.green))
            _blueValue = State(initialValue: Self.format(grade.gamma.blue))
            _scalarValue = State(initialValue: "")
        case .gain:
            _redValue = State(initialValue: Self.format(grade.gain.red))
            _greenValue = State(initialValue: Self.format(grade.gain.green))
            _blueValue = State(initialValue: Self.format(grade.gain.blue))
            _scalarValue = State(initialValue: "")
        case .saturation:
            _redValue = State(initialValue: "")
            _greenValue = State(initialValue: "")
            _blueValue = State(initialValue: "")
            _scalarValue = State(initialValue: Self.format(grade.saturation))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                switch target {
                case .saturation:
                    Section("Value") {
                        numericField(
                            "Saturation",
                            text: $scalarValue,
                            identifier: "numeric-saturation-field"
                        )
                    }
                case .lift, .gamma, .gain:
                    Section("RGB") {
                        numericField("Red", text: $redValue, identifier: "numeric-red-field")
                        numericField("Green", text: $greenValue, identifier: "numeric-green-field")
                        numericField("Blue", text: $blueValue, identifier: "numeric-blue-field")
                    }
                }
            }
            .navigationTitle(target.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(updatedGrade())
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func numericField(
        _ label: String,
        text: Binding<String>,
        identifier: String
    ) -> some View {
        TextField(label, text: text)
            .keyboardType(.numbersAndPunctuation)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .accessibilityIdentifier(identifier)
    }

    private func updatedGrade() -> ColorBoxGradeControlState {
        var next = grade

        switch target {
        case .lift:
            next.lift = vectorValue(fallback: grade.lift)
        case .gamma:
            next.gamma = vectorValue(fallback: grade.gamma)
        case .gain:
            next.gain = vectorValue(fallback: grade.gain)
        case .saturation:
            next.saturation = Float(scalarValue) ?? grade.saturation
        }

        return next
    }

    private func vectorValue(
        fallback: ColorBoxRGBVector
    ) -> ColorBoxRGBVector {
        ColorBoxRGBVector(
            red: Float(redValue) ?? fallback.red,
            green: Float(greenValue) ?? fallback.green,
            blue: Float(blueValue) ?? fallback.blue
        )
    }

    private static func format(_ value: Float) -> String {
        String(format: "%.3f", Double(value))
    }
}

private enum TouchSurfaceShape {
    case circle(radiusFraction: CGFloat)
    case annulus(innerRadiusFraction: CGFloat, outerRadiusFraction: CGFloat)
    case rectangle

    func contains(
        point: CGPoint,
        in bounds: CGRect
    ) -> Bool {
        switch self {
        case .rectangle:
            return bounds.contains(point)
        case let .circle(radiusFraction):
            let radius = min(bounds.width, bounds.height) * radiusFraction
            return distance(from: point, to: bounds.center) <= radius
        case let .annulus(innerRadiusFraction, outerRadiusFraction):
            let distance = distance(from: point, to: bounds.center)
            let minimum = min(bounds.width, bounds.height) * innerRadiusFraction
            let maximum = min(bounds.width, bounds.height) * outerRadiusFraction
            return distance >= minimum && distance <= maximum
        }
    }

    private func distance(
        from point: CGPoint,
        to center: CGPoint
    ) -> CGFloat {
        let dx = point.x - center.x
        let dy = point.y - center.y
        return sqrt((dx * dx) + (dy * dy))
    }
}

private struct ControlTouchSurface: UIViewRepresentable {
    let shape: TouchSurfaceShape
    let onEvent: (SimultaneousTouchEvent) -> Void

    func makeUIView(context: Context) -> TouchSurfaceRegionView {
        let view = TouchSurfaceRegionView()
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = true
        view.isAccessibilityElement = false
        view.accessibilityElementsHidden = true
        view.eventHandler = onEvent
        view.shape = shape
        return view
    }

    func updateUIView(_ uiView: TouchSurfaceRegionView, context: Context) {
        uiView.shape = shape
        uiView.eventHandler = onEvent
    }
}

private final class TouchSurfaceRegionView: UIView {
    var shape: TouchSurfaceShape = .rectangle
    var eventHandler: ((SimultaneousTouchEvent) -> Void)?

    private lazy var touchRecognizer: SimultaneousTouchGestureRecognizer = {
        let recognizer = SimultaneousTouchGestureRecognizer()
        recognizer.eventHandler = { [weak self] event in
            self?.eventHandler?(event)
        }
        return recognizer
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        addGestureRecognizer(touchRecognizer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        shape.contains(point: point, in: bounds)
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

extension View {
    func surfacePanelStyle(cornerRadius: CGFloat) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(red: 0.1, green: 0.12, blue: 0.16).opacity(0.9))
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    func cardStyle() -> some View {
        padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
    }
}
