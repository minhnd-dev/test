import SwiftUI

@main
struct PopDictApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("PopDict", systemImage: "text.viewfinder") {
            Button("Capture Selected Text") { appDelegate.captureText() }
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
