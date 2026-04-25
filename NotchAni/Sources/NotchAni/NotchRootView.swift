import SwiftUI

enum NotchLayout {
    static let notchWidth: CGFloat = 200
    static let notchHeight: CGFloat = 32
    static let hudWidth: CGFloat = 220
    static let hudHeight: CGFloat = 96
    static let notificationWidth: CGFloat = 340
    static let notificationHeight: CGFloat = 76
    static let expandedWidth: CGFloat = 720
    static let expandedHeight: CGFloat = 220
    static let cornerRadius: CGFloat = 14
}

struct NotchRootView: View {
    @ObservedObject var viewModel: NotchViewModel

    private var size: CGSize {
        switch viewModel.mode {
        case .idle:
            return CGSize(width: NotchLayout.notchWidth, height: NotchLayout.notchHeight)
        case .hud:
            return CGSize(width: NotchLayout.hudWidth, height: NotchLayout.hudHeight)
        case .notification:
            return CGSize(width: NotchLayout.notificationWidth, height: NotchLayout.notificationHeight)
        case .expanded:
            return CGSize(width: NotchLayout.expandedWidth, height: NotchLayout.expandedHeight)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                NotchShape(cornerRadius: NotchLayout.cornerRadius)
                    .fill(Color.black)
                    .shadow(color: .black.opacity(viewModel.mode == .idle ? 0 : 0.35),
                            radius: 10, x: 0, y: 4)

                contentView
                    .padding(.top, NotchLayout.notchHeight)
            }
            .frame(width: size.width, height: size.height)
            .clipShape(NotchShape(cornerRadius: NotchLayout.cornerRadius))
            .animation(.spring(response: 0.42, dampingFraction: 0.78), value: viewModel.mode)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.mode {
        case .idle:
            EmptyView()
        case .hud(let kind):
            HUDContent(kind: kind, viewModel: viewModel)
                .transition(contentTransition)
        case .notification:
            NotificationContent(info: viewModel.notification)
                .transition(contentTransition)
        case .expanded:
            ExpandedContent(viewModel: viewModel)
                .transition(contentTransition)
        }
    }

    private var contentTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.93, anchor: .top))
                .animation(.spring(response: 0.38, dampingFraction: 0.8).delay(0.06)),
            removal: .opacity.animation(.easeOut(duration: 0.12))
        )
    }
}

struct NotchShape: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = min(cornerRadius, rect.height / 2, rect.width / 2)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - r, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - r),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - HUD

struct HUDContent: View {
    let kind: HUDKind
    @ObservedObject var viewModel: NotchViewModel

    private var value: Float {
        kind == .volume ? viewModel.volume : viewModel.brightness
    }

    private var icon: String {
        switch kind {
        case .volume:
            if viewModel.muted || viewModel.volume <= 0.001 { return "speaker.slash.fill" }
            if viewModel.volume < 0.33 { return "speaker.wave.1.fill" }
            if viewModel.volume < 0.66 { return "speaker.wave.2.fill" }
            return "speaker.wave.3.fill"
        case .brightness:
            return "sun.max.fill"
        }
    }

    private var tint: Color {
        kind == .volume ? .white : Color(red: 1.0, green: 0.82, blue: 0.28)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .contentTransition(.symbolEffect(.replace))
                Spacer()
                Text("\(Int(round(value * 100)))%")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            ProgressBar(value: value, tint: tint)
                .frame(height: 7)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
    }
}

// MARK: - Notification

struct NotificationContent: View {
    let info: NotificationInfo?

    var body: some View {
        HStack(spacing: 12) {
            artwork
            VStack(alignment: .leading, spacing: 2) {
                Text(info?.title ?? "")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let sub = info?.subtitle, !sub.isEmpty {
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if let icon = info?.icon, info?.imageData == nil {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var artwork: some View {
        if let data = info?.imageData, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.medium)
                .aspectRatio(contentMode: .fill)
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        } else if let icon = info?.icon {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.white.opacity(0.1))
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
            }
            .frame(width: 32, height: 32)
        }
    }
}

// MARK: - Expanded

struct ExpandedContent: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            MediaPanel(viewModel: viewModel)
                .frame(width: 360)
            Divider()
                .background(Color.white.opacity(0.08))
                .frame(height: 140)
            SlidersPanel(viewModel: viewModel)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 22)
        .padding(.top, 4)
        .padding(.bottom, 18)
    }
}

struct MediaPanel: View {
    @ObservedObject var viewModel: NotchViewModel

    private var title: String { viewModel.nowPlaying?.title ?? "Nothing playing" }
    private var artist: String { viewModel.nowPlaying?.artist ?? "" }
    private var elapsed: TimeInterval { viewModel.nowPlaying?.elapsed ?? 0 }
    private var duration: TimeInterval { viewModel.nowPlaying?.duration ?? 0 }
    private var isPlaying: Bool { viewModel.nowPlaying?.isPlaying ?? false }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            artwork
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(artist)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)

                ProgressBar(value: progressFraction, tint: .white.opacity(0.9))
                    .frame(height: 3)
                    .padding(.top, 6)
                HStack {
                    Text(format(elapsed))
                    Spacer()
                    Text(format(duration))
                }
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .monospacedDigit()

                HStack(spacing: 18) {
                    Spacer(minLength: 0)
                    MediaButton(symbol: "backward.fill") {
                        viewModel.sendMediaCommand(MediaRemoteCommand.previous)
                    }
                    MediaButton(symbol: isPlaying ? "pause.fill" : "play.fill", size: 22) {
                        viewModel.sendMediaCommand(MediaRemoteCommand.togglePlayPause)
                    }
                    MediaButton(symbol: "forward.fill") {
                        viewModel.sendMediaCommand(MediaRemoteCommand.next)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 4)
            }
        }
    }

    private var progressFraction: Float {
        guard duration > 0 else { return 0 }
        return Float(max(0, min(1, elapsed / duration)))
    }

    @ViewBuilder
    private var artwork: some View {
        if let data = viewModel.nowPlaying?.artworkData, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
                .frame(width: 110, height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08)))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.08))
                Image(systemName: "music.note")
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .frame(width: 110, height: 110)
        }
    }

    private func format(_ t: TimeInterval) -> String {
        guard t.isFinite, t >= 0 else { return "0:00" }
        let total = Int(t.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

struct MediaButton: View {
    let symbol: String
    var size: CGFloat = 16
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

struct SlidersPanel: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SliderRow(
                label: "VOLUME",
                value: viewModel.volume,
                tint: .white,
                icon: viewModel.muted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                onScrub: { v in
                    SystemAdjuster.setVolume(v)
                    viewModel.applyVolume(v)
                }
            )
            SliderRow(
                label: "BRIGHTNESS",
                value: viewModel.brightness,
                tint: Color(red: 1.0, green: 0.82, blue: 0.28),
                icon: "sun.max.fill",
                onScrub: { v in
                    SystemAdjuster.setBrightness(v)
                    viewModel.applyBrightness(v)
                }
            )
        }
        .padding(.top, 6)
    }
}

struct SliderRow: View {
    let label: String
    let value: Float
    let tint: Color
    let icon: String
    let onScrub: (Float) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .tracking(1.2)
                Spacer()
                Text("\(Int(round(value * 100)))%")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            ScrubBar(value: value, tint: tint, onScrub: onScrub)
                .frame(height: 18)
        }
    }
}

struct ScrubBar: View {
    let value: Float
    let tint: Color
    let onScrub: (Float) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.14))
                    .frame(height: 7)
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, geo.size.width * CGFloat(max(0, min(1, value)))),
                           height: 7)
                    .animation(.spring(response: 0.22, dampingFraction: 0.9), value: value)
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let f = Float(gesture.location.x / max(1, geo.size.width))
                        onScrub(max(0, min(1, f)))
                    }
            )
        }
    }
}

struct ProgressBar: View {
    let value: Float
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.14))
                Capsule()
                    .fill(tint)
                    .frame(width: geo.size.width * CGFloat(max(0, min(1, value))))
                    .animation(.spring(response: 0.28, dampingFraction: 0.85), value: value)
            }
        }
    }
}
