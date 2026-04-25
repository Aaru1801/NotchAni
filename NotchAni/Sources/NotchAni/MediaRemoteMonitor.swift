import AppKit
import Foundation

/// Streams now-playing info from the bundled `mediaremote-adapter.pl`.
/// The adapter emits newline-delimited JSON envelopes:
///   {"type":"data","diff":bool,"payload":{...}}
/// Diff envelopes only carry changed fields, so we maintain a running merged
/// state and emit a fresh snapshot on every event.
final class MediaRemoteMonitor {
    typealias Handler = (NowPlayingInfo?) -> Void

    private let handler: Handler
    private let queue = DispatchQueue(label: "NotchAni.MediaRemote", qos: .userInitiated)
    private var process: Process?
    private var buffer = Data()
    private var current = AdapterPayload()
    private var shouldRun = true

    init(handler: @escaping Handler) { self.handler = handler }

    deinit {
        stop()
    }

    func stop() {
        shouldRun = false
        guard let task = process else { return }
        task.terminate()
        let deadline = Date().addingTimeInterval(0.4)
        while task.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.04)
        }
        if task.isRunning {
            kill(task.processIdentifier, SIGKILL)
        }
    }

    func start() {
        killOrphanedAdapters()
        queue.async { [weak self] in
            self?.runLoop()
        }
    }

    /// If a previous app instance was force-killed, its perl child becomes
    /// orphaned and keeps holding the MediaRemote client slot. Reap any leftovers
    /// before we spawn our own.
    private func killOrphanedAdapters() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        task.arguments = ["-f", "mediaremote-adapter.pl"]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return
        }
        Thread.sleep(forTimeInterval: 0.15)
    }

    func sendCommand(_ cmd: Int32) {
        guard let res = Bundle.main.resourcePath else { return }
        let script = "\(res)/mediaremote-adapter.pl"
        let framework = "\(res)/MediaRemoteAdapter.framework"
        guard FileManager.default.fileExists(atPath: script) else { return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        task.arguments = [script, framework, "send", String(cmd)]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
    }

    // MARK: - Stream

    private func runLoop() {
        guard let res = Bundle.main.resourcePath else { return }
        let script = "\(res)/mediaremote-adapter.pl"
        let framework = "\(res)/MediaRemoteAdapter.framework"
        guard FileManager.default.fileExists(atPath: script),
              FileManager.default.fileExists(atPath: framework) else {
            return
        }
        var consecutiveFailures = 0
        while shouldRun {
            buffer.removeAll(keepingCapacity: true)
            let succeeded = runOnce(script: script, framework: framework)
            consecutiveFailures = succeeded ? 0 : consecutiveFailures + 1
            // Cap backoff at ~10s after repeated failures (e.g. perl missing).
            let delay = min(10, 1 << min(consecutiveFailures, 4))
            sleep(UInt32(delay))
        }
    }

    private func runOnce(script: String, framework: String) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        task.arguments = [script, framework, "stream"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty {
                self?.processIncoming(data)
            }
        }

        process = task
        defer {
            pipe.fileHandleForReading.readabilityHandler = nil
            process = nil
        }

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func processIncoming(_ data: Data) {
        buffer.append(data)
        let newline = Data([0x0A])
        while let range = buffer.firstRange(of: newline) {
            let line = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
            buffer.removeSubrange(buffer.startIndex..<range.upperBound)
            handleLine(line)
        }
    }

    private func handleLine(_ line: Data) {
        guard !line.isEmpty,
              let event = try? JSONDecoder().decode(AdapterEvent.self, from: line),
              event.type == "data" else {
            return
        }

        if event.diff == false {
            // Full snapshot — replace state. Empty payload resets to nothing playing.
            current = event.payload ?? AdapterPayload()
        } else if let payload = event.payload {
            current.merge(from: payload)
        }

        let snapshot = current.toNowPlaying()
        DispatchQueue.main.async { [weak self] in
            self?.handler(snapshot)
        }
    }
}

private struct AdapterEvent: Decodable {
    let type: String
    let diff: Bool
    let payload: AdapterPayload?
}

private struct AdapterPayload: Decodable {
    var title: String?
    var artist: String?
    var album: String?
    var artworkData: String?
    var artworkMimeType: String?
    var duration: Double?
    var elapsedTime: Double?
    var playing: Bool?
    var playbackRate: Double?
    var bundleIdentifier: String?

    init() {}

    mutating func merge(from other: AdapterPayload) {
        if let v = other.title { title = v }
        if let v = other.artist { artist = v }
        if let v = other.album { album = v }
        if let v = other.artworkData { artworkData = v }
        if let v = other.artworkMimeType { artworkMimeType = v }
        if let v = other.duration { duration = v }
        if let v = other.elapsedTime { elapsedTime = v }
        if let v = other.playing { playing = v }
        if let v = other.playbackRate { playbackRate = v }
        if let v = other.bundleIdentifier { bundleIdentifier = v }
    }

    func toNowPlaying() -> NowPlayingInfo? {
        guard let title, !title.isEmpty else { return nil }
        var artwork: Data?
        if let b64 = artworkData, !b64.isEmpty {
            artwork = Data(base64Encoded: b64)
        }
        return NowPlayingInfo(
            title: title,
            artist: artist ?? "",
            album: album ?? "",
            artworkData: artwork,
            elapsed: elapsedTime ?? 0,
            duration: duration ?? 0,
            isPlaying: playing ?? ((playbackRate ?? 0) > 0),
            timestamp: Date()
        )
    }
}
