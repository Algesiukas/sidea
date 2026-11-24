import SwiftUI

@main
struct SideAApp: App {
    @State private var library = LibraryStore()
    @State private var player = PlayerEngine()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environment(library)
                .environment(player)
                .preferredColorScheme(.light)
                .tint(Theme.red)
        }
        .onChange(of: scenePhase) { _, phase in
            // Pick up files added through the Files app or Finder while we were away.
            if phase == .active {
                Task { await library.reload() }
            }
        }
    }
}
