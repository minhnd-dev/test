import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if !TextCaptureService.shared.isAccessibilityPermissionGranted {
            TextCaptureService.shared.requestAccessibilityPermission()
        }

        HotkeyService.shared.register { [weak self] in
            self?.captureText()
        }
    }

    func captureText() {
        if !TextCaptureService.shared.isAccessibilityPermissionGranted {
            TextCaptureService.shared.requestAccessibilityPermission()
            return
        }

        guard let text = TextCaptureService.shared.getSelectedText(), !text.isEmpty else {
            return
        }

        FloatingPanelController.shared.show(text: text)
    }
}
