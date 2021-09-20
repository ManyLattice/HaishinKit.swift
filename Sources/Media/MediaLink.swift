import AVFoundation

protocol MediaLinkDelegate: AnyObject {
    func mediaLink(_ mediaLink: MediaLink, didDequeue sampleBuffer: CMSampleBuffer)
    func mediaLinkDidEmpty(_ mediaLink: MediaLink)
}

protocol MediaLinkDataSource: AnyObject {
    var duration: TimeInterval { get }
}

final class MediaLink {
    static let defaultPreferredFramesPerSecond = 0

    var isPaused: Bool {
        get {
            choreographer.isPaused
        }
        set {
            choreographer.isPaused = newValue
        }
    }
    weak var delegate: MediaLinkDelegate?
    weak var dataSource: MediaLinkDataSource?
    private var buffer: CircularBuffer<CMSampleBuffer> = .init(256)
    private lazy var choreographer: Choreographer = {
        var choreographer = DisplayLinkChoreographer()
        choreographer.delegate = self
        return choreographer
    }()
    private let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.DisplayLinkedQueue.lock")
    private(set) var isRunning: Atomic<Bool> = .init(false)

    func enqueue(_ buffer: CMSampleBuffer) {
        guard buffer.presentationTimeStamp != .invalid else {
            return
        }
        _ = self.buffer.append(buffer)
    }
}

extension MediaLink: ChoreographerDelegate {
    // MARK: ChoreographerDelegate
    func choreographer(_ choreographer: Choreographer, didFrame duration: Double) {
        var frameCount = 0
        while !buffer.isEmpty {
            guard let first = buffer.first else {
                continue
            }
            if first.presentationTimeStamp.seconds == 0.0 {
                choreographer.clear()
            }
            if first.presentationTimeStamp.seconds <= duration {
                delegate?.mediaLink(self, didDequeue: first)
                frameCount += 1
                buffer.removeFirst()
            } else {
                if 2 < frameCount {
                    logger.info("droppedFrame: \(frameCount)")
                }
                break
            }
        }
    }
}

extension MediaLink: Running {
    // MARK: Running
    func startRunning() {
        lockQueue.async {
            guard !self.isRunning.value else {
                return
            }
            self.choreographer.startRunning()
            self.isRunning.mutate { $0 = true }
        }
    }

    func stopRunning() {
        lockQueue.async {
            guard self.isRunning.value else {
                return
            }
            self.choreographer.stopRunning()
            self.dataSource = nil
            self.buffer.removeAll()
            self.isRunning.mutate { $0 = false }
        }
    }
}
