import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var appModel = TrackGradeAppModel()

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                ConnectFeatureView(model: appModel)
                    .frame(width: sidebarWidth(for: proxy.size))
                    .background(Color(uiColor: .systemGroupedBackground))

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1)

                Group {
                    if let selectedSnapshot = appModel.selectedSnapshot {
                        GradeFeatureView(
                            model: appModel,
                            device: selectedSnapshot
                        )
                    } else {
                        ContentUnavailableView(
                            "TrackGrade",
                            systemImage: "dial.medium",
                            description: Text("Add an AJA ColorBox by IP or select a discovered device to begin.")
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await appModel.start(modelContext: modelContext)
        }
        .sheet(isPresented: addDeviceSheetBinding) {
            AddDeviceSheet(model: appModel)
        }
        .sheet(item: authPromptBinding) { prompt in
            AuthenticationSheet(
                model: appModel,
                prompt: prompt
            )
        }
        .safeAreaInset(edge: .top) {
            if let bannerMessage = appModel.visibleConnectionBanner,
               let selectedDeviceID = appModel.selectedDeviceID {
                ConnectionBannerView(
                    message: bannerMessage,
                    retryAction: {
                        Task {
                            await appModel.retryConnection(for: selectedDeviceID)
                        }
                    },
                    dismissAction: {
                        appModel.dismissConnectionBanner()
                    }
                )
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
        }
        .alert(
            "TrackGrade",
            isPresented: errorAlertBinding,
            actions: {
                Button("OK", role: .cancel) {
                    appModel.errorMessage = nil
                }
            },
            message: {
                Text(appModel.errorMessage ?? "")
            }
        )
    }

    private var addDeviceSheetBinding: Binding<Bool> {
        Binding(
            get: { appModel.isShowingAddDeviceSheet },
            set: { isPresented in
                appModel.isShowingAddDeviceSheet = isPresented
            }
        )
    }

    private var authPromptBinding: Binding<AuthenticationPrompt?> {
        Binding(
            get: { appModel.activeAuthPrompt },
            set: { prompt in
                appModel.activeAuthPrompt = prompt
            }
        )
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { appModel.errorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    appModel.errorMessage = nil
                }
            }
        )
    }

    private func sidebarWidth(for size: CGSize) -> CGFloat {
        min(340, max(300, size.width * 0.28))
    }
}

#Preview {
    ContentView()
}

private struct ConnectionBannerView: View {
    let message: String
    let retryAction: () -> Void
    let dismissAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .imageScale(.large)
                .foregroundStyle(.white)

            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Retry", action: retryAction)
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.2))

            Button("Dismiss", action: dismissAction)
                .buttonStyle(.borderless)
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.orange.gradient)
        )
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
    }
}
