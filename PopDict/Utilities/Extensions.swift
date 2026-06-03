import AppKit

extension NSScreen {
    static var mouseScreen: NSScreen? {
        screens.first { NSPointInRect(NSEvent.mouseLocation, $0.frame) }
    }
}
