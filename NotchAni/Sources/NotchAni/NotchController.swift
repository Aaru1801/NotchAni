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
        mediaMonitor?.stop()
    }

    func previewVolume() {
        viewModel.setVolume(Float.random(in: 0.2...0.95), muted: false)
    }

    func previewBrightness() {
        viewModel.setBrightness(Float.random(in: 0.2...0.95))
    }

    func previewNotification() {
        if let np = viewModel.nowPlaying, !np.title.isEmpty {
            viewModel.setNotification(NotificationInfo(
                title: np.title,
                subtitle: np.artist.isEmpty ? nil : np.artist,
                icon: "music.note",
                imageData: np.artworkData
            ))
        } else {
            viewModel.setNotification(NotificationInfo(
                title: "Nothing playing",
                subtitle: nil,
                icon: "music.note"
            ))
        }
    }

    private func handleHover(_ hovered: Bool) {
        if hovered {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                }
        viewModel.setHovered(hovered)
        window?.setInteractive(hovered)
    }

    private func handleDeviceChange(_ name: String?) {
        guard let name, !name.isEmpty else { return }
        // Skip built-in speakers — they fire on app boot when populating the
        // initial device set on some macOS versions.
        let lower = name.lowercased()
        if lower.contains("macbook") && lower.contains("speaker") { return }
        viewModel.setNotification(NotificationInfo(
            title: name,
            subtitle: "Connected",
            icon: iconForDevice(name: name)
        ))
    }

    private func iconForDevice(name: String) -> String {
        let lower = name.lowercased()

        // AirPods family
        if lower.contains("airpods pro") { return "airpods.pro" }
        if lower.contains("airpods max") { return "airpodsmax" }
        if lower.contains("airpod") { return "airpods" }

        // Beats
        if lower.contains("beats") { return "beats.headphones" }

        // In-ear / earbuds — match brand or "buds"
        let earbudKeys = ["buds", "realme", "galaxy buds", "nothing ear",
                          "oneplus buds", "redmi buds", "xiaomi buds",
                          "soundcore liberty", "jbl tune", "wf-",
                          "moto buds", "pixel buds"]
        if earbudKeys.contains(where: { lower.contains($0) }) { return "earbuds" }

        // Over-ear / on-ear by brand or model
        let overEarKeys = ["sony", "wh-", "wh1000", "bose", "sennheiser",
                           "audio-technica", "ath-", "shure", "akg",
                           "jbl live", "marshall", "soundcore q"]
        if overEarKeys.contains(where: { lower.contains($0) }) { return "headphones" }
        if lower.contains("headphone") || lower.contains("headset") { return "headphones" }

        // Speakers
        if lower.contains("homepod") { return "homepod.fill" }
        if lower.contains("speaker") { return "hifispeaker.fill" }

        // Computer outputs
        if lower.contains("macbook") { return "laptopcomputer" }
        if lower.contains("imac") { return "desktopcomputer" }
        if lower.contains("display") || lower.contains("monitor") { return "display" }

        return "headphones"
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
