import SwiftUI

struct GradeFeatureView: View {
    @Bindable var model: TrackGradeAppModel
    let device: ManagedColorBoxDevice

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                deviceSummaryCard
                actionCard
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
