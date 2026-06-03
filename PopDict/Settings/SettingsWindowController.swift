import AppKit
import SwiftUI

final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var panel: NSPanel?
    private var didCommit = false

    func show() {
        if panel == nil {
            createPanel()
        }
        didCommit = false
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 260),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        panel.title = "Settings"
        panel.center()
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = true
        panel.delegate = self

        let hostingView = NSHostingView(rootView: SettingsView(
            onSave: { [weak self] in
                SettingsStore.shared.commit()
                self?.didCommit = true
                self?.panel?.close()
            },
            onCancel: { [weak self] in
                SettingsStore.shared.discard()
                self?.panel?.close()
            }
        ))
        panel.contentView = hostingView

        self.panel = panel
    }

    func windowWillClose(_ notification: Notification) {
        if !didCommit {
            SettingsStore.shared.discard()
        }
        didCommit = false
    }
}
