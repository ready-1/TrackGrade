import SwiftUI
import UniformTypeIdentifiers

struct LibraryFeatureView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var model: TrackGradeAppModel
    let device: ManagedColorBoxDevice

    @State private var isLoading = false
    @State private var importTarget: LibraryImportTarget?
    @State private var renameTarget: ColorBoxLibraryEntry?
    @State private var renameDraft = ""
    @State private var deleteTarget: ColorBoxLibraryEntry?

    private var sections: [ColorBoxLibrarySection] {
        model.librarySections(for: device.id)
    }

    var body: some View {
        NavigationStack {
            Group {
                if sections.isEmpty, isLoading {
                    ProgressView("Loading Library")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("ColorBox library slots are shown exactly by slot number. Import is enabled for 1D LUT, 3D LUT, Matrix, Image, and Overlay assets in this build.")
                                Text("AMF import now uses the ColorBox multi-file `/v2/uploadMultiple` path. Select the `.amf` file and any companion files together so the device stores the intended package.")
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("library-management-note")
                        }

                        ForEach(sections) { section in
                            Section {
                                ForEach(section.entries) { entry in
                                    LibraryEntryRow(
                                        entry: entry,
                                        onImport: entry.kind.supportsImport ? {
                                            importTarget = LibraryImportTarget(
                                                kind: entry.kind,
                                                slot: entry.slot
                                            )
                                        } : nil,
                                        onRename: entry.isEmpty ? nil : {
                                            renameDraft = entry.userName ?? entry.displayName
                                            renameTarget = entry
                                        },
                                        onDelete: entry.isEmpty ? nil : {
                                            deleteTarget = entry
                                        }
                                    )
                                }
                            } header: {
                                HStack {
                                    Text(section.kind.title)
                                    Spacer()
                                    if section.kind.supportsImport {
                                        Text("16 Slots")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            } footer: {
                                if section.kind == .amf {
                                    Text("Choose the `.amf` file plus any companion files. TrackGrade uses the selected `.amf` file as the AMF package entry.")
                                }
                            }
                            .accessibilityIdentifier("library-section-\(section.kind.id)")
                        }
                    }
                    .accessibilityIdentifier("library-list")
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Refresh") {
                        Task {
                            await refreshLibrary()
                        }
                    }
                    .disabled(isLoading)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .fileImporter(
            isPresented: isImportingBinding,
            allowedContentTypes: [.data],
            allowsMultipleSelection: importTarget?.kind.requiresMultipleImportFiles ?? false
        ) { result in
            guard let target = importTarget else {
                return
            }
            importTarget = nil

            switch result {
            case let .success(urls):
                guard urls.isEmpty == false else {
                    return
                }
                Task {
                    await performMutation {
                        await model.importLibraryAssets(
                            id: device.id,
                            kind: target.kind,
                            slot: target.slot,
                            from: urls
                        )
                    }
                }
            case .failure:
                break
            }
        }
        .alert(
            "Rename Asset",
            isPresented: isRenamingBinding
        ) {
            TextField("Name", text: $renameDraft)
                .accessibilityIdentifier("library-rename-field")
            Button("Cancel", role: .cancel) {
                renameTarget = nil
            }
            Button("Rename") {
                guard let target = renameTarget else {
                    return
                }
                let trimmedName = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                renameTarget = nil
                Task {
                    await performMutation {
                        await model.renameLibraryEntry(
                            id: device.id,
                            kind: target.kind,
                            slot: target.slot,
                            name: trimmedName
                        )
                    }
                }
            }
        } message: {
            if let renameTarget {
                Text("Update the device-visible name for slot \(renameTarget.slot).")
            }
        }
        .confirmationDialog(
            "Delete Asset",
            isPresented: isDeletingBinding,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let target = deleteTarget else {
                    return
                }
                deleteTarget = nil
                Task {
                    await performMutation {
                        await model.deleteLibraryEntry(
                            id: device.id,
                            kind: target.kind,
                            slot: target.slot
                        )
                    }
                }
            }

            Button("Cancel", role: .cancel) {
                deleteTarget = nil
            }
        } message: {
            if let deleteTarget {
                Text("Delete \(deleteTarget.displayName) from slot \(deleteTarget.slot)?")
            }
        }
        .task {
            guard sections.isEmpty else {
                return
            }

            await refreshLibrary()
        }
    }

    private var isImportingBinding: Binding<Bool> {
        Binding(
            get: { importTarget != nil },
            set: { isPresented in
                if isPresented == false {
                    importTarget = nil
                }
            }
        )
    }

    private var isRenamingBinding: Binding<Bool> {
        Binding(
            get: { renameTarget != nil },
            set: { isPresented in
                if isPresented == false {
                    renameTarget = nil
                }
            }
        )
    }

    private var isDeletingBinding: Binding<Bool> {
        Binding(
            get: { deleteTarget != nil },
            set: { isPresented in
                if isPresented == false {
                    deleteTarget = nil
                }
            }
        )
    }

    private func refreshLibrary() async {
        await performMutation {
            await model.refreshLibrary(id: device.id)
        }
    }

    private func performMutation(
        _ operation: @escaping () async -> Void
    ) async {
        guard isLoading == false else {
            return
        }

        isLoading = true
        await operation()
        isLoading = false
    }
}

private struct LibraryImportTarget: Identifiable {
    let kind: ColorBoxLibraryKind
    let slot: Int

    var id: String {
        "\(kind.id)-\(slot)"
    }
}

private struct LibraryEntryRow: View {
    let entry: ColorBoxLibraryEntry
    let onImport: (() -> Void)?
    let onRename: (() -> Void)?
    let onDelete: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(primaryText)
                    .font(.headline)
                    .foregroundStyle(entry.isEmpty ? .secondary : .primary)

                Text(secondaryText)
                    .font(entry.isEmpty ? .caption : .caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 8) {
                Text("Slot \(entry.slot)")
                    .font(.caption.monospacedDigit())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())

                if let onImport, entry.isEmpty {
                    Button("Import", action: onImport)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .accessibilityIdentifier("library-import-\(entry.id)")
                } else if onImport != nil || onRename != nil || onDelete != nil {
                    Menu {
                        if let onImport {
                            Button(entry.isEmpty ? "Import" : "Replace", action: onImport)
                        }

                        if let onRename {
                            Button("Rename", action: onRename)
                        }

                        if let onDelete {
                            Button("Delete", role: .destructive, action: onDelete)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                    .accessibilityIdentifier("library-actions-\(entry.id)")
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("library-entry-\(entry.id)")
    }

    private var primaryText: String {
        entry.isEmpty ? "Empty Slot" : entry.displayName
    }

    private var secondaryText: String {
        if let fileName = entry.fileName,
           fileName.isEmpty == false {
            return fileName
        }

        if entry.isEmpty {
            return entry.kind.supportsImport
                ? "Ready for import"
                : "Browse-only in this build"
        }

        return entry.kind.title
    }

    private var accessibilityLabel: String {
        if entry.isEmpty {
            return "\(entry.kind.title) slot \(entry.slot), empty"
        }

        return "\(entry.displayName), slot \(entry.slot)"
    }
}
