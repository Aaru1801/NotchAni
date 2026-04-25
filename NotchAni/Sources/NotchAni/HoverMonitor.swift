import AppKit

final class HoverMonitor {
    typealias Handler = (Bool) -> Void

    var hotZoneProvider: () -> CGRect
    private let handler: Handler
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isInside: Bool = false

    init(hotZone: @escaping () -> CGRect, handler: @escaping Handler) {
        self.hotZoneProvider = hotZone
        self.handler = handler
    }

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.check()
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.check()
            return event
        }
        check()
    }

    func stop() {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
        globalMonitor = nil
        localMonitor = nil
    }

    deinit { stop() }

    private func check() {
        let loc = NSEvent.mouseLocation
        let inside = hotZoneProvider().contains(loc)
        if inside != isInside {
            isInside = inside
            DispatchQueue.main.async { [weak self] in
                self?.handler(inside)
            }
        }
    }
}
