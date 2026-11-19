import UIKit

/// 键盘内设置面板（④）：按键声音 开/关 ＋ 按键震动 开/关（都为开关制，去掉 3/4 档）。
/// 键盘内弹出、不跳 App、占满原键盘区不抖动；改完即存 config.json（重启键盘仍在）。
/// 调「声音」只出声、调「震动」只震动（不发声）。
final class KeyboardSettingsPanel: UIView {
    var onClose: (() -> Void)?

    private let soundControl = UISegmentedControl(items: ["关", "开"])
    private let hapticControl = UISegmentedControl(items: ["关", "开"])

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = KBColor.background
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        let title = UILabel()
        title.text = "键盘设置"
        title.font = .systemFont(ofSize: 17, weight: .semibold)
        title.textColor = KBColor.keyText
        title.textAlignment = .center

        let soundLabel = UILabel()
        soundLabel.text = "按键声音"
        soundLabel.font = .systemFont(ofSize: 15)
        soundLabel.textColor = KBColor.keyText
        soundLabel.setContentHuggingPriority(.required, for: .horizontal)

        let hapticLabel = UILabel()
        hapticLabel.text = "按键震动"
        hapticLabel.font = .systemFont(ofSize: 15)
        hapticLabel.textColor = KBColor.keyText
        hapticLabel.setContentHuggingPriority(.required, for: .horizontal)

        let s = SettingsStore.shared()
        soundControl.selectedSegmentIndex = s.keySoundLevel > 0 ? 1 : 0
        hapticControl.selectedSegmentIndex = s.keyHapticLevel > 0 ? 1 : 0
        soundControl.addTarget(self, action: #selector(soundChanged), for: .valueChanged)
        hapticControl.addTarget(self, action: #selector(hapticChanged), for: .valueChanged)

        let done = UIButton(type: .system)
        done.setTitle("完成", for: .normal)
        done.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        done.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        func row(_ label: UILabel, _ control: UIView) -> UIStackView {
            let h = UIStackView(arrangedSubviews: [label, control])
            h.axis = .horizontal
            h.spacing = 12
            h.alignment = .center
            return h
        }

        let stack = UIStackView(arrangedSubviews: [title, row(soundLabel, soundControl), row(hapticLabel, hapticControl), done])
        stack.axis = .vertical
        stack.spacing = 18
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @objc private func soundChanged() {
        SettingsStore.update { $0.keySoundLevel = self.soundControl.selectedSegmentIndex }
        KeyFeedback.shared.playSound() // 调声音：只出声（原生键音）
    }

    @objc private func hapticChanged() {
        SettingsStore.update { $0.keyHapticLevel = self.hapticControl.selectedSegmentIndex }
        KeyFeedback.shared.playHaptic() // 调震动：只震动、绝不出声
    }

    @objc private func closeTapped() { onClose?() }
}
