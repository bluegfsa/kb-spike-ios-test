import UIKit

/// 键盘内设置面板（UI 定稿）：声音/震动均为「拨钮开关」，全图标化、无文字标题、纯黑白灰（不用蓝）。
/// 点开关＝一次性动效（不循环）：声音＝声波弹一下/斜杠画出；震动＝机身抖一下/斜杠画出；✓ 收起。
/// 调「声音」只出声、调「震动」只震不出声；改完即存 config.json（重启键盘仍在）。
final class KeyboardSettingsPanel: UIView {
    var onClose: (() -> Void)?

    private let soundIcon = SettingsIconView(kind: .sound)
    private let hapticIcon = SettingsIconView(kind: .vibration)
    private let soundToggle = SettingsToggleControl()
    private let hapticToggle = SettingsToggleControl()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        // ① 半透明毛玻璃背景：.systemMaterial + 覆盖色（浅 白0.55 / 深 #2C2C2E 0.55）；注意键盘扩展采不到宿主 App 画面，只能透键盘底色。
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)
        let overlay = UIView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 44/255, green: 44/255, blue: 46/255, alpha: 0.55)
                : UIColor(white: 1, alpha: 0.55)
        }
        addSubview(overlay)
        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            overlay.topAnchor.constraint(equalTo: topAnchor),
            overlay.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        let s = SettingsStore.shared()
        soundToggle.isOn = s.keySoundLevel > 0
        hapticToggle.isOn = s.keyHapticLevel > 0
        soundIcon.isOn = soundToggle.isOn
        hapticIcon.isOn = hapticToggle.isOn
        soundToggle.addTarget(self, action: #selector(soundChanged), for: .valueChanged)
        hapticToggle.addTarget(self, action: #selector(hapticChanged), for: .valueChanged)

        let soundRow = makeRow(iconView: soundIcon, toggle: soundToggle)
        let hapticRow = makeRow(iconView: hapticIcon, toggle: hapticToggle)
        let doneWrap = makeDone()

        let stack = UIStackView(arrangedSubviews: [soundRow, hapticRow, doneWrap])
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16), // ① 设置页整体下移：首卡上沿距键盘上沿≈16pt
        ])
    }

    /// 一行：白底圆角卡，左图标、右拨钮。
    private func makeRow(iconView: SettingsIconView, toggle: SettingsToggleControl) -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor { t in
            // UI §二十：卡片 rgba(255,255,255,0.72)（浅）/ #2C2C2E 0.72（深）
            t.userInterfaceStyle == .dark
                ? UIColor(red: 44/255, green: 44/255, blue: 46/255, alpha: 0.72)
                : UIColor(white: 1, alpha: 0.72)
        }
        card.layer.cornerRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false
        iconView.translatesAutoresizingMaskIntoConstraints = false
        toggle.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(iconView)
        card.addSubview(toggle)
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 78),
            iconView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            iconView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),
            toggle.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            toggle.centerYAnchor.constraint(equalTo: card.centerYAnchor),
        ])
        return card
    }

    /// 底部 ✓ 完成按钮（图标化）。
    private func makeDone() -> UIView {
        let doneWrap = UIView()
        doneWrap.translatesAutoresizingMaskIntoConstraints = false

        let doneIcon = SettingsIconView(kind: .check)
        doneIcon.isOn = true

        let done = UIButton(type: .system)
        done.backgroundColor = .clear
        done.accessibilityLabel = "完成"
        done.translatesAutoresizingMaskIntoConstraints = false
        done.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        doneIcon.translatesAutoresizingMaskIntoConstraints = false
        done.addSubview(doneIcon)
        doneWrap.addSubview(done)

        NSLayoutConstraint.activate([
            done.widthAnchor.constraint(equalToConstant: 52),
            done.heightAnchor.constraint(equalToConstant: 52),
            done.centerXAnchor.constraint(equalTo: doneWrap.centerXAnchor),
            done.topAnchor.constraint(equalTo: doneWrap.topAnchor),
            done.bottomAnchor.constraint(equalTo: doneWrap.bottomAnchor),
            doneIcon.centerXAnchor.constraint(equalTo: done.centerXAnchor),
            doneIcon.centerYAnchor.constraint(equalTo: done.centerYAnchor),
            doneIcon.widthAnchor.constraint(equalToConstant: 34),
            doneIcon.heightAnchor.constraint(equalToConstant: 34),
        ])
        return doneWrap
    }

    @objc private func soundChanged() {
        SettingsStore.update { $0.keySoundLevel = self.soundToggle.isOn ? 1 : 0 }
        soundIcon.isOn = soundToggle.isOn
        soundIcon.playToggleAnimation(toOn: soundToggle.isOn)
        if soundToggle.isOn { KeyFeedback.shared.playSound() } // 调声音：只出声
    }

    @objc private func hapticChanged() {
        SettingsStore.update { $0.keyHapticLevel = self.hapticToggle.isOn ? 1 : 0 }
        hapticIcon.isOn = hapticToggle.isOn
        hapticIcon.playToggleAnimation(toOn: hapticToggle.isOn)
        if hapticToggle.isOn { KeyFeedback.shared.playHaptic() } // 调震动：只震不出声
    }

    @objc private func closeTapped() { onClose?() }
}
