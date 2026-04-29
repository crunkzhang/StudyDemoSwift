import Foundation
import MachO

public final class StackCapture {

    /// 最大回溯帧数
    private static let maxFrames = 128

    /// 从子线程采集主线程堆栈
    /// - Returns: 堆栈帧字符串数组（Debug 下符号化，Release 下原始地址）
    public static func captureMainThread() -> [String] {
        guard let mainThread = getMainMachThread() else { return [] }
        let addresses = getStackAddresses(thread: mainThread)
        return symbolicate(addresses)
    }

    // MARK: - 获取主线程 Mach Thread

    private static func getMainMachThread() -> thread_t? {
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0

        let kr = task_threads(mach_task_self_, &threadList, &threadCount)
        guard kr == KERN_SUCCESS, let threads = threadList, threadCount > 0 else {
            return nil
        }

        // 主线程通常是第一个线程
        let mainThread = threads[0]

        // 释放线程列表内存
        let size = vm_size_t(MemoryLayout<thread_t>.size * Int(threadCount))
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threads), size)

        return mainThread
    }

    // MARK: - 获取栈帧地址（条件编译 arm64 / x86_64）

    private static func getStackAddresses(thread: thread_t) -> [UnsafeRawPointer] {
        #if arch(arm64)
        return getStackAddresses_arm64(thread: thread)
        #elseif arch(x86_64)
        return getStackAddresses_x86_64(thread: thread)
        #else
        return []
        #endif
    }

    #if arch(arm64)
    private static func getStackAddresses_arm64(thread: thread_t) -> [UnsafeRawPointer] {
        var state = arm_thread_state64_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<arm_thread_state64_t>.size / MemoryLayout<natural_t>.size
        )

        let kr = withUnsafeMutablePointer(to: &state) { ptr in
            ptr.withMemoryRebound(to: natural_t.self, capacity: Int(count)) { natPtr in
                thread_get_state(thread, ARM_THREAD_STATE64, natPtr, &count)
            }
        }

        guard kr == KERN_SUCCESS else { return [] }

        var addresses: [UnsafeRawPointer] = []

        // PC 是当前执行地址
        let pc = UInt(state.__pc)
        if pc != 0, let ptr = UnsafeRawPointer(bitPattern: pc) {
            addresses.append(ptr)
        }

        // LR 是返回地址
        let lr = UInt(state.__lr)
        if lr != 0, let ptr = UnsafeRawPointer(bitPattern: lr) {
            addresses.append(ptr)
        }

        // 沿 FP 链回溯
        var fp = UInt(state.__fp)
        while fp != 0 && addresses.count < maxFrames {
            guard let framePtr = UnsafePointer<UInt>(bitPattern: fp) else { break }

            // FP 指向的栈帧结构：[previous_fp, return_address]
            let returnAddress = framePtr.advanced(by: 1).pointee
            if returnAddress == 0 { break }

            if let ptr = UnsafeRawPointer(bitPattern: returnAddress) {
                addresses.append(ptr)
            }

            let previousFP = framePtr.pointee
            // 防止死循环：FP 必须单调递增（栈向低地址增长时 FP 向高地址回溯）
            if previousFP <= fp { break }
            fp = previousFP
        }

        return addresses
    }
    #endif

    #if arch(x86_64)
    private static func getStackAddresses_x86_64(thread: thread_t) -> [UnsafeRawPointer] {
        var state = x86_thread_state64_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<x86_thread_state64_t>.size / MemoryLayout<natural_t>.size
        )

        let kr = withUnsafeMutablePointer(to: &state) { ptr in
            ptr.withMemoryRebound(to: natural_t.self, capacity: Int(count)) { natPtr in
                thread_get_state(thread, x86_THREAD_STATE64, natPtr, &count)
            }
        }

        guard kr == KERN_SUCCESS else { return [] }

        var addresses: [UnsafeRawPointer] = []

        // RIP 是当前执行地址
        let rip = UInt(state.__rip)
        if rip != 0, let ptr = UnsafeRawPointer(bitPattern: rip) {
            addresses.append(ptr)
        }

        // 沿 RBP 链回溯
        var rbp = UInt(state.__rbp)
        while rbp != 0 && addresses.count < maxFrames {
            guard let framePtr = UnsafePointer<UInt>(bitPattern: rbp) else { break }

            // x86_64 栈帧：[previous_rbp, return_address]
            let returnAddress = framePtr.advanced(by: 1).pointee
            if returnAddress == 0 { break }

            if let ptr = UnsafeRawPointer(bitPattern: returnAddress) {
                addresses.append(ptr)
            }

            let previousRBP = framePtr.pointee
            if previousRBP <= rbp { break }
            rbp = previousRBP
        }

        return addresses
    }
    #endif

    // MARK: - 符号化

    private static func symbolicate(_ addresses: [UnsafeRawPointer]) -> [String] {
        return addresses.enumerated().map { index, addr in
            #if DEBUG
            return debugSymbol(addr, index: index)
            #else
            return releaseSymbol(addr, index: index)
            #endif
        }
    }

    private static func debugSymbol(_ addr: UnsafeRawPointer, index: Int) -> String {
        var info = Dl_info()
        if dladdr(addr, &info) != 0 {
            let symbolName = info.dli_sname.map { String(cString: $0) } ?? "???"
            let offset = addr - UnsafeRawPointer(info.dli_saddr)
            let imageName = info.dli_fname.map {
                String(cString: $0).components(separatedBy: "/").last ?? "???"
            } ?? "???"
            return String(format: "%-4d %-30s 0x%016lx %@ + %d",
                          index, (imageName as NSString).utf8String!, UInt(bitPattern: addr),
                          symbolName, offset)
        }
        return String(format: "%-4d ??? 0x%016lx", index, UInt(bitPattern: addr))
    }

    private static func releaseSymbol(_ addr: UnsafeRawPointer, index: Int) -> String {
        var info = Dl_info()
        if dladdr(addr, &info) != 0 {
            let imageName = info.dli_fname.map {
                String(cString: $0).components(separatedBy: "/").last ?? "???"
            } ?? "???"
            let slide = UInt(bitPattern: addr) - UInt(bitPattern: info.dli_fbase)
            return "\(imageName) 0x\(String(slide, radix: 16))"
        }
        return "0x\(String(UInt(bitPattern: addr), radix: 16))"
    }
}
