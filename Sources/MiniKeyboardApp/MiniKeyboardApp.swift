import SwiftUI

@main
struct MiniKeyboardApp: App {
  var body: some Scene {
    WindowGroup("Mini Keyboard Studio") {
      ContentView()
    }
    .defaultSize(width: 1080, height: 760)
    .windowResizability(.contentMinSize)
  }
}
