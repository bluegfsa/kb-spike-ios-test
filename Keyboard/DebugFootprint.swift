import Foundation
import Darwin

/// 调试用内存探针：读取本进程的 phys_footprint（与 S4 实测同口径，单位 MB）。
/// 仅用于真机验收读数，不影响正式逻辑。
enum DebugFootprint {
    private static var _peak: Double = 0

    /// 当前进程物理内存占用（MB）；失败返回 -1。
    static func currentMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size
        )
        let kr = withUnsafeMutablePointer(to: &info) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { p in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), p, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return -1 }
        return Double(info.phys_footprint) / 1024.0 / 1024.0
    }

    /// 采样一次并更新峰值，返回当前值（MB）。
    @discardableResult
    static func sample() -> Double {
        let cur = currentMB()
        if cur > _peak { _peak = cur }
        return cur
    }

    /// 观测到的峰值（MB）。
    static var peakMB: Double { return _peak }
}
