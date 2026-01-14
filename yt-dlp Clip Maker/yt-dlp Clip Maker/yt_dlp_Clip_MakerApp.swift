import SwiftUI

@main
struct yt_dlp_Clip_MakerApp: App {
    @StateObject private var dependencyManager = DependencyManager()

    var body: some Scene {
        WindowGroup {
            MainView(dependencyManager: dependencyManager)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }  // Remove New Window command
        }

        Settings {
            SettingsView()
                .environmentObject(dependencyManager)
        }
    }
}

/// Root view that shows onboarding or main content based on dependency status
struct MainView: View {
    @ObservedObject var dependencyManager: DependencyManager
    @State private var viewModel: ClipViewModel?
    @State private var hasCheckedDependencies = false

    init(dependencyManager: DependencyManager) {
        self.dependencyManager = dependencyManager
    }

    var body: some View {
        Group {
            if !hasCheckedDependencies {
                loadingView
            } else if dependencyManager.allDependenciesReady {
                if let viewModel = viewModel {
                    ContentView(viewModel: viewModel)
                } else {
                    loadingView
                }
            } else {
                OnboardingView(dependencyManager: dependencyManager)
            }
        }
        .task {
            await dependencyManager.checkDependencies()
            hasCheckedDependencies = true

            if dependencyManager.allDependenciesReady {
                createViewModel()
            }
        }
        .onChange(of: dependencyManager.allDependenciesReady) { _, ready in
            if ready && viewModel == nil {
                createViewModel()
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading...")
                .foregroundColor(.secondary)
        }
        .frame(width: 400, height: 300)
    }

    private func createViewModel() {
        let clipService = ClipService(dependencyManager: dependencyManager)
        viewModel = ClipViewModel(clipService: clipService)
    }
}
