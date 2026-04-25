import AppKit

@MainActor
final class NotchController {
    private let viewModel = NotchViewModel()
    private var window: NotchWindow?
    private var audioMonitor: AudioMonitor?
    private var brightnessMonitor: BrightnessMonitor?
    private var mediaMonitor: MediaRemoteMonitor?
    private var hoverMonitor: HoverMonitor?
    private let suppressor = SystemHUDSuppressor()
    private var lastSongTitle: String?

    func start() {
        viewModel.onMediaCommand = { [weak self] cmd in
            self?.mediaMonitor?.sendCommand(cmd)
        }

        let window = NotchWindow(viewModel: viewModel)
        window.orderFrontRegardless()
        self.window = window

        audioMonitor = AudioMonitor(onVolume: { [weak self] volume, muted in
            Task { @MainActor in self?.viewModel.setVolume(volume, muted: muted) }
        }, onDevice: { [weak self] name in
            Task { @MainActor in self?.handleDeviceChange(name) }
        })
        audioMonitor?.start()

        brightnessMonitor = BrightnessMonitor { [weak self] brightness in
            Task { @MainActor in self?.viewModel.setBrightness(brightness) }
        }
        brightnessMonitor?.start()

        mediaMonitor = MediaRemoteMonitor { [weak self] info in
            Task { @MainActor in self?.handleMediaUpdate(info) }
        }
        mediaMonitor?.start()

        hoverMonitor = HoverMonitor(hotZone: { [weak self] in
            MainActor.assumeIsolated { self?.currentHotZone() ?? .zero }
        }, handler: { [weak self] hovered in
            Task { @MainActor in self?.handleHover(hovered) }
        })
        hoverMonitor?.start()

        suppressor.start()
    }

    func shutdown() {
        suppressor.stop()
        suppressor.resumeSystem()
    }

    func previewVolume() {
        viewModel.setVolume(Float.random(in: 0.2...0.95), muted: false)
    }

    func previewBrightness() {
        viewModel.setBrightness(Float.random(in: 0.2...0.95))
    }

    func previewNotification() {
        viewModel.setNotification(NotificationInfo(
            title: "WAGWAN",
            subtitle: "Central Cee",
            icon: "music.note"
        ))
    }

    private func handleHover(_ hovered: Bool) {
        if hovered {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            mediaMonitor?.fetch()
        }
        viewModel.setHovered(hovered)
        window?.setInteractive(hovered)
    }

    private func handleDeviceChange(_ name: String?) {
        guard let name, !name.isEmpty else { return }
        viewModel.setNotification(NotificationInfo(
            title: name,
            subtitle: "Connected",
            icon: iconForDevice(name: name)
        ))
    }

    private func iconForDevice(name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("airpods pro") { return "airpods.pro" }
        if lower.contains("airpods max") { return "airpodsmax" }
        if lower.contains("airpod") { return "airpods" }
        if lower.contains("beats") { return "beats.headphones" }
        if lower.contains("headphone") { return "headphones" }
        if lower.contains("bluetooth") { return "bluetooth" }
        if lower.contains("macbook") { return "laptopcomputer" }
        return "hifispeaker.fill"
    }

    private func handleMediaUpdate(_ info: NowPlayingInfo?) {
        let previous = viewModel.nowPlaying?.title
        viewModel.nowPlaying = info
        guard let info, info.title != previous, !info.title.isEmpty else { return }
        lastSongTitle = info.title
        viewModel.setNotification(NotificationInfo(
            title: info.title,
            subtitle: info.artist.isEmpty ? nil : info.artist,
            icon: "music.note",
            imageData: info.artworkData
        ))

        if info.artworkData == nil {
            let title = info.title
            MediaArtworkFetcher.fetch(matchingTitle: title) { [weak self] data in
                guard let data else { return }
                Task { @MainActor in
                    self?.viewModel.updateNotificationArtwork(data, matching: title)
                }
            }
        }
    }

    private func currentHotZone() -> CGRect {
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main
        guard let screen else { return .zero }
        let frame = screen.frame
        let width: CGFloat
        let height: CGFloat
        switch viewModel.mode {
        case .expanded:
            width = NotchLayout.expandedWidth + 20
            height = NotchLayout.expandedHeight + 20
        case .hud, .notification:
            width = 260
            height = 110
        case .idle:
            width = 240
            height = 38
        }
        return CGRect(x: frame.midX - width / 2,
                      y: frame.maxY - height,
                      width: width,
                      height: height)
    }
}
