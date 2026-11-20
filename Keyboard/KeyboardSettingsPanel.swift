import UIKit
import AudioToolbox

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
        backgroundColor = KBColor.background
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
        let diagRow = makeDiagnostic()   // 临时：震动诊断按钮（正式版移除）
        let doneWrap = makeDone()

        let stack = UIStackView(arrangedSubviews: [soundRow, hapticRow, diagRow, doneWrap])
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    /// 一行：白底圆角卡，左图标、右拨钮。
    private func makeRow(iconView: SettingsIconView, toggle: SettingsToggleControl) -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor { t in
            // 浅色白卡；深色取定稿 §四 的键盘键色 #636366（与 #2C2C2E 面板底留色差）
            t.userInterfaceStyle == .dark ? UIColor(red: 99/255, green: 99/255, blue: 102/255, alpha: 1) : .white
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

    /// 【临时诊断】一排按钮并列试不同震动路径：长震(Vibrate) / 1519 / 1520 / 1521。
    /// 仅供定位"哪条能短震"，正式版务必删除（1519-1521 为未公开 ID，仅测试用）。
    private func makeDiagnostic() -> UIView {
        let wrap = UIView()
        wrap.translatesAutoresizingMaskIntoConstraints = false
        let label = UILabel()
        label.text = "震动诊断(临时)"
        label.font = .systemFont(ofSize: 12)
        label.textColor = .systemGray
        label.textAlignment = .center

        func mk(_ title: String, _ id: SystemSoundID) -> UIButton {
            let b = UIButton(type: .system)
            b.setTitle(title, for: .normal)
            b.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
            b.setTitleColor(.label, for: .normal)
            b.layer.borderColor = UIColor.systemGray.cgColor
            b.layer.borderWidth = 1
            b.layer.cornerRadius = 8
            b.translatesAutoresizingMaskIntoConstraints = false
            b.widthAnchor.constraint(equalToConstant: 62).isActive = true
            b.heightAnchor.constraint(equalToConstant: 34).isActive = true
            b.addAction(UIAction { _ in KeyFeedback.shared.debugPlay(id) }, for: .touchUpInside)
            return b
        }

        let row = UIStackView(arrangedSubviews: [
            mk("短震1519", 1519), mk("长震", kSystemSoundID_Vibrate)
        ])
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        row.distribution = .equalSpacing

        let stack = UIStackView(arrangedSubviews: [label, row])
        stack.axis = .vertical
        stack.spacing = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        wrap.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: wrap.topAnchor),
            stack.bottomAnchor.constraint(equalTo: wrap.bottomAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: wrap.leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: wrap.trailingAnchor),
            stack.centerXAnchor.constraint(equalTo: wrap.centerXAnchor),
        ])
        return wrap
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
