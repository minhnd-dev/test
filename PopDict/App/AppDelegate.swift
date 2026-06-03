import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var cancellables = Set<AnyCancellable>()
    private var mouseUpMonitor: Any?
    private var lastCapturedText: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !TextCaptureService.shared.isAccessibilityPermissionGranted {
            TextCaptureService.shared.requestAccessibilityPermission()
        }

        SettingsStore.shared.$triggerMethod
            .sink { [weak self] method in
                self?.applyTriggerMethod(method)
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(
            SettingsStore.shared.$hotkeyKeyCode,
            SettingsStore.shared.$hotkeyModifiers
        )
        .dropFirst()
        .removeDuplicates { $0.0 == $1.0 && $0.1 == $1.1 }
        .sink { [weak self] _, _ in
            guard let self, SettingsStore.shared.triggerMethod == .hotkey else { return }
            HotkeyService.shared.register(
                keyCode: SettingsStore.shared.hotkeyKeyCode,
                modifiers: SettingsStore.shared.hotkeyModifiers
            ) { [weak self] in self?.captureText() }
        }
        .store(in: &cancellables)

        applyTriggerMethod(SettingsStore.shared.triggerMethod)
    }

    func captureText() {
        if !TextCaptureService.shared.isAccessibilityPermissionGranted {
            TextCaptureService.shared.requestAccessibilityPermission()
            return
        }

        guard let text = TextCaptureService.shared.getSelectedText(), !text.isEmpty else {
            lastCapturedText = nil
            return
        }

        guard text != lastCapturedText else { return }

        lastCapturedText = text
        FloatingPanelController.shared.show(text: text)
    }

    private func applyTriggerMethod(_ method: TriggerMethod) {
        switch method {
        case .hotkey:
            stopMouseMonitoring()
            HotkeyService.shared.register(
                keyCode: SettingsStore.shared.hotkeyKeyCode,
                modifiers: SettingsStore.shared.hotkeyModifiers
            ) { [weak self] in self?.captureText() }
        case .textSelection:
            HotkeyService.shared.unregister()
            startMouseMonitoring()
        }
    }

    private func startMouseMonitoring() {
        stopMouseMonitoring()
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            self?.captureText()
        }
    }

    private func stopMouseMonitoring() {
        if let monitor = mouseUpMonitor {
            NSEvent.removeMonitor(monitor)
        }
        mouseUpMonitor = nil
    }
}
