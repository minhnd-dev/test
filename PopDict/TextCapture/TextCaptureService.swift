import AppKit
import ApplicationServices

final class TextCaptureService {
    static let shared = TextCaptureService()

    var isAccessibilityPermissionGranted: Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    func getSelectedText() -> String? {
        if let text = getSelectedTextViaAX(), !text.isEmpty {
            return text
        }
        return getSelectedTextViaPasteboard()
    }

    private func getSelectedTextViaAX() -> String? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedApp: CFTypeRef?
        let appResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        )
        guard appResult == .success, let focusedApp else { return nil }

        let appElement = focusedApp as! AXUIElement

        var focusedElement: CFTypeRef?
        let elementResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )
        guard elementResult == .success, let focusedElement else { return nil }

        var selectedText: CFTypeRef?
        let textResult = AXUIElementCopyAttributeValue(
            focusedElement as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        )
        guard textResult == .success, let text = selectedText as? String, !text.isEmpty else {
            return nil
        }
        return text
    }

    private func getSelectedTextViaPasteboard() -> String? {
        let pasteboard = NSPasteboard.general
        let originalString = pasteboard.string(forType: .string)
        let originalChangeCount = pasteboard.changeCount

        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        Thread.sleep(forTimeInterval: 0.1)

        let text = pasteboard.string(forType: .string)
        let pasteboardDidChange = pasteboard.changeCount != originalChangeCount

        if let originalString {
            pasteboard.clearContents()
            pasteboard.setString(originalString, forType: .string)
        }

        guard let text, !text.isEmpty, pasteboardDidChange else {
            return nil
        }
        return text
    }
}
