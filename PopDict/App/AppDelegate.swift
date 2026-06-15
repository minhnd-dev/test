import AppKit
import Combine
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var cancellables = Set<AnyCancellable>()
    private var axObserver: AXObserver?
    private var debounceWorkItem: DispatchWorkItem?
    private var lastCapturedText: String?
    private var mouseDownMonitor: Any?
    private var mouseUpMonitor: Any?
    private var mouseIsDown = false
    private var debouncePending = false

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

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(focusedAppDidChange),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

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

        guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return
        }

        guard !isSelectionInsideOwnApp() else { return }

        guard text != lastCapturedText else { return }

        lastCapturedText = text
        FloatingPanelController.shared.show(text: text)
    }

    private func isSelectionInsideOwnApp() -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        )
        guard result == .success, let focusedApp else { return false }
        var pid: pid_t = 0
        AXUIElementGetPid(focusedApp as! AXUIElement, &pid)
        return pid == ProcessInfo.processInfo.processIdentifier
    }

    private func applyTriggerMethod(_ method: TriggerMethod) {
        switch method {
        case .hotkey:
            stopTextSelectionMonitoring()
            HotkeyService.shared.register(
                keyCode: SettingsStore.shared.hotkeyKeyCode,
                modifiers: SettingsStore.shared.hotkeyModifiers
            ) { [weak self] in self?.captureText() }
        case .textSelection:
            HotkeyService.shared.unregister()
            startTextSelectionMonitoring()
        }
    }

    @objc private func focusedAppDidChange(_ notification: Notification) {
        guard SettingsStore.shared.triggerMethod == .textSelection else { return }
        startTextSelectionMonitoring()
    }

    private func startTextSelectionMonitoring() {
        guard AXIsProcessTrusted() else { return }
        stopTextSelectionMonitoring()

        let systemWide = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?
        let appResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        )
        guard appResult == .success, let focusedApp else { return }

        let appElement = focusedApp as! AXUIElement
        var pid: pid_t = 0
        AXUIElementGetPid(appElement, &pid)

        var observer: AXObserver?
        let createResult = AXObserverCreate(pid, { (_, element, _, refcon) in
            guard let refcon else { return }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
            delegate.handleSelectionChanged()
        }, &observer)

        guard createResult == .success, let observer else { return }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let addResult = AXObserverAddNotification(
            observer,
            appElement,
            kAXSelectedTextChangedNotification as CFString,
            selfPtr
        )

        guard addResult == .success else { return }

        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )
        self.axObserver = observer

        startMouseMonitors()
    }

    private func stopTextSelectionMonitoring() {
        stopMouseMonitors()
        if let observer = axObserver {
            let source = AXObserverGetRunLoopSource(observer)
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            self.axObserver = nil
        }
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
    }

    private func startMouseMonitors() {
        stopMouseMonitors()
        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            print("[AppDelegate] mouse DOWN → mouseIsDown = true")
            self?.mouseIsDown = true
        }
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            guard let self else { return }
            mouseIsDown = false
            print("[AppDelegate] mouse UP → mouseIsDown = false, tryCapture() in 150ms")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.tryCapture()
            }
        }
    }

    private func stopMouseMonitors() {
        if let monitor = mouseDownMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = mouseUpMonitor {
            NSEvent.removeMonitor(monitor)
        }
        mouseDownMonitor = nil
        mouseUpMonitor = nil
    }

    private func handleSelectionChanged() {
        debouncePending = true
        print("[AppDelegate] selection changed → debouncePending = true, timer 250ms")
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            debouncePending = false
            print("[AppDelegate] timer expired → debouncePending = false, tryCapture()")
            tryCapture()
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }

    private func tryCapture() {
        if debouncePending || mouseIsDown {
            print("[AppDelegate] tryCapture() → SKIP (debouncePending=\(debouncePending), mouseIsDown=\(mouseIsDown))")
        } else {
            print("[AppDelegate] tryCapture() → PASS (debouncePending=\(debouncePending), mouseIsDown=\(mouseIsDown))")
            captureText()
        }
    }
}
