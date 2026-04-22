import SwiftUI

enum TrackGradeSettingsKey {
    static let liftBallSensitivity = "trackgrade.settings.liftBallSensitivity"
    static let liftRingSensitivity = "trackgrade.settings.liftRingSensitivity"
    static let gammaBallSensitivity = "trackgrade.settings.gammaBallSensitivity"
    static let gammaRingSensitivity = "trackgrade.settings.gammaRingSensitivity"
    static let gainBallSensitivity = "trackgrade.settings.gainBallSensitivity"
    static let gainRingSensitivity = "trackgrade.settings.gainRingSensitivity"
    static let saturationSensitivity = "trackgrade.settings.saturationSensitivity"
    static let hapticsEnabled = "trackgrade.settings.hapticsEnabled"
    static let autoRefreshInterval = "trackgrade.settings.autoRefreshInterval"
    static let resetRequiresConfirmation = "trackgrade.settings.resetRequiresConfirmation"
}

struct TrackGradeControlSensitivity {
    let liftBall: Double
    let liftRing: Double
    let gammaBall: Double
    let gammaRing: Double
    let gainBall: Double
    let gainRing: Double
    let saturation: Double

    static let `default` = TrackGradeControlSensitivity(
        liftBall: 1,
        liftRing: 1,
        gammaBall: 1,
        gammaRing: 1,
        gainBall: 1,
        gainRing: 1,
        saturation: 1
    )
}

extension TrackGradeControlSensitivity {
    static func load(from defaults: UserDefaults = .standard) -> TrackGradeControlSensitivity {
        TrackGradeControlSensitivity(
            liftBall: resolvedValue(for: TrackGradeSettingsKey.liftBallSensitivity, defaults: defaults),
            liftRing: resolvedValue(for: TrackGradeSettingsKey.liftRingSensitivity, defaults: defaults),
            gammaBall: resolvedValue(for: TrackGradeSettingsKey.gammaBallSensitivity, defaults: defaults),
            gammaRing: resolvedValue(for: TrackGradeSettingsKey.gammaRingSensitivity, defaults: defaults),
            gainBall: resolvedValue(for: TrackGradeSettingsKey.gainBallSensitivity, defaults: defaults),
            gainRing: resolvedValue(for: TrackGradeSettingsKey.gainRingSensitivity, defaults: defaults),
            saturation: resolvedValue(for: TrackGradeSettingsKey.saturationSensitivity, defaults: defaults)
        )
    }

    private static func resolvedValue(
        for key: String,
        defaults: UserDefaults
    ) -> Double {
        let value = defaults.object(forKey: key) as? Double ?? 1
        return value == 0 ? 1 : value
    }
}

struct SettingsFeatureView: View {
    let deviceName: String

    @Environment(\.dismiss) private var dismiss

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

    var body: some View {
        NavigationStack {
            Form {
                Section("Device") {
                    LabeledContent("Focused Device", value: deviceName)
                    LabeledContent("Working Color Space", value: "Rec.709 SDR")
                    LabeledContent("LUT Resolution", value: "33³")
                }

                Section("Sensitivity") {
                    sensitivityRow("Lift Ball", value: $liftBallSensitivity)
                    sensitivityRow("Lift Ring", value: $liftRingSensitivity)
                    sensitivityRow("Gamma Ball", value: $gammaBallSensitivity)
                    sensitivityRow("Gamma Ring", value: $gammaRingSensitivity)
                    sensitivityRow("Gain Ball", value: $gainBallSensitivity)
                    sensitivityRow("Gain Ring", value: $gainRingSensitivity)
                    sensitivityRow("Saturation", value: $saturationSensitivity)
                }

                Section("Behavior") {
                    Toggle("Haptics Enabled", isOn: $hapticsEnabled)
                    Toggle("Reset Confirmation Required", isOn: $resetRequiresConfirmation)

                    Picker(
                        "Preview Auto Refresh",
                        selection: $autoRefreshInterval
                    ) {
                        Text("Off").tag(0.0)
                        Text("1s").tag(1.0)
                        Text("5s").tag(5.0)
                        Text("10s").tag(10.0)
                    }
                }

                Section("Diagnostics") {
                    Text("The current build centers on the touch surface, workflow drawer, and live ColorBox grading path. Device auth remains optional on the reference hardware, and gang control is now managed from the device list.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("About") {
                    LabeledContent("App", value: "TrackGrade")
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("License", value: "Apache License 2.0")

                    Link(
                        "Project Repository",
                        destination: URL(string: "https://github.com/ready-1/TrackGrade")!
                    )

                    Link(
                        "Code of Conduct Contact",
                        destination: URL(string: "mailto:info@getready1.com")!
                    )

                    Text("TrackGrade is not affiliated with or endorsed by AJA Video Systems. AJA and ColorBox are trademarks of AJA Video Systems.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var appVersion: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (shortVersion, build) {
        case let (shortVersion?, build?) where shortVersion.isEmpty == false && build.isEmpty == false:
            return "\(shortVersion) (\(build))"
        case let (shortVersion?, _):
            return shortVersion
        case let (_, build?):
            return build
        default:
            return "Development"
        }
    }

    private func sensitivityRow(
        _ title: String,
        value: Binding<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.2fx", value.wrappedValue))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: value,
                in: 0.25 ... 4.0
            )
        }
        .padding(.vertical, 4)
    }
}
