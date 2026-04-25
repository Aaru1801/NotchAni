import Darwin
import Foundation

private let pidPathMax: Int = 4 * 1024

final class SystemHUDSuppressor {
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "NotchAni.Suppressor", qos: .userInitiated)

    func start() {
        attemptLaunchctlBootout()

        stop()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: 0.05)
        t.setEventHandler { [weak self] in self?.killHUDProcesses() }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    func resumeSystem() {
        attemptLaunchctlBootstrap()
    }

    // MARK: - Process killing

    private func killHUDProcesses() {
        for pid in hudPIDs() {
            kill(pid, SIGKILL)
        }
    }

    private func hudPIDs() -> [pid_t] {
        let bytesReported = proc_listallpids(nil, 0)
        guard bytesReported > 0 else { return [] }
        let slots = Int(bytesReported) / MemoryLayout<pid_t>.size + 64
        var pids = [pid_t](repeating: 0, count: slots)
        let bytes = proc_listallpids(&pids, Int32(slots * MemoryLayout<pid_t>.size))
        let n = Int(max(0, bytes)) / MemoryLayout<pid_t>.size

        var result: [pid_t] = []
        let pathBuf = UnsafeMutableRawPointer.allocate(byteCount: pidPathMax, alignment: 1)
        defer { pathBuf.deallocate() }

        for i in 0..<n {
            let pid = pids[i]
            guard pid > 0 else { continue }
            memset(pathBuf, 0, pidPathMax)
            let len = proc_pidpath(pid, pathBuf, UInt32(pidPathMax))
            if len <= 0 { continue }
            let path = String(cString: pathBuf.assumingMemoryBound(to: CChar.self))
            if isHUDProcess(path: path) {
                result.append(pid)
            }
        }
        return result
    }

    private func isHUDProcess(path: String) -> Bool {
        let needles = [
            "/OSDUIHelper",
            "/Contents/MacOS/OSDUIHelper",
            "/BezelUIServer",
        ]
        return needles.contains(where: { path.hasSuffix($0) })
    }

    // MARK: - launchctl

    private func attemptLaunchctlBootout() {
        let uid = getuid()
        runProcess("/bin/launchctl", ["bootout", "gui/\(uid)/com.apple.OSDUIHelper"])
    }

    private func attemptLaunchctlBootstrap() {
        let uid = getuid()
        runProcess("/bin/launchctl", [
            "bootstrap", "gui/\(uid)",
            "/System/Library/LaunchAgents/com.apple.OSDUIHelper.plist"
        ])
    }

    @discardableResult
    private func runProcess(_ path: String, _ args: [String]) -> Int32 {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args
        task.standardError = FileHandle.nullDevice
        task.standardOutput = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus
        } catch {
            return -1
        }
    }

    deinit { stop() }
}
