import SwiftUI

@main
struct LyricBridgeApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Lyric Bridge") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 380, minHeight: 560)
                .onAppear { model.start() }
        }
        .windowResizability(.contentSize)
    }
}
