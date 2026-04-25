import AppKit
import Foundation

final class MediaRemoteMonitor {
    typealias Handler = (NowPlayingInfo?) -> Void

    private let handler: Handler
    private var observers: [NSObjectProtocol] = []

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    func start() {
        guard MediaRemoteSPI.registerForNotifications != nil else {
            handler(nil)
            return
        }
        MediaRemoteSPI.registerForNotifications?(0)

        let center = NotificationCenter.default
        let names = [
            "kMRMediaRemoteNowPlayingInfoDidChangeNotification",
            "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
            "kMRMediaRemoteNowPlayingApplicationClientStateDidChange",
            "kMRMediaRemoteNowPlayingPlaybackQueueChangedNotification",
        ]
        for name in names {
            let obs = center.addObserver(
                forName: Notification.Name(name),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.fetch()
            }
            observers.append(obs)
        }

        fetch()
    }

    deinit {
        for obs in observers {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    func sendCommand(_ cmd: Int32) {
        _ = MediaRemoteSPI.sendCommand?(cmd, nil)
    }

    func fetch() {
        guard let get = MediaRemoteSPI.getNowPlayingInfo else {
            handler(nil)
            return
        }
        get(DispatchQueue.main) { [weak self] info in
            let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
            guard !title.isEmpty else {
                self?.handler(nil)
                return
            }
            let np = NowPlayingInfo(
                title: title,
                artist: info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? "",
                album: info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? "",
                artworkData: info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data,
                elapsed: info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? TimeInterval ?? 0,
                duration: info["kMRMediaRemoteNowPlayingInfoDuration"] as? TimeInterval ?? 0,
                isPlaying: (info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0) > 0,
                timestamp: Date()
            )
            self?.handler(np)
        }
    }
}

private enum MediaRemoteSPI {
    typealias GetNowPlayingInfoFn = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    typealias RegisterFn = @convention(c) (Int32) -> Void
    typealias SendCommandFn = @convention(c) (Int32, [AnyHashable: Any]?) -> Bool

    static let handle: UnsafeMutableRawPointer? = {
        dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW)
    }()

    static let getNowPlayingInfo: GetNowPlayingInfoFn? = sym("MRMediaRemoteGetNowPlayingInfo")
    static let registerForNotifications: RegisterFn? = sym("MRMediaRemoteRegisterForNowPlayingNotifications")
    static let sendCommand: SendCommandFn? = sym("MRMediaRemoteSendCommand")

    private static func sym<T>(_ name: String) -> T? {
        guard let handle, let p = dlsym(handle, name) else { return nil }
        return unsafeBitCast(p, to: T.self)
    }
}
