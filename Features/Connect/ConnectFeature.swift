import SwiftUI

struct ConnectFeatureView: View {
    @Bindable var model: TrackGradeAppModel

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TrackGrade")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text("Touch-first control for AJA ColorBox over LAN.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Device Actions")
                        .font(.headline)

                    HStack(spacing: 10) {
                        Button {
                            model.refreshDiscovery()
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)

                        Button {
                            model.isShowingAddDeviceSheet = true
                        } label: {
                            Label("Add Device", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)

                        Button {
                            Task {
                                await model.connectSelectedDevice()
                            }
                        } label: {
                            Label("Connect", systemImage: "dot.radiowaves.left.and.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(model.selectedDeviceID == nil)
                    }
                }
                .padding(.vertical, 4)
            }

            if model.gangedPeerCount > 0 {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "link")
                            .foregroundStyle(.orange)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Gang Active")
                                .font(.headline)
                            Text("The focused device will mirror grade, bypass, false color, and preset recall to \(model.gangedPeerCount) linked peer\(model.gangedPeerCount == 1 ? "" : "s").")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 12)

                        Button("Clear") {
                            Task {
                                await model.clearGangMembership()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                if model.knownDevices.isEmpty {
                    ContentUnavailableView(
                        "No saved devices",
                        systemImage: "externaldrive.badge.questionmark",
                        description: Text("Add a ColorBox manually or save one from discovery.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(model.knownDevices) { device in
                        let snapshot = model.snapshots.first { $0.id == device.id }
                        HStack(spacing: 12) {
                            Button {
                                model.selectedDeviceID = device.id
                            } label: {
                                SavedDeviceRow(
                                    device: device,
                                    snapshot: snapshot,
                                    isSelected: model.selectedDeviceID == device.id
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("saved-device-\(device.id.uuidString)")

                            Button {
                                Task {
                                    await model.setGangMembership(
                                        deviceID: device.id,
                                        isEnabled: device.isGanged == false
                                    )
                                }
                            } label: {
                                Image(systemName: device.isGanged ? "link.circle.fill" : "link.circle")
                                    .font(.title3)
                                    .foregroundStyle(device.isGanged ? .orange : .secondary)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        Circle()
                                            .fill((device.isGanged ? Color.orange : Color.secondary).opacity(0.14))
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(device.isGanged ? "Ungang \(device.name)" : "Gang \(device.name)")
                        }
                        .swipeActions {
                            Button("Auth") {
                                model.promptForAuthentication(deviceID: device.id)
                            }
                            .tint(.blue)

                            Button("Delete", role: .destructive) {
                                Task {
                                    await model.removeDevice(id: device.id)
                                }
                            }
                        }
                    }
                }
            } header: {
                SidebarSectionHeader(title: "Saved Devices")
            }

            Section {
                if model.discoveredDevices.isEmpty {
                    Text("No Bonjour-advertised ColorBox services are visible yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.discoveredDevices) { device in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(device.serviceName)
                                    .font(.headline)
                                Text(device.address)
                                    .font(.footnote.monospaced())
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if model.knownDevices.contains(where: { $0.address == device.address }) {
                                Text("Saved")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            } else {
                                Button("Save") {
                                    Task {
                                        await model.addDiscoveredDevice(device)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                SidebarSectionHeader(title: "Discovered on LAN")
            }
        }
    }
}

struct AddDeviceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: TrackGradeAppModel

    @State private var name = ""
    @State private var address = ""
    @State private var username = "admin"
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Device") {
                    TextField("Display name", text: $name)
                    TextField("Address or IP", text: $address)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password (optional)", text: $password)
                }

                Section {
                    Text("Credentials are stored in the iPad Keychain and the device address is persisted locally.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add ColorBox")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await model.addKnownDevice(
                                name: name,
                                address: address,
                                username: username,
                                password: password
                            )
                            if model.isShowingAddDeviceSheet == false {
                                dismiss()
                            }
                        }
                    }
                    .disabled(address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct AuthenticationSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var model: TrackGradeAppModel
    let prompt: AuthenticationPrompt

    @State private var username: String
    @State private var password = ""

    init(
        model: TrackGradeAppModel,
        prompt: AuthenticationPrompt
    ) {
        self.model = model
        self.prompt = prompt
        _username = State(initialValue: prompt.username)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Credentials for \(prompt.deviceName)") {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                }

                Section {
                    Text("TrackGrade reuses these credentials whenever this ColorBox reconnects.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Update Credentials")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        model.activeAuthPrompt = nil
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await model.saveCredentials(
                                deviceID: prompt.deviceID,
                                username: username,
                                password: password
                            )
                            if model.activeAuthPrompt == nil {
                                dismiss()
                            }
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct SavedDeviceRow: View {
    let device: StoredColorBoxDevice
    let snapshot: ManagedColorBoxDevice?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "switch.2")
                .font(.title3)
                .foregroundStyle(statusColor)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline)
                Text(device.address)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                Text(statusText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(statusColor)
            }
            .accessibilityHidden(true)

            Spacer()

            if device.isGanged {
                Image(systemName: "link")
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
            }

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(device.name))
        .accessibilityValue(Text(accessibilitySummary))
        .accessibilityHint(Text(isSelected ? "Focused device." : "Focuses this device."))
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var statusText: String {
        switch snapshot?.connectionState {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting"
        case .degraded:
            return "Retrying"
        case .error:
            return "Error"
        default:
            return "Idle"
        }
    }

    private var statusColor: Color {
        switch snapshot?.connectionState {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .degraded:
            return .yellow
        case .error:
            return .red
        default:
            return .secondary
        }
    }

    private var accessibilitySummary: String {
        let selection = isSelected ? "Selected." : "Not selected."
        let gangStatus = device.isGanged ? "Ganged." : "Not ganged."
        return "\(device.address). \(statusText). \(selection) \(gangStatus)"
    }
}

private struct SidebarSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.primary)
            .textCase(nil)
    }
}
