import SwiftUI

enum HUDKind: Equatable {
    case volume
    case brightness
}

enum DisplayMode: Equatable {
    case idle
    case hud(HUDKind)
    case notification
    case expanded
}

struct NowPlayingInfo: Equatable {
    var title: String
    var artist: String
    var album: String
    var artworkData: Data?
    var elapsed: TimeInterval
    var duration: TimeInterval
    var isPlaying: Bool
    var timestamp: Date
}

struct NotificationInfo: Equatable {
    var title: String
    var subtitle: String?
    var icon: String?
    var imageData: Data?
}

@MainActor
final class NotchViewModel: ObservableObject {
    @Published private(set) var mode: DisplayMode = .idle
    @Published var volume: Float = 0
    @Published var muted: Bool = false
    @Published var brightness: Float = 0
    @Published var nowPlaying: NowPlayingInfo?
    @Published private(set) var notification: NotificationInfo?

    var onMediaCommand: (Int32) -> Void = { _ in }

    private var dismissTask: Task<Void, Never>?
    private var isHovering: Bool = false

    func setHovered(_ hovered: Bool) {
        guard isHovering != hovered else { return }
        isHovering = hovered
        dismissTask?.cancel()
        updateMode()
    }

    func setVolume(_ volume: Float, muted: Bool) {
        self.volume = volume
        self.muted = muted
        showHUD(.volume)
    }

    func setBrightness(_ brightness: Float) {
        self.brightness = brightness
        showHUD(.brightness)
    }

    /// Drag-applied changes from the expanded panel — update state but don't trigger
    /// the auto-dismissing HUD (the user is already hovering / scrubbing).
    func applyVolume(_ value: Float) {
        volume = value
        if value > 0 { muted = false }
    }

    func applyBrightness(_ value: Float) {
        brightness = value
    }

    func setNotification(_ info: NotificationInfo) {
        notification = info
        guard !isHovering else { return }
        withAnim { mode = .notification }
        scheduleDismiss(after: 2.4)
    }

    func updateNotificationArtwork(_ data: Data, matching title: String) {
        if var current = notification, current.title == title, current.imageData == nil {
            current.imageData = data
            notification = current
        }
        if var np = nowPlaying, np.title == title, np.artworkData == nil {
            np.artworkData = data
            nowPlaying = np
        }
    }

    func sendMediaCommand(_ cmd: Int32) {
        onMediaCommand(cmd)
    }

    private func showHUD(_ kind: HUDKind) {
        guard !isHovering else { return }
        withAnim { mode = .hud(kind) }
        scheduleDismiss(after: 1.6)
    }

    private func updateMode() {
        withAnim {
            mode = isHovering ? .expanded : .idle
        }
    }

    private func scheduleDismiss(after seconds: Double) {
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if Task.isCancelled { return }
            await MainActor.run { self?.updateMode() }
        }
    }

    private func withAnim(_ block: () -> Void) {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78), block)
    }
}

enum MediaRemoteCommand {
    static let play: Int32 = 0
    static let pause: Int32 = 1
    static let togglePlayPause: Int32 = 2
    static let next: Int32 = 4
    static let previous: Int32 = 5
}
