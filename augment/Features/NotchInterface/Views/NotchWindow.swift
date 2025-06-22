import AppKit

// MARK: - Custom Window Class
class NotchWindow: NSWindow {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
} 