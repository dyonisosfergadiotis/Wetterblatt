import SwiftUI

@main
struct Weather_AppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var appModel: AppModel

    init() {
        let container = AppContainer()
        _appModel = State(initialValue: container.makeAppModel())
    }

    var body: some Scene {
        WindowGroup {
            AppShellView(model: appModel)
                .task {
                    await appModel.start()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            Task {
                await appModel.handleScenePhase(newPhase)
            }
        }
    }
}
