import AppKit
import Carbon
import Combine

enum TriggerMethod: String, CaseIterable, Codable {
    case hotkey
    case textSelection
}

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var triggerMethod: TriggerMethod

    @Published var hotkeyKeyCode: Int

    @Published var hotkeyModifiers: Int

    private init() {
        let defaults = UserDefaults.standard
        triggerMethod = TriggerMethod(rawValue: defaults.string(forKey: "triggerMethod") ?? "") ?? .hotkey
        hotkeyKeyCode = defaults.object(forKey: "hotkeyKeyCode") as? Int ?? Int(kVK_ANSI_T)
        hotkeyModifiers = defaults.object(forKey: "hotkeyModifiers") as? Int ?? (Int(optionKey) | Int(shiftKey))
    }

    func commit() {
        let defaults = UserDefaults.standard
        defaults.set(triggerMethod.rawValue, forKey: "triggerMethod")
        defaults.set(hotkeyKeyCode, forKey: "hotkeyKeyCode")
        defaults.set(hotkeyModifiers, forKey: "hotkeyModifiers")
    }

    func discard() {
        let defaults = UserDefaults.standard
        triggerMethod = TriggerMethod(rawValue: defaults.string(forKey: "triggerMethod") ?? "") ?? .hotkey
        hotkeyKeyCode = defaults.object(forKey: "hotkeyKeyCode") as? Int ?? Int(kVK_ANSI_T)
        hotkeyModifiers = defaults.object(forKey: "hotkeyModifiers") as? Int ?? (Int(optionKey) | Int(shiftKey))
    }

    var hotkeyDisplayString: String {
        Self.hotkeyDisplayString(for: hotkeyKeyCode, modifiers: hotkeyModifiers)
    }

    static func hotkeyDisplayString(for keyCode: Int, modifiers: Int) -> String {
        var parts = ""
        if modifiers & controlKey != 0 { parts += "\u{2303}" }
        if modifiers & optionKey != 0 { parts += "\u{2325}" }
        if modifiers & shiftKey != 0 { parts += "\u{21E7}" }
        if modifiers & cmdKey != 0 { parts += "\u{2318}" }
        parts += keyCodeToSymbol(keyCode)
        return parts
    }

    static func keyCodeToSymbol(_ keyCode: Int) -> String {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: UInt16(keyCode), keyDown: true),
              let nsEvent = NSEvent(cgEvent: event),
              let chars = nsEvent.charactersIgnoringModifiers?.uppercased(),
              !chars.isEmpty
        else {
            return "?"
        }
        return chars
    }
}
