import AppKit
import SwiftUI

final class FloatingPanelController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var hostingController: NSHostingController<FloatingPanelView>?

    func show(text: String) {
        if panel == nil {
            createPanel()
        }
        guard let panel else { return }

        hostingController?.rootView = FloatingPanelView(text: text, onClose: { [weak self] in
            self?.hide()
        })

        positionPanelNearMouse(panel)

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isReleasedWhenClosed = false
        panel.delegate = self

        let view = FloatingPanelView(text: "", onClose: { [weak self] in self?.hide() })
        let hostingController = NSHostingController(rootView: view)
        panel.contentViewController = hostingController

        self.panel = panel
        self.hostingController = hostingController
    }

    private func positionPanelNearMouse(_ panel: NSPanel) {
        let mouseLocation = NSEvent.mouseLocation
        let panelSize = panel.frame.size

        var origin = NSPoint(
            x: mouseLocation.x - panelSize.width / 2,
            y: mouseLocation.y - panelSize.height / 2
        )

        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            origin.x = max(visible.minX, min(origin.x, visible.maxX - panelSize.width))
            origin.y = max(visible.minY, min(origin.y, visible.maxY - panelSize.height))
        }

        panel.setFrameOrigin(origin)
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}
