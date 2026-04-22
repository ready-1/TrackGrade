import SwiftUI

struct LibraryFeatureView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var model: TrackGradeAppModel
    let device: ManagedColorBoxDevice

    @State private var isLoading = false

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
                            Text("Read-only browse of the device libraries. Upload and write semantics remain deferred on the reference firmware, but the current app can inspect the existing assets on the ColorBox.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        ForEach(sections) { section in
                            Section(section.kind.title) {
                                if section.entries.isEmpty {
                                    Text("No \(section.kind.title) entries are currently visible.")
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(section.entries) { entry in
                                        LibraryEntryRow(entry: entry)
                                    }
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
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            guard sections.isEmpty else {
                return
            }

            await refreshLibrary()
        }
    }

    private func refreshLibrary() async {
        guard isLoading == false else {
            return
        }

        isLoading = true
        await model.refreshLibrary(id: device.id)
        isLoading = false
    }
}

private struct LibraryEntryRow: View {
    let entry: ColorBoxLibraryEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.displayName)
                    .font(.headline)

                if let fileName = entry.fileName,
                   fileName.isEmpty == false {
                    Text(fileName)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)

            Text("Slot \(entry.slot)")
                .font(.caption.monospacedDigit())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.thinMaterial, in: Capsule())
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(entry.displayName)
        .accessibilityIdentifier("library-entry-\(entry.id)")
    }
}
