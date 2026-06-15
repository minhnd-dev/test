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
            print("[TextCapture] AX path → \"\(text)\"")
            return text
        }
        print("[TextCapture] AX path failed → trying pasteboard")
        let text = getSelectedTextViaPasteboard()
        if let text {
            print("[TextCapture] pasteboard path → \"\(text)\"")
        } else {
            print("[TextCapture] pasteboard path → nil")
        }
        return text
    }

    private func getSelectedTextViaAX() -> String? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedApp: CFTypeRef?
        let appResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        )
        guard appResult == .success, let focusedApp else {
            print("[TextCapture] AX → no focused app")
            return nil
        }

        let appElement = focusedApp as! AXUIElement

        var focusedElement: CFTypeRef?
        let elementResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )
        guard elementResult == .success, let focusedElement else {
            print("[TextCapture] AX → no focused element")
            return nil
        }

        var selectedText: CFTypeRef?
        let textResult = AXUIElementCopyAttributeValue(
            focusedElement as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        )
        guard textResult == .success, let text = selectedText as? String, !text.isEmpty else {
            print("[TextCapture] AX → selectedText failed (result=\(textResult.rawValue))")
            return nil
        }
        return text
    }

    private func getSelectedTextViaPasteboard() -> String? {
        let pasteboard = NSPasteboard.general
        let originalString = pasteboard.string(forType: .string)
        let originalChangeCount = pasteboard.changeCount
        print("[TextCapture] pasteboard → original changeCount=\(originalChangeCount)")

        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)

        Thread.sleep(forTimeInterval: 0.15)

        let text = pasteboard.string(forType: .string)
        let textChanged = text != originalString
        print("[TextCapture] pasteboard → after Cmd+C: text=\(text ?? "nil"), changeCount=\(pasteboard.changeCount), textChanged=\(textChanged)")

        if let originalString {
            pasteboard.clearContents()
            pasteboard.setString(originalString, forType: .string)
            print("[TextCapture] pasteboard → restored original: \"\(originalString)\"")
        }

        guard let text, !text.isEmpty, textChanged else {
            return nil
        }
        return text
    }
}
