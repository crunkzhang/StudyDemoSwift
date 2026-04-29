import Foundation

public final class RunLoopDetector: CatonDetectable {

    public var onCatonDetected: ((CatonEvent) -> Void)?

    private let threshold: TimeInterval
    private var observer: CFRunLoopObserver?
    private var monitorThread: Thread?
    private let semaphore = DispatchSemaphore(value: 0)

    /// 当前 RunLoop activity，由主线程 Observer 更新
    private var currentActivity: Int = 0
    private var isRunning = false

    public init(threshold: TimeInterval) {
        self.threshold = threshold
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true

        // 在主线程注册 RunLoop Observer
        let activities: CFRunLoopActivity = [.beforeSources, .afterWaiting, .beforeWaiting]
        observer = CFRunLoopObserverCreateWithHandler(
            kCFAllocatorDefault,
            activities.rawValue,
            true,  // repeats
            0      // order
        ) { [weak self] _, activity in
            guard let self = self else { return }
            self.currentActivity = Int(activity.rawValue)
            self.semaphore.signal()
        }

        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)

        // 启动监控子线程
        let thread = Thread { [weak self] in
            self?.monitorLoop()
        }
        thread.name = "CatonMonitorKit.RunLoopDetector"
        thread.qualityOfService = .userInitiated
        monitorThread = thread
        thread.start()
    }

    public func stop() {
        isRunning = false
        semaphore.signal()

        if let observer = observer {
            CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, .commonModes)
            self.observer = nil
        }
        monitorThread = nil
    }

    // MARK: - 监控循环

    private func monitorLoop() {
        while isRunning {
            let result = semaphore.wait(timeout: .now() + threshold)

            if result == .timedOut && isRunning {
                // 只在 beforeSources 和 afterWaiting 阶段超时才算卡顿
                // beforeWaiting 表示主线程即将空闲，超时是正常的
                let activity = currentActivity
                let isBeforeSources = (activity & Int(CFRunLoopActivity.beforeSources.rawValue)) != 0
                let isAfterWaiting = (activity & Int(CFRunLoopActivity.afterWaiting.rawValue)) != 0

                if isBeforeSources || isAfterWaiting {
                    let stack = StackCapture.captureMainThread()
                    let threadInfo = ThreadInfoCollector.collect()
                    let event = CatonEvent(
                        type: .runLoop,
                        duration: threshold * 1000,
                        stackTrace: stack,
                        threadInfo: threadInfo,
                        page: nil,
                        isAppInBackground: false
                    )
                    onCatonDetected?(event)
                }
            }
        }
    }
}

// MARK: - ThreadInfoCollector

enum ThreadInfoCollector {
    static func collect() -> ThreadInfo {
        var threadBasicInfo = thread_basic_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<thread_basic_info_data_t>.size / MemoryLayout<natural_t>.size)
        var mainThread: thread_t = 0

        // 获取主线程
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        if task_threads(mach_task_self_, &threadList, &threadCount) == KERN_SUCCESS,
           let threads = threadList, threadCount > 0 {
            mainThread = threads[0]
            let size = vm_size_t(MemoryLayout<thread_t>.size * Int(threadCount))
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threads), size)
        }

        var cpuUsage: Double = 0
        if mainThread != 0 {
            let kr = withUnsafeMutablePointer(to: &threadBasicInfo) { ptr in
                ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                    thread_info(mainThread, thread_flavor_t(THREAD_BASIC_INFO), intPtr, &count)
                }
            }
            if kr == KERN_SUCCESS {
                cpuUsage = Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100
            }
        }

        // 进程线程数
        var tList: thread_act_array_t?
        var tCount: mach_msg_type_number_t = 0
        var threadTotal = 0
        if task_threads(mach_task_self_, &tList, &tCount) == KERN_SUCCESS {
            threadTotal = Int(tCount)
            if let list = tList {
                vm_deallocate(mach_task_self_, vm_address_t(bitPattern: list),
                              vm_size_t(MemoryLayout<thread_t>.size * Int(tCount)))
            }
        }

        return ThreadInfo(cpuUsage: cpuUsage, threadCount: threadTotal)
    }
}
