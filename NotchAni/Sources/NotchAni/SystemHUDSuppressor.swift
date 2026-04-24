import Darwin
import Foundation

private let pidPathMax: Int = 4 * 1024

final class SystemHUDSuppressor {
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "NotchAni.Suppressor", qos: .utility)

    func start() {
        stop()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: 0.1)
        t.setEventHandler { [weak self] in self?.suspend() }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    func resumeSystem() {
        for pid in osdPIDs() { kill(pid, SIGCONT) }
    }

    private func suspend() {
        for pid in osdPIDs() { kill(pid, SIGSTOP) }
    }

    private func osdPIDs() -> [pid_t] {
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
            if path.hasSuffix("/OSDUIHelper") || path.hasSuffix("/Contents/MacOS/OSDUIHelper") {
                result.append(pid)
            }
        }
        return result
    }

    deinit { stop() }
}
