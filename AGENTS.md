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

## QA Checklist

Run through these manually after any change to trigger/capture/panel/settings logic (~2 min).

### Settings window

- [ ] **Persistence:** Change trigger method → Save → close settings → reopen → value persisted
- [ ] **Discard on cancel:** Change trigger method → Cancel → reopen → reverted to last saved
- [ ] **Discard on close:** Change trigger method → click X or click outside → reopen → reverted to last saved
- [ ] **Hotkey remap persists:** Change key combo → Save → reopen → new combo displayed
- [ ] **Layout stable:** Switch between "On key combination" and "On text selection" — no UI jumping
- [ ] **Hotkey row shows/hides:** Key combination row appears only when "On key combination" is active

### Hotkey trigger mode

- [ ] **Combo works:** Press the configured key combination → floating panel opens with selected text
- [ ] **Combo works after remap:** Change key combo in settings → Save → new combo works, old combo doesn't
- [ ] **No text selected:** Press hotkey with no text selected in any app → panel does NOT show

### Text-selection trigger mode

- [ ] **Select text → panel opens:** Select text in another app, release mouse → panel opens with captured text
- [ ] **Double-click → panel opens:** Double-click a word in another app → panel opens
- [ ] **Different text triggers again:** Select "hello" → panel shows → deselect → select "world" → panel shows again
- [ ] **Same text does NOT reopen:** Select "hello" → panel shows → click outside to close → panel does NOT reopen (text still selected)

### Floating panel

- [ ] **Click outside closes:** Panel open → click anywhere outside (another app, desktop) → panel closes immediately
- [ ] **Close button works:** Click the X button in the panel header → panel closes
- [ ] **Drag works:** Drag the panel by its content area → panel moves with mouse
- [ ] **Positions near mouse:** Panel appears centered on the current cursor position

### Menu bar

- [ ] **Settings opens:** Click menu bar icon → Settings... → settings window opens
- [ ] **Manual capture:** Click menu bar icon → Capture Selected Text → panel opens with selected text
- [ ] **Quit:** Click menu bar icon → Quit (or Cmd+Q) → app terminates

## Testing

- No test targets exist. Any new tests should be added as a new target in Xcode.
