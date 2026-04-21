import SwiftUI
import UIKit

struct GradeFeatureView: View {
    @Bindable var model: TrackGradeAppModel
    let device: ManagedColorBoxDevice

    @State private var isShowingSettings = false
    @AppStorage(TrackGradeSettingsKey.hapticsEnabled) private var hapticsEnabled = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                deviceSummaryCard
                actionCard
                gradeCard
                toggleCard
                previewCard
                PresetsFeatureView(
                    model: model,
                    device: device
                )
            }
            .padding(24)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(device.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    emitButtonHaptic()
                    isShowingSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape.fill")
                }
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsFeatureView(deviceName: device.name)
        }
    }

    private var deviceSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Device State")
                .font(.title3.weight(.bold))

            LabeledContent("Address", value: device.address)
            LabeledContent("Connection", value: device.connectionState.rawValue.capitalized)
            if let productName = device.systemInfo?.productName {
                LabeledContent("Product", value: productName)
            }
            if let serialNumber = device.systemInfo?.serialNumber {
                LabeledContent("Serial", value: serialNumber)
            }
            if let firmwareVersion = device.firmwareInfo?.version {
                LabeledContent("Firmware", value: firmwareVersion)
            }
            if let dynamicLUTMode = device.pipelineState?.dynamicLUTMode {
                LabeledContent("3D LUT Node", value: dynamicLUTMode.capitalized)
            }
            LabeledContent("Preview", value: "\(device.previewByteCount) bytes")
        }
        .cardStyle()
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connection")
                .font(.title3.weight(.bold))

            HStack(spacing: 12) {
                Button("Connect") {
                    Task {
                        await model.connect(to: device.id)
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Refresh") {
                    Task {
                        await model.refreshDevice(id: device.id)
                    }
                }
                .buttonStyle(.bordered)

                Button("Preview") {
                    Task {
                        await model.refreshPreview(id: device.id)
                    }
                }
                .buttonStyle(.bordered)

                Button("Auth") {
                    model.promptForAuthentication(deviceID: device.id)
                }
                .buttonStyle(.bordered)
            }

            Button("Configure Node 4 as Dynamic 3D LUT") {
                Task {
                    await model.configurePipeline(id: device.id)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .cardStyle()
    }

    private var gradeCard: some View {
        DynamicGradeControlsCard(
            model: model,
            device: device
        )
    }

    private var toggleCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pipeline Toggles")
                .font(.title3.weight(.bold))

            Toggle(
                "Bypass",
                isOn: Binding(
                    get: { device.pipelineState?.bypassEnabled ?? false },
                    set: { isEnabled in
                        emitButtonHaptic()
                        Task {
                            await model.setBypass(
                                id: device.id,
                                enabled: isEnabled
                            )
                        }
                    }
                )
            )

            Toggle(
                "False Color",
                isOn: Binding(
                    get: { device.pipelineState?.falseColorEnabled ?? false },
                    set: { isEnabled in
                        emitButtonHaptic()
                        Task {
                            await model.setFalseColor(
                                id: device.id,
                                enabled: isEnabled
                            )
                        }
                    }
                )
            )
            .disabled(device.supportsFalseColor == false)

            if device.supportsFalseColor == false {
                Text(falseColorUnsupportedMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preview")
                .font(.title3.weight(.bold))

            PreviewFeatureView(
                imageData: device.previewFrameData,
                byteCount: device.previewByteCount
            )
        }
        .cardStyle()
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

    @State private var draftGrade: ColorBoxGradeControlState
    @State private var liftState: ColorBoxTrackballState
    @State private var gammaState: ColorBoxTrackballState
    @State private var gainState: ColorBoxTrackballState
    @State private var pendingUpdateTask: Task<Void, Never>?
    @State private var activeEditor: GradeEditorTarget?

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
    @AppStorage(TrackGradeSettingsKey.resetRequiresConfirmation) private var resetRequiresConfirmation = true

    init(
        model: TrackGradeAppModel,
        device: ManagedColorBoxDevice
    ) {
        self.model = model
        self.device = device

        let initialGrade = device.pipelineState?.gradeControl ?? .identity
        _draftGrade = State(initialValue: initialGrade)
        _liftState = State(initialValue: ColorBoxTrackballMapping.state(for: initialGrade.lift, kind: .lift))
        _gammaState = State(initialValue: ColorBoxTrackballMapping.state(for: initialGrade.gamma, kind: .gamma))
        _gainState = State(initialValue: ColorBoxTrackballMapping.state(for: initialGrade.gain, kind: .gain))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Control Surface")
                        .font(.title3.weight(.bold))
                    Text("Trackball, ring, and roller gestures drive the current `pipelineStages` grading path directly.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                DoubleTapActionChip(
                    title: "Reset All",
                    tint: .orange,
                    requiresExplicitLabel: resetRequiresConfirmation
                ) {
                    emitButtonHaptic()
                    draftGrade = .identity
                    syncSurfaceStates(from: .identity)
                    pushGradeControlImmediately(successHaptic: true)
                }
            }

            GradeStateDisplay(
                grade: draftGrade,
                previewFrameData: device.previewFrameData,
                onEdit: { target in
                    activeEditor = target
                },
                onRefreshPreview: {
                    Task {
                        await model.refreshPreview(id: device.id)
                    }
                }
            )

            HStack(alignment: .top, spacing: 20) {
                TrackballClusterView(
                    title: "Lift",
                    kind: .lift,
                    state: $liftState,
                    renderedVector: draftGrade.lift,
                    ballSensitivity: liftBallSensitivity,
                    ringSensitivity: liftRingSensitivity,
                    onBallEvent: handleLiftBall,
                    onRingEvent: handleLiftRing,
                    onResetBall: {
                        emitButtonHaptic()
                        liftState.ball = .zero
                        updateGradeFromSurfaceStates(pushImmediately: true, successHaptic: true)
                    },
                    onResetRing: {
                        emitButtonHaptic()
                        liftState.ring = 0
                        updateGradeFromSurfaceStates(pushImmediately: true, successHaptic: true)
                    }
                )

                TrackballClusterView(
                    title: "Gamma",
                    kind: .gamma,
                    state: $gammaState,
                    renderedVector: draftGrade.gamma,
                    ballSensitivity: gammaBallSensitivity,
                    ringSensitivity: gammaRingSensitivity,
                    onBallEvent: handleGammaBall,
                    onRingEvent: handleGammaRing,
                    onResetBall: {
                        emitButtonHaptic()
                        gammaState.ball = .zero
                        updateGradeFromSurfaceStates(pushImmediately: true, successHaptic: true)
                    },
                    onResetRing: {
                        emitButtonHaptic()
                        gammaState.ring = 0
                        updateGradeFromSurfaceStates(pushImmediately: true, successHaptic: true)
                    }
                )

                TrackballClusterView(
                    title: "Gain",
                    kind: .gain,
                    state: $gainState,
                    renderedVector: draftGrade.gain,
                    ballSensitivity: gainBallSensitivity,
                    ringSensitivity: gainRingSensitivity,
                    onBallEvent: handleGainBall,
                    onRingEvent: handleGainRing,
                    onResetBall: {
                        emitButtonHaptic()
                        gainState.ball = .zero
                        updateGradeFromSurfaceStates(pushImmediately: true, successHaptic: true)
                    },
                    onResetRing: {
                        emitButtonHaptic()
                        gainState.ring = 0
                        updateGradeFromSurfaceStates(pushImmediately: true, successHaptic: true)
                    }
                )
            }

            SaturationRollerView(
                value: Double(draftGrade.saturation),
                sensitivity: saturationSensitivity,
                onEvent: handleSaturationEvent,
                onReset: {
                    emitButtonHaptic()
                    draftGrade.saturation = 1
                    pushGradeControlImmediately(successHaptic: true)
                }
            )
        }
        .cardStyle()
        .sheet(item: $activeEditor) { target in
            NumericGradeEditorSheet(
                target: target,
                grade: draftGrade,
                onSave: { updatedGrade in
                    draftGrade = updatedGrade
                    syncSurfaceStates(from: updatedGrade)
                    pushGradeControlImmediately()
                }
            )
        }
        .onChange(of: device.pipelineState?.gradeControl) { _, newValue in
            guard let newValue else {
                return
            }

            if newValue != draftGrade {
                draftGrade = newValue
                syncSurfaceStates(from: newValue)
            }
        }
        .onDisappear {
            pendingUpdateTask?.cancel()
        }
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
        }
    }

    private func handleSaturationEvent(
        event: SimultaneousTouchEvent,
        size: CGSize
    ) {
        switch event {
        case .began:
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

        case .cancelled:
            saturationAnchor = nil
            pushGradeControlImmediately()
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

private struct GradeStateDisplay: View {
    let grade: ColorBoxGradeControlState
    let previewFrameData: Data?
    let onEdit: (GradeEditorTarget) -> Void
    let onRefreshPreview: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 14) {
                Text("State Display")
                    .font(.headline.weight(.semibold))

                NumericDisplayRow(
                    label: "Lift",
                    value: formatted(grade.lift),
                    action: { onEdit(.lift) }
                )

                NumericDisplayRow(
                    label: "Gamma",
                    value: formatted(grade.gamma),
                    action: { onEdit(.gamma) }
                )

                NumericDisplayRow(
                    label: "Gain",
                    value: formatted(grade.gain),
                    action: { onEdit(.gain) }
                )

                NumericDisplayRow(
                    label: "Sat",
                    value: formatted(grade.saturation),
                    action: { onEdit(.saturation) }
                )

                Text("Tap any row to edit values numerically.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            PreviewThumbnail(
                imageData: previewFrameData,
                refreshAction: onRefreshPreview
            )
            .frame(width: 140, height: 92)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.92))
        )
    }

    private func formatted(_ value: Float) -> String {
        String(format: "%.2f", Double(value))
    }

    private func formatted(_ vector: ColorBoxRGBVector) -> String {
        "R \(formatted(vector.red))  G \(formatted(vector.green))  B \(formatted(vector.blue))"
    }
}

private struct NumericDisplayRow: View {
    let label: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))

                Spacer()

                Text(value)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct PreviewThumbnail: View {
    let imageData: Data?
    let refreshAction: () -> Void

    var body: some View {
        Button(action: refreshAction) {
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
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottomTrailing) {
            Text("Hold to refresh")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(8)
        }
        .onLongPressGesture(perform: refreshAction)
    }
}

private struct TrackballClusterView: View {
    let title: String
    let kind: TrackballSurfaceKind
    @Binding var state: ColorBoxTrackballState
    let renderedVector: ColorBoxRGBVector
    let ballSensitivity: Double
    let ringSensitivity: Double
    let onBallEvent: (SimultaneousTouchEvent, CGSize) -> Void
    let onRingEvent: (SimultaneousTouchEvent, CGSize) -> Void
    let onResetBall: () -> Void
    let onResetRing: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline.weight(.semibold))
                Spacer()
                Text("B \(ballSensitivity, specifier: "%.2fx")  R \(ringSensitivity, specifier: "%.2fx")")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
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
            .frame(minHeight: 220)

            HStack(spacing: 10) {
                DoubleTapActionChip(
                    title: "Reset Ball",
                    tint: .cyan,
                    requiresExplicitLabel: true,
                    action: onResetBall
                )

                DoubleTapActionChip(
                    title: "Reset Ring",
                    tint: .mint,
                    requiresExplicitLabel: true,
                    action: onResetRing
                )
            }
        }
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Saturation")
                    .font(.headline.weight(.semibold))
                Spacer()
                Text("\(sensitivity, specifier: "%.2fx")")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(String(format: "%.2f", value))
                    .font(.body.monospacedDigit())
            }

            GeometryReader { proxy in
                let size = proxy.size
                let progress = CGFloat((value / 2).clamped(to: 0 ... 1))

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.black.opacity(0.08))

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
            .frame(height: 84)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Saturation roller"))
            .accessibilityIdentifier("saturation-roller")

            HStack {
                Text("0.00")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                DoubleTapActionChip(
                    title: "Reset To 1.00",
                    tint: .yellow,
                    requiresExplicitLabel: true,
                    action: onReset
                )
                Spacer()
                Text("2.00")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct DoubleTapActionChip: View {
    let title: String
    let tint: Color
    let requiresExplicitLabel: Bool
    let action: () -> Void

    var body: some View {
        Text(requiresExplicitLabel ? "\(title) (double-tap)" : title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            )
            .contentShape(Capsule())
            .onTapGesture(count: 2, perform: action)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Double-tap to \(title.lowercased()).")
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
                        numericField("Saturation", text: $scalarValue)
                    }
                case .lift, .gamma, .gain:
                    Section("RGB") {
                        numericField("Red", text: $redValue)
                        numericField("Green", text: $greenValue)
                        numericField("Blue", text: $blueValue)
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
        text: Binding<String>
    ) -> some View {
        TextField(label, text: text)
            .keyboardType(.numbersAndPunctuation)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
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
    func cardStyle() -> some View {
        padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
    }
}
