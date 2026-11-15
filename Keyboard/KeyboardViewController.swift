import UIKit
import Darwin

/// 读取当前进程物理内存占用（phys_footprint，MB）——键盘扩展的实际内存预算看这个。
func currentFootprintMB() -> Double? {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
    let kr = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    guard kr == KERN_SUCCESS else { return nil }
    return Double(info.phys_footprint) / 1024.0 / 1024.0
}

/// 最小键盘扩展 + 内存读数（S1/S2 打包验证 + S4 真机内存观测）。
/// 键盘顶部实时显示「当前 / 峰值」phys_footprint，用户打字时即可看峰值。
final class KeyboardViewController: UIInputViewController {
    private let titleLabel = UILabel()
    private let memLabel = UILabel()
    private let nextKeyboardButton = UIButton(type: .system)
    private var timer: Timer?
    private var peakMB: Double = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGray6

        titleLabel.text = "双译键盘 (spike)"
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        memLabel.text = "内存: —"
        memLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        memLabel.textColor = .systemRed
        memLabel.textAlignment = .center
        memLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(memLabel)

        nextKeyboardButton.setTitle("🌐", for: .normal)
        nextKeyboardButton.addTarget(self, action: #selector(advanceToNextInputMode), for: .touchUpInside)
        nextKeyboardButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nextKeyboardButton)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            memLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            memLabel.bottomAnchor.constraint(equalTo: view.topAnchor, constant: 28),
            nextKeyboardButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            nextKeyboardButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
        ])

        updateMem()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateMem()
        }
    }

    private func updateMem() {
        guard let mb = currentFootprintMB() else { memLabel.text = "内存: 不可读"; return }
        if mb > peakMB { peakMB = mb }
        memLabel.text = String(format: "内存: %.1f MB  峰值: %.1f MB (硬顶60)", mb, peakMB)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        timer?.invalidate()
        timer = nil
    }
}
