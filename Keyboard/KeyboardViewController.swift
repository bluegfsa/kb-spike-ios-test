import UIKit
import Darwin

/// 读进程内存：footprint（预算口径）+ internal（dirty/内部近似 live）。
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

/// 最小键盘扩展：内存读数 + 拼音 mmap 查词 + 堆探测对照 + librime 部署并打拼音出字。
final class KeyboardViewController: UIInputViewController {
    private let titleLabel = UILabel()
    private let memLabel = UILabel()
    private let dictLabel = UILabel()
    private let pinyinLabel = UILabel()
    private let rimeLabel = UILabel()
    private let nextKeyboardButton = UIButton(type: .system)
    private let probeButton = UIButton(type: .system)
    private var timer: Timer?
    private var peakMB: Double = 0
    private var dict: MmapDict?
    private var pinyin: PinyinEngine?
    private var didInitRime = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGray6

        titleLabel.text = "双译键盘 (spike)"
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)

        memLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        memLabel.textColor = .systemRed
        memLabel.numberOfLines = 2
        memLabel.text = "内存: —"

        dictLabel.font = .systemFont(ofSize: 11); dictLabel.textColor = .darkGray; dictLabel.numberOfLines = 2
        pinyinLabel.font = .systemFont(ofSize: 11); pinyinLabel.textColor = .systemBlue; pinyinLabel.numberOfLines = 2
        rimeLabel.font = .systemFont(ofSize: 11); rimeLabel.textColor = .systemGreen; rimeLabel.numberOfLines = 4

        let stack = UIStackView(arrangedSubviews: [titleLabel, memLabel, dictLabel, pinyinLabel, rimeLabel])
        stack.axis = .vertical; stack.alignment = .center; stack.spacing = 5
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        nextKeyboardButton.setTitle("🌐", for: .normal)
        nextKeyboardButton.addTarget(self, action: #selector(advanceToNextInputMode), for: .touchUpInside)
        nextKeyboardButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nextKeyboardButton)

        probeButton.setTitle("堆探测", for: .normal)
        probeButton.titleLabel?.font = .systemFont(ofSize: 11)
        probeButton.addTarget(self, action: #selector(runHeapProbe), for: .touchUpInside)
        probeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(probeButton)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            nextKeyboardButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            nextKeyboardButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
            probeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            probeButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
        ])

        loadDict()
        loadPinyin()
        runRimeDeploy()
        updateMem()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateMem()
        }
    }

    private func loadDict() {
        guard let url = Bundle(for: KeyboardViewController.self).url(forResource: "dict", withExtension: "txt") else {
            dictLabel.text = "词库资源未打包"; return
        }
        dict = MmapDict(url: url)
        guard let d = dict else { dictLabel.text = "词库 mmap 失败"; return }
        let hits = d.prefix("hello", limit: 3)
        dictLabel.text = "mmap 词库 \(d.count) 条 · hello → " + (hits.first ?? "无命中")
    }

    private func loadPinyin() {
        guard let url = Bundle(for: KeyboardViewController.self).url(forResource: "pinyin", withExtension: "txt") else {
            pinyinLabel.text = "拼音表未打包"; return
        }
        pinyin = PinyinEngine(url: url)
        guard let p = pinyin else { pinyinLabel.text = "拼音 mmap 失败"; return }
        let hits = p.candidates("ni", limit: 6)
        pinyinLabel.text = "拼音 \(p.count) 条 · ni → " + (hits.prefix(4).joined(separator: " / "))
    }

    /// 后台部署 librime（编译词典可能耗时数秒，避免阻塞扩展主线程被 watchdog 杀）。
    private func runRimeDeploy() {
        guard !didInitRime else { return }
        didInitRime = true
        rimeLabel.text = "librime 部署中…（首次编译词典）"
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let shared = base.appendingPathComponent("rime/shared")
        let user = base.appendingPathComponent("rime/user")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let status = RimeProbeType(shared.path, user.path)
            DispatchQueue.main.async { self?.rimeLabel.text = status }
        }
    }

    @objc private func runHeapProbe() {
        guard let url = Bundle(for: KeyboardViewController.self).url(forResource: "pinyin", withExtension: "txt") else { return }
        let n = HeapDictProbe.build(url: url)
        let fp = vmInfoMB()?.footprint ?? -1
        probeButton.setTitle("已入堆 \(n)", for: .normal)
        pinyinLabel.text = "堆探测: 全量解析 \(n) 键进内存, footprint≈" + String(format: "%.1fMB", fp)
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
        timer?.invalidate(); timer = nil
    }
}
