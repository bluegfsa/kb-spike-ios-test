import UIKit
import Darwin

/// 读进程内存：footprint（预算口径）+ internal（dirty/内部占用，近似 live 申请量）。
func vmInfoMB() -> (footprint: Double, internalMem: Double)? {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
    let kr = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    guard kr == KERN_SUCCESS else { return nil }
    return (Double(info.phys_footprint) / 1048576.0, Double(info.internal) / 1048576.0)
}

/// 最小键盘扩展 + 内存读数 + mmap 词典样例。
/// 键盘顶部/中部显示 footprint、峰值、内部(dirty) 占用；并演示 mmap 词库前缀查词。
final class KeyboardViewController: UIInputViewController {
    private let titleLabel = UILabel()
    private let memLabel = UILabel()
    private let dictLabel = UILabel()
    private let nextKeyboardButton = UIButton(type: .system)
    private var timer: Timer?
    private var peakMB: Double = 0
    private var dict: MmapDict?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGray6

        titleLabel.text = "双译键盘 (spike)"
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)

        memLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        memLabel.textColor = .systemRed
        memLabel.numberOfLines = 2
        memLabel.text = "内存: —"

        dictLabel.font = .systemFont(ofSize: 11)
        dictLabel.textColor = .darkGray
        dictLabel.numberOfLines = 2

        let stack = UIStackView(arrangedSubviews: [titleLabel, memLabel, dictLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        nextKeyboardButton.setTitle("🌐", for: .normal)
        nextKeyboardButton.addTarget(self, action: #selector(advanceToNextInputMode), for: .touchUpInside)
        nextKeyboardButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nextKeyboardButton)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            nextKeyboardButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            nextKeyboardButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
        ])

        loadDict()
        updateMem()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateMem()
        }
    }

    private func loadDict() {
        guard let url = Bundle(for: KeyboardViewController.self).url(forResource: "dict", withExtension: "txt") else {
            dictLabel.text = "词库资源未打包"
            return
        }
        dict = MmapDict(url: url)
        guard let d = dict else { dictLabel.text = "词库 mmap 失败"; return }
        let hits = d.prefix("hello", limit: 3)
        dictLabel.text = "mmap 词库 \(d.count) 条 · hello → " + (hits.first ?? "无命中")
    }

    private func updateMem() {
        guard let v = vmInfoMB() else { memLabel.text = "内存: 不可读"; return }
        if v.footprint > peakMB { peakMB = v.footprint }
        memLabel.text = String(
            format: "footprint %.1f MB (峰值 %.1f, 硬顶60)\n内部/dirty %.1f MB",
            v.footprint, peakMB, v.internalMem
        )
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        timer?.invalidate()
        timer = nil
    }
}
