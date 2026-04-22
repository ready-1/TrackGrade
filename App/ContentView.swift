import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var appModel = TrackGradeAppModel()
    @State private var isShowingDeviceSidebar = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Group {
                    if let selectedSnapshot = appModel.selectedSnapshot {
                        GradeFeatureView(
                            model: appModel,
                            device: selectedSnapshot,
                            isShowingDeviceSidebar: isShowingDeviceSidebar,
                            toggleDeviceSidebar: {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                    isShowingDeviceSidebar.toggle()
                                }
                            }
                        )
                    } else {
                        ConnectFeatureView(model: appModel, style: .fullScreen)
                            .background(Color(uiColor: .systemGroupedBackground))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if appModel.selectedSnapshot != nil, isShowingDeviceSidebar {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                isShowingDeviceSidebar = false
                            }
                        }

                    ConnectFeatureView(
                        model: appModel,
                        style: .drawer(
                            closeAction: {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                    isShowingDeviceSidebar = false
                                }
                            }
                        )
                    )
                    .frame(width: sidebarWidth(for: proxy.size))
                    .background(Color(uiColor: .systemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .shadow(color: .black.opacity(0.16), radius: 18, y: 10)
                    .padding(.leading, 16)
                    .padding(.vertical, 16)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isShowingDeviceSidebar)
        }
        .task {
            await appModel.start(modelContext: modelContext)
        }
        .onChange(of: appModel.selectedDeviceID) { _, newValue in
            _ = newValue
            isShowingDeviceSidebar = false
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
        min(360, max(316, size.width * 0.28))
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
