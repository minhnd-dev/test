import SwiftUI

@main
struct TestApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Capture", systemImage: "text.viewfinder") {
            Button("Capture Selected Text") {
                appDelegate.captureText()
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let textCapture = TextCaptureService.shared
    private let panelController = FloatingPanelController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !textCapture.isAccessibilityPermissionGranted {
            textCapture.requestAccessibilityPermission()
        }

        HotkeyService.shared.register { [weak self] in
            DispatchQueue.main.async {
                self?.captureText()
            }
        }
    }

    @objc func captureText() {
        guard textCapture.isAccessibilityPermissionGranted else {
            textCapture.requestAccessibilityPermission()
            return
        }

        guard let text = textCapture.getSelectedText(), !text.isEmpty else {
            panelController.show(text: "No selected text found.\n\nSelect text in any app and press ⌥⇧T again.")
            return
        }

        panelController.show(text: text)
    }
}
