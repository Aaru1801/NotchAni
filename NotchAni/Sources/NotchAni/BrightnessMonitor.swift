import AppKit
import Foundation

final class BrightnessMonitor {
    typealias Handler = (Float) -> Void

    private let handler: Handler
    private var timer: DispatchSourceTimer?
    private var lastValue: Float = -1
    private let queue = DispatchQueue(label: "NotchAni.BrightnessMonitor")

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    func start() {
        stop()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 0.1, repeating: 0.1)
        timer.setEventHandler { [weak self] in
            self?.tick()
        }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    deinit { stop() }

    private func tick() {
        guard let value = currentBrightness() else { return }
        if abs(value - lastValue) < 0.002 { return }
        let firstRead = lastValue < 0
        lastValue = value
        if firstRead { return }
        handler(value)
    }

    private func currentBrightness() -> Float? {
        guard let getter = BrightnessSPI.getBrightness else { return nil }
        let display = mainDisplayID()
        var value: Float = 0
        if getter(display, &value) == 0 {
            return max(0, min(1, value))
        }
        return nil
    }

    private func mainDisplayID() -> CGDirectDisplayID {
        if let screen = NSScreen.main,
           let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return CGDirectDisplayID(number.uint32Value)
        }
        return CGMainDisplayID()
    }
}

private enum BrightnessSPI {
    typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32

    static let handle: UnsafeMutableRawPointer? = {
        dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
    }()

    static let getBrightness: GetBrightness? = {
        guard let handle,
              let sym = dlsym(handle, "DisplayServicesGetBrightness") else { return nil }
        return unsafeBitCast(sym, to: GetBrightness.self)
    }()
}
