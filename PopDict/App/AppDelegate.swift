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

    @discardableResult
    func captureText() -> Bool {
        if !TextCaptureService.shared.isAccessibilityPermissionGranted {
            print("[AppDelegate] captureText → no AX permission")
            TextCaptureService.shared.requestAccessibilityPermission()
            return false
        }

        guard let text = TextCaptureService.shared.getSelectedText(), !text.isEmpty else {
            print("[AppDelegate] captureText → no text (getSelectedText returned nil/empty)")
            lastCapturedText = nil
            return false
        }
        print("[AppDelegate] captureText → raw text: \"\(text)\"")

        guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            print("[AppDelegate] captureText → whitespace only, skip")
            return false
        }

        if isSelectionInsideOwnApp() {
            print("[AppDelegate] captureText → selection inside own app, skip")
            return false
        }

        guard text != lastCapturedText else {
            print("[AppDelegate] captureText → same text as last: \"\(text)\" == \"\(lastCapturedText ?? "")\", skip")
            return false
        }

        print("[AppDelegate] captureText → PASS, showing panel")
        lastCapturedText = text
        FloatingPanelController.shared.show(text: text)
        return true
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
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        print("[AppDelegate] focusedAppDidChange → \(app?.localizedName ?? "?") (PID \(app?.processIdentifier ?? 0))")
        guard SettingsStore.shared.triggerMethod == .textSelection else {
            print("[AppDelegate] focusedAppDidChange → ignored (trigger = \(SettingsStore.shared.triggerMethod))")
            return
        }
        startTextSelectionMonitoring()
    }

    private func startTextSelectionMonitoring() {
        guard AXIsProcessTrusted() else {
            print("[AppDelegate] startTextSelectionMonitoring → AX not trusted")
            return
        }
        stopTextSelectionMonitoring()
        startMouseMonitors()

        let systemWide = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?
        let appResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        )
        guard appResult == .success, let focusedApp else {
            print("[AppDelegate] startTextSelectionMonitoring → couldn't get focused app (mouse monitors still active)")
            return
        }

        let appElement = focusedApp as! AXUIElement
        var pid: pid_t = 0
        AXUIElementGetPid(appElement, &pid)
        let app = NSRunningApplication(processIdentifier: pid)
        print("[AppDelegate] startTextSelectionMonitoring → registering on \(app?.localizedName ?? "?") (PID \(pid))")

        var observer: AXObserver?
        let createResult = AXObserverCreate(pid, { (_, element, _, refcon) in
            guard let refcon else { return }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
            delegate.handleSelectionChanged()
        }, &observer)

        guard createResult == .success, let observer else {
            print("[AppDelegate] startTextSelectionMonitoring → AXObserverCreate failed: \(createResult)")
            return
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let addResult = AXObserverAddNotification(
            observer,
            appElement,
            kAXSelectedTextChangedNotification as CFString,
            selfPtr
        )

        if addResult != .success {
            print("[AppDelegate] startTextSelectionMonitoring → AXObserverAddNotification failed: \(addResult)")
            return
        }

        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )
        self.axObserver = observer
        print("[AppDelegate] startTextSelectionMonitoring → observer active")
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
            print("[AppDelegate] mouse UP → mouseIsDown = false, tryCapture() in 400ms")
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
