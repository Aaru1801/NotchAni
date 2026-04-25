import AppKit
import SwiftUI

final class NotchWindow: NSPanel {
    private static let windowWidth: CGFloat = 820
    private static let windowHeight: CGFloat = 280

    init(viewModel: NotchViewModel) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Self.windowWidth, height: Self.windowHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.overlayWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true

        let hosting = NSHostingView(rootView: NotchRootView(viewModel: viewModel))
        hosting.frame = NSRect(x: 0, y: 0, width: Self.windowWidth, height: Self.windowHeight)
        hosting.autoresizingMask = [.width, .height]
        contentView = hosting

        positionOverNotch()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func setInteractive(_ interactive: Bool) {
        ignoresMouseEvents = !interactive
    }

    @objc private func screensChanged() {
        positionOverNotch()
    }

    private func positionOverNotch() {
        let notched = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
        let screen = notched ?? NSScreen.main
        guard let screen else { return }
        let frame = screen.frame
        let x = frame.midX - Self.windowWidth / 2
        let y = frame.maxY - Self.windowHeight
        setFrame(NSRect(x: x, y: y, width: Self.windowWidth, height: Self.windowHeight),
                 display: true)
    }
}
