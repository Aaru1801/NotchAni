import AppKit
import iTunesLibrary // The correct framework for macOS Media permissions

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: NotchController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Force macOS to show the Media & Apple Music permissions popup
        do {
            let _ = try ITLibrary(apiVersion: "1.0")
            print("Media permissions requested successfully.")
        } catch {
            print("ITLibrary requested permission: \(error.localizedDescription)")
        }

        let controller = NotchController()
        controller.start()
        self.controller = controller

        installMenuBar()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.shutdown()
    }

    private func installMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "rectangle.roundedtop.fill",
                                   accessibilityDescription: "NotchAni")
            button.image?.isTemplate = true
            button.toolTip = "NotchAni"
        }

        let menu = NSMenu()
        let volumePreview = NSMenuItem(title: "Preview Volume HUD",
                                       action: #selector(previewVolume),
                                       keyEquivalent: "")
        let brightnessPreview = NSMenuItem(title: "Preview Brightness HUD",
                                           action: #selector(previewBrightness),
                                           keyEquivalent: "")
        let notificationPreview = NSMenuItem(title: "Preview Song Notification",
                                             action: #selector(previewNotification),
                                             keyEquivalent: "")
        let quitItem = NSMenuItem(title: "Quit NotchAni",
                                  action: #selector(quit),
                                  keyEquivalent: "q")
        [volumePreview, brightnessPreview, notificationPreview, quitItem].forEach {
            $0.target = self
        }

        menu.addItem(volumePreview)
        menu.addItem(brightnessPreview)
        menu.addItem(notificationPreview)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        item.menu = menu

        statusItem = item
    }

    @objc private func previewVolume() {
        controller?.previewVolume()
    }

    @objc private func previewBrightness() {
        controller?.previewBrightness()
    }

    @objc private func previewNotification() {
        controller?.previewNotification()
    }

    @objc private func quit() {
        controller?.shutdown()
        NSApp.terminate(nil)
    }
}
