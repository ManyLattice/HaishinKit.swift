import Foundation

#if os(macOS)
#else
    typealias DisplayLink = CADisplayLink
#endif

protocol ChoreographerDelegate: AnyObject {
    func choreographer(_ choreographer: Choreographer, didFrame duration: Double)
}

protocol Choreographer: Running {
    var isPaused: Bool { get set }
    var delegate: ChoreographerDelegate? { get set }
    func clear()
}

final class DisplayLinkChoreographer: Choreographer {
    static let defaultPreferredFramesPerSecond = 0

    var isPaused: Bool {
        get {
            displayLink?.isPaused ?? true
        }
        set {
            displayLink?.isPaused = newValue
        }
    }
    weak var delegate: ChoreographerDelegate?
    var isRunning: Atomic<Bool> = .init(false)
    private var timestamp = 0.0
    private var displayLink: DisplayLink? {
        didSet {
            oldValue?.invalidate()
            guard let displayLink = displayLink else {
                return
            }
            displayLink.isPaused = true
            if #available(iOS 10.0, tvOS 10.0, *) {
                displayLink.preferredFramesPerSecond = Self.defaultPreferredFramesPerSecond
            } else {
                displayLink.frameInterval = 1
            }
            displayLink.add(to: .main, forMode: .common)
        }
    }

    func clear() {
        timestamp = 0.0
    }

    @objc
    private func update(displayLink: DisplayLink) {
        if timestamp == 0.0 {
            timestamp = displayLink.timestamp
        }
        delegate?.choreographer(self, didFrame: displayLink.timestamp - timestamp)
    }
}

extension DisplayLinkChoreographer: Running {
    func startRunning() {
        displayLink = DisplayLink(target: self, selector: #selector(self.update(displayLink:)))
        isRunning.mutate { $0 = true }
    }

    func stopRunning() {
        displayLink = nil
        timestamp = 0.0
        isRunning.mutate { $0 = false }
    }
}
