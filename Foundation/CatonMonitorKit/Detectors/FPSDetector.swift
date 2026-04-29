import UIKit
import QuartzCore

public final class FPSDetector: CatonDetectable {

    public var onCatonDetected: ((CatonEvent) -> Void)?
    /// 实时 FPS 值回调（给浮窗用）
    public var onFPSUpdate: ((Int) -> Void)?

    private let dropThreshold: Int
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount: Int = 0
    /// 连续低帧计数（连续 3 秒低于阈值才触发事件）
    private var consecutiveLowCount: Int = 0
    private static let triggerSeconds = 3

    public init(dropThreshold: Int) {
        self.dropThreshold = dropThreshold
    }

    public func start() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
        lastTimestamp = 0
        frameCount = 0
        consecutiveLowCount = 0
    }

    public func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
            return
        }

        frameCount += 1
        let elapsed = link.timestamp - lastTimestamp

        // 每秒计算一次 FPS
        if elapsed >= 1.0 {
            let fps = Int(round(Double(frameCount) / elapsed))
            frameCount = 0
            lastTimestamp = link.timestamp

            onFPSUpdate?(fps)

            if fps < dropThreshold {
                consecutiveLowCount += 1
            } else {
                consecutiveLowCount = 0
            }

            // 连续低帧达到阈值才触发
            if consecutiveLowCount >= FPSDetector.triggerSeconds {
                let stack = StackCapture.captureMainThread()
                let threadInfo = ThreadInfoCollector.collect()
                let event = CatonEvent(
                    type: .fps,
                    duration: Double(consecutiveLowCount) * 1000,
                    stackTrace: stack,
                    threadInfo: threadInfo,
                    page: nil,
                    isAppInBackground: false
                )
                onCatonDetected?(event)
                consecutiveLowCount = 0
            }
        }
    }

    deinit {
        stop()
    }
}
