# PopDict — macOS menu-bar dictionary app

## Build & run

- **Build:** `xcodebuild -project PopDict.xcodeproj -scheme PopDict -configuration Debug build`
- No SPM/CocoaPods/any external dependencies — pure Apple frameworks only
- Xcode project uses **file-system-synchronized groups** — adding new `.swift` files inside `PopDict/` auto-discovers them; no need to edit `pbxproj`

## Architecture

- **Menu-bar agent** (`LSUIElement = YES`) — no Dock icon, no standard window. `PopDictApp.swift` is the `@main` entry with a `MenuBarExtra` scene.
- **Feature folders** under `PopDict/`: `App/`, `TextCapture/`, `Hotkey/`, `Dictionary/`, `Anki/`, `UI/`, `Utilities/`
- **Services are singletons** (`static let shared`) — simple, no DI
- **FloatingPanelController** (`UI/FloatingPanel/`) owns the `NSPanel` (AppKit, not SwiftUI window). It manages show/hide/position; the panel content is a SwiftUI `NSHostingController`

## Key patterns to know

- **Carbon C interop** — global hotkeys use `RegisterEventHotKey` / `InstallEventHandler` (the only way to register global shortcuts on macOS). `Unmanaged.passUnretained` is used to pass `self` to C callbacks.
- **Accessibility API** — `TextCaptureService` reads selected text via `AXUIElementCopyAttributeValue`. This requires Accessibility permission (prompted on first launch). No App Sandbox (disabled in build settings).
- **Pasteboard fallback** — when AX fails (Electron/custom-drawn apps), `getSelectedTextViaPasteboard()` simulates `Cmd+C` via `CGEvent` then restores the original clipboard. 50ms sleep + `changeCount` check to avoid stale data.
- **AnkiConnect** — `AnkiConnectService` talks to Anki's local HTTP plugin at `localhost:8765` (not yet wired into UI).
- **DictionaryServiceProtocol** – use this protocol for new dictionary backends; currently only `MockDictionaryService` exists.

## Key files

| File | Role |
|------|------|
| `App/PopDictApp.swift` | `@main` entry point, `MenuBarExtra` |
| `App/AppDelegate.swift` | Lifecycle, hotkey registration, capture orchestration |
| `TextCapture/TextCaptureService.swift` | AX + pasteboard text capture |
| `Hotkey/HotkeyService.swift` | Carbon global hotkey (Opt+Shift+T) |
| `UI/FloatingPanel/FloatingPanelController.swift` | NSPanel manager |
| `UI/FloatingPanel/FloatingPanelView.swift` | SwiftUI panel content |
| `Dictionary/DictionaryService.swift` | Protocol + mock + models |
| `Anki/AnkiConnectService.swift` | AnkiConnect HTTP client |

## Testing

- No test targets exist. Any new tests should be added as a new target in Xcode.
