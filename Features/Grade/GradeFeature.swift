import SwiftUI

struct GradeFeatureView: View {
    @Bindable var model: TrackGradeAppModel
    let device: ManagedColorBoxDevice

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
            if let gradeControl = device.pipelineState?.gradeControl {
                LabeledContent("Lift", value: formatted(gradeControl.lift))
                LabeledContent("Gamma", value: formatted(gradeControl.gamma))
                LabeledContent("Gain", value: formatted(gradeControl.gain))
                LabeledContent("Saturation", value: formatted(gradeControl.saturation))
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

    private func formatted(_ value: Float) -> String {
        String(format: "%.2f", Double(value))
    }

    private func formatted(_ vector: ColorBoxRGBVector) -> String {
        "R \(formatted(vector.red))  G \(formatted(vector.green))  B \(formatted(vector.blue))"
    }
}

private struct DynamicGradeControlsCard: View {
    @Bindable var model: TrackGradeAppModel
    let device: ManagedColorBoxDevice

    @State private var draftGrade: ColorBoxGradeControlState
    @State private var pendingUpdateTask: Task<Void, Never>?

    init(
        model: TrackGradeAppModel,
        device: ManagedColorBoxDevice
    ) {
        self.model = model
        self.device = device
        _draftGrade = State(initialValue: device.pipelineState?.gradeControl ?? .identity)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Dynamic Grade")
                        .font(.title3.weight(.bold))
                    Text("Direct control of `lut3d_1.colorCorrector` and `procAmp.sat` on the ColorBox.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Reset Grade") {
                    draftGrade = .identity
                    pushGradeControlImmediately()
                }
                .buttonStyle(.bordered)
            }

            ScalarControlRow(
                title: "Saturation",
                value: saturationBinding,
                range: 0 ... 1.5,
                onCommit: pushGradeControlImmediately
            )

            RGBControlSection(
                title: "Lift",
                value: liftBinding,
                range: -20 ... 20,
                onCommit: pushGradeControlImmediately
            )

            RGBControlSection(
                title: "Gamma",
                value: gammaBinding,
                range: -1 ... 1,
                onCommit: pushGradeControlImmediately
            )

            RGBControlSection(
                title: "Gain",
                value: gainBinding,
                range: 0 ... 1.5,
                onCommit: pushGradeControlImmediately
            )
        }
        .cardStyle()
        .onChange(of: device.pipelineState?.gradeControl) { _, newValue in
            guard let newValue else {
                return
            }

            if newValue != draftGrade {
                draftGrade = newValue
            }
        }
        .onDisappear {
            pendingUpdateTask?.cancel()
        }
    }

    private var saturationBinding: Binding<Double> {
        Binding(
            get: { Double(draftGrade.saturation) },
            set: { newValue in
                draftGrade.saturation = Float(newValue)
                scheduleGradeControlUpdate()
            }
        )
    }

    private var liftBinding: Binding<ColorBoxRGBVector> {
        Binding(
            get: { draftGrade.lift },
            set: { newValue in
                draftGrade.lift = newValue
                scheduleGradeControlUpdate()
            }
        )
    }

    private var gammaBinding: Binding<ColorBoxRGBVector> {
        Binding(
            get: { draftGrade.gamma },
            set: { newValue in
                draftGrade.gamma = newValue
                scheduleGradeControlUpdate()
            }
        )
    }

    private var gainBinding: Binding<ColorBoxRGBVector> {
        Binding(
            get: { draftGrade.gain },
            set: { newValue in
                draftGrade.gain = newValue
                scheduleGradeControlUpdate()
            }
        )
    }

    private func scheduleGradeControlUpdate() {
        let gradeControl = draftGrade
        pendingUpdateTask?.cancel()
        pendingUpdateTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            if Task.isCancelled {
                return
            }

            await model.updateGradeControl(
                id: device.id,
                gradeControl: gradeControl
            )
        }
    }

    private func pushGradeControlImmediately() {
        pendingUpdateTask?.cancel()
        let gradeControl = draftGrade
        Task {
            await model.updateGradeControl(
                id: device.id,
                gradeControl: gradeControl
            )
        }
    }
}

private struct ScalarControlRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let onCommit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: $value,
                in: range,
                onEditingChanged: { isEditing in
                    if isEditing == false {
                        onCommit()
                    }
                }
            )
        }
    }
}

private struct RGBControlSection: View {
    let title: String
    @Binding var value: ColorBoxRGBVector
    let range: ClosedRange<Double>
    let onCommit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button("Reset") {
                    value = resetVector
                    onCommit()
                }
                .buttonStyle(.bordered)
            }

            RGBSliderRow(
                title: "Red",
                tint: .red,
                value: channelBinding(\.red),
                range: range,
                onCommit: onCommit
            )
            RGBSliderRow(
                title: "Green",
                tint: .green,
                value: channelBinding(\.green),
                range: range,
                onCommit: onCommit
            )
            RGBSliderRow(
                title: "Blue",
                tint: .blue,
                value: channelBinding(\.blue),
                range: range,
                onCommit: onCommit
            )
        }
    }

    private var resetVector: ColorBoxRGBVector {
        if range.lowerBound < 0 {
            return ColorBoxRGBVector(red: 0, green: 0, blue: 0)
        }

        return ColorBoxRGBVector(red: 1, green: 1, blue: 1)
    }

    private func channelBinding(
        _ keyPath: WritableKeyPath<ColorBoxRGBVector, Float>
    ) -> Binding<Double> {
        Binding(
            get: { Double(value[keyPath: keyPath]) },
            set: { newValue in
                value[keyPath: keyPath] = Float(newValue)
            }
        )
    }
}

private struct RGBSliderRow: View {
    let title: String
    let tint: Color
    @Binding var value: Double
    let range: ClosedRange<Double>
    let onCommit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: $value,
                in: range,
                onEditingChanged: { isEditing in
                    if isEditing == false {
                        onCommit()
                    }
                }
            )
            .tint(tint)
        }
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
