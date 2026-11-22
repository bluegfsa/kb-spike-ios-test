import UIKit

/// 添加键盘教程 · 纯动画屏（零文字说明，仅图标控件）。
/// 5 幕模拟 iOS 设置路径：设置→通用→键盘→添加新键盘→点「语桥输入法」开关拨开打勾。
/// **播一轮停末帧（不自动循环）**；可「↺ 重播」从头放、「✕ 跳过」退出；减弱动态时退化静态分镜淡入。
/// 仅用系统 UIKit/CA 实现，无第三方依赖。
final class TutorialViewController: UIViewController {
    /// 结束（跳过或播完点跳过）回调；nil 时自行 dismiss。
    var onFinish: (() -> Void)?

    private struct Scene {
        let title: String        // 模拟页导航标题
        let rows: [String]       // 该页可见行
        let highlight: Int       // 高亮行 index
        let toggle: Bool         // 是否末幕（开关拨动 + 勾）
    }
    private let scenes: [Scene] = [
        Scene(title: L10n.t("设置", "Settings"),
              rows: [L10n.t("飞行模式", "Airplane Mode"), L10n.t("无线局域网", "Wi-Fi"), L10n.t("蓝牙", "Bluetooth"), L10n.t("蜂窝网络", "Cellular"), L10n.t("通用", "General"), L10n.t("辅助功能", "Accessibility")],
              highlight: 4, toggle: false),
        Scene(title: L10n.t("‹ 通用", "‹ General"),
              rows: [L10n.t("关于本机", "About"), L10n.t("软件更新", "Software Update"), L10n.t("键盘", "Keyboard"), L10n.t("字体", "Fonts"), L10n.t("语言与地区", "Language & Region")],
              highlight: 2, toggle: false),
        Scene(title: L10n.t("‹ 键盘", "‹ Keyboard"),
              rows: [L10n.t("键盘  2", "Keyboards  2"), L10n.t("文本替换", "Text Replacement"), L10n.t("单手键盘", "One Handed")],
              highlight: 0, toggle: false),
        Scene(title: L10n.t("‹ 键盘", "‹ Keyboard"),
              rows: [L10n.t("英文（美国）", "English (US)"), L10n.t("表情符号", "Emoji"), L10n.t("添加新键盘", "Add New Keyboard")],
              highlight: 2, toggle: false),
        Scene(title: L10n.t("‹ 添加新键盘", "‹ Add New Keyboard"),
              rows: [L10n.t("语桥输入法", "WordBridge"), L10n.t("拼音 — 全键盘", "Pinyin — QWERTY"), L10n.t("双拼", "Shuangpin")],
              highlight: 0, toggle: true),
    ]

    /// 强调色：用户定「品牌黑白灰」= #3C3C43；改回系统蓝只改这一行 (#0A84FF → .systemBlue)。零成本切色。
    private let accent = UIColor(red: 60/255.0, green: 60/255.0, blue: 67/255.0, alpha: 1)

    private let rowH: CGFloat = 44
    private let navH: CGFloat = 52
    private let total: CFTimeInterval = 13.0

    private let stage = UIView()
    private let navBar = UIView()
    private let navTitle = UILabel()
    private let rowsStack = UIStackView()
    private let ring = UIView()
    private let finger = UIView()
    private let switchView = UISwitch()
    private let checkView = UIImageView()
    private let replayBtn = UIButton(type: .system)
    private let skipBtn = UIButton(type: .system)
    private let dots = UIStackView()
    private var dotViews: [UIView] = []

    private var link: CADisplayLink?
    private var elapsed: CFTimeInterval = 0
    private var currentScene = -1
    private var rowsTopY: CGFloat = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        buildStage()
        buildControls()
        if UIAccessibility.isReduceMotionEnabled {
            buildReducedMotion()
        } else {
            startLoop()
        }
    }

    deinit { link?.invalidate() }

    // MARK: - 舞台（模拟系统设置页）
    private func buildStage() {
        stage.backgroundColor = .secondarySystemGroupedBackground
        stage.layer.cornerRadius = 26
        stage.clipsToBounds = true
        stage.translatesAutoresizingMaskIntoConstraints = false
        stage.isAccessibilityElement = false
        view.addSubview(stage)

        navBar.translatesAutoresizingMaskIntoConstraints = false
        navBar.backgroundColor = .secondarySystemGroupedBackground
        stage.addSubview(navBar)
        navTitle.font = .systemFont(ofSize: 17, weight: .semibold)
        navTitle.textColor = .label
        navTitle.translatesAutoresizingMaskIntoConstraints = false
        navBar.addSubview(navTitle)

        rowsStack.axis = .vertical
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        stage.addSubview(rowsStack)

        ring.layer.borderColor = accent.cgColor
        ring.layer.borderWidth = 2.5
        ring.layer.cornerRadius = 9
        ring.isUserInteractionEnabled = false
        ring.isHidden = true
        stage.addSubview(ring)

        finger.backgroundColor = UIColor.white
        finger.layer.borderColor = UIColor(white: 0.84, alpha: 1).cgColor
        finger.layer.borderWidth = 0.5
        finger.layer.cornerRadius = 13
        finger.layer.shadowColor = UIColor.black.cgColor
        finger.layer.shadowOpacity = 0.3
        finger.layer.shadowRadius = 6
        finger.layer.shadowOffset = CGSize(width: 0, height: 2)
        finger.isUserInteractionEnabled = false
        finger.isHidden = true
        stage.addSubview(finger)

        switchView.onTintColor = accent
        checkView.image = UIImage(systemName: "checkmark.circle.fill")
        checkView.tintColor = accent
        checkView.translatesAutoresizingMaskIntoConstraints = false
        checkView.isHidden = true
        stage.addSubview(checkView)

        NSLayoutConstraint.activate([
            stage.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            stage.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            stage.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stage.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -110),

            navBar.leadingAnchor.constraint(equalTo: stage.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: stage.trailingAnchor),
            navBar.topAnchor.constraint(equalTo: stage.topAnchor),
            navBar.heightAnchor.constraint(equalToConstant: navH),
            navTitle.centerXAnchor.constraint(equalTo: navBar.centerXAnchor),
            navTitle.centerYAnchor.constraint(equalTo: navBar.centerYAnchor),

            rowsStack.leadingAnchor.constraint(equalTo: stage.leadingAnchor, constant: 12),
            rowsStack.trailingAnchor.constraint(equalTo: stage.trailingAnchor, constant: -12),
            rowsStack.topAnchor.constraint(equalTo: navBar.bottomAnchor),
        ])
    }

    private func buildControls() {
        let cfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        styleIconButton(replayBtn, symbol: "arrow.counterclockwise", cfg: cfg, label: "重播教程")
        styleIconButton(skipBtn, symbol: "xmark", cfg: cfg, label: "跳过教程")
        replayBtn.addTarget(self, action: #selector(replayTapped), for: .touchUpInside)
        skipBtn.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        view.addSubview(replayBtn)
        view.addSubview(skipBtn)

        dots.axis = .horizontal
        dots.spacing = 8
        dots.alignment = .center
        dots.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dots)
        for _ in scenes {
            let d = UIView()
            d.backgroundColor = .tertiaryLabel
            d.layer.cornerRadius = 3.5
            d.translatesAutoresizingMaskIntoConstraints = false
            d.widthAnchor.constraint(equalToConstant: 7).isActive = true
            d.heightAnchor.constraint(equalToConstant: 7).isActive = true
            dots.addArrangedSubview(d)
            dotViews.append(d)
        }

        NSLayoutConstraint.activate([
            replayBtn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            replayBtn.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -36),
            replayBtn.widthAnchor.constraint(equalToConstant: 44),
            replayBtn.heightAnchor.constraint(equalToConstant: 44),
            skipBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            skipBtn.bottomAnchor.constraint(equalTo: replayBtn.bottomAnchor),
            skipBtn.widthAnchor.constraint(equalToConstant: 44),
            skipBtn.heightAnchor.constraint(equalToConstant: 44),
            dots.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            dots.centerYAnchor.constraint(equalTo: replayBtn.centerYAnchor),
        ])
    }

    private func styleIconButton(_ b: UIButton, symbol: String, cfg: UIImage.SymbolConfiguration, label: String) {
        b.setImage(UIImage(systemName: symbol, withConfiguration: cfg), for: .normal)
        b.tintColor = .label
        b.backgroundColor = .tertiarySystemBackground
        b.layer.cornerRadius = 22
        b.layer.shadowColor = UIColor.black.cgColor
        b.layer.shadowOpacity = 0.08
        b.layer.shadowRadius = 4
        b.layer.shadowOffset = CGSize(width: 0, height: 1)
        b.accessibilityLabel = label
        b.translatesAutoresizingMaskIntoConstraints = false
    }

    // MARK: - 循环
    private func startLoop() {
        link?.invalidate()
        elapsed = 0
        let l = CADisplayLink(target: self, selector: #selector(tick))
        l.add(to: .main, forMode: .common)
        link = l
    }

    @objc private func tick(_ l: CADisplayLink) {
        elapsed += l.targetTimestamp - l.timestamp
        if elapsed >= total {
            elapsed = total          // 播一轮停末帧，不自动循环
            l.invalidate(); link = nil
        }
        let p = elapsed / total
        let idx = sceneIndex(for: p)
        if idx != currentScene { enterScene(idx) }
        updateFinalToggle(progress: p)
    }

    private func sceneIndex(for p: CFTimeInterval) -> Int {
        let bounds: [CFTimeInterval] = [0, 0.16, 0.33, 0.49, 0.70, 1.0]
        for i in 0..<scenes.count where p >= bounds[i] && p < bounds[i + 1] { return i }
        return scenes.count - 1
    }

    private func enterScene(_ idx: Int) {
        currentScene = idx
        let s = scenes[idx]
        navTitle.text = s.title
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        switchView.removeFromSuperview()
        switchView.isOn = false
        checkView.isHidden = true
        for (i, txt) in s.rows.enumerated() {
            rowsStack.addArrangedSubview(makeRow(txt, trailingSwitch: s.toggle && i == 0))
        }
        updateDots(idx)
        layoutIfNeededNow()
        animateHighlight(row: s.highlight)
    }

    private func makeRow(_ text: String, trailingSwitch: Bool) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: rowH).isActive = true
        row.backgroundColor = .systemBackground
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: 16)
        l.textColor = .label
        l.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(l)
        NSLayoutConstraint.activate([
            l.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            l.centerYAnchor.constraint(equalTo: row.centerYAnchor),
        ])
        if trailingSwitch {
            switchView.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(switchView)
            NSLayoutConstraint.activate([
                switchView.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
                switchView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            ])
        } else {
            let chev = UIImageView(image: UIImage(systemName: "chevron.right"))
            chev.tintColor = .tertiaryLabel
            chev.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(chev)
            NSLayoutConstraint.activate([
                chev.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
                chev.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            ])
        }
        return row
    }

    private func layoutIfNeededNow() {
        stage.layoutIfNeeded()
        rowsTopY = navH
    }

    /// 高亮环 + 手指：定位到目标行，环呼吸脉冲、手指上浮回弹点一下。
    private func animateHighlight(row: Int) {
        guard row < rowsStack.arrangedSubviews.count else { ring.isHidden = true; finger.isHidden = true; return }
        let rowView = rowsStack.arrangedSubviews[row]
        // 目标行浅底（accent 12%）
        for (i, r) in rowsStack.arrangedSubviews.enumerated() {
            r.backgroundColor = (i == row) ? accent.withAlphaComponent(0.12) : .systemBackground
        }
        let f = rowView.convert(rowView.bounds, to: stage)
        ring.isHidden = false
        finger.isHidden = false
        ring.frame = f.insetBy(dx: 8, dy: 2)
        ring.layer.removeAllAnimations()
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 0.99; pulse.toValue = 1.02
        pulse.autoreverses = true; pulse.duration = 0.6; pulse.repeatCount = .greatestFiniteMagnitude
        ring.layer.add(pulse, forKey: "pulse")
        let op = CABasicAnimation(keyPath: "opacity")
        op.fromValue = 0.95; op.toValue = 0.4
        op.autoreverses = true; op.duration = 0.6; op.repeatCount = .greatestFiniteMagnitude
        ring.layer.add(op, forKey: "op")

        let target = CGPoint(x: f.midX, y: f.midY)
        finger.center = target
        finger.transform = CGAffineTransform(scaleX: 0.86, y: 0.86)
        UIView.animate(withDuration: 0.35, delay: 0.15, options: [.autoreverse, .repeat]) {
            self.finger.transform = CGAffineTransform(scaleX: 1.0, y: 1.0).translatedBy(x: 0, y: -3)
        }
    }

    private func updateFinalToggle(progress p: CFTimeInterval) {
        guard scenes.indices.contains(currentScene), scenes[currentScene].toggle else { return }
        // 幕5 相对总进度 ~0.835（=幕5 的 0.45 处）拨开关；到位后出 ✓
        if p >= 0.835 && !switchView.isOn {
            switchView.setOn(true, animated: true)
            checkView.isHidden = false
            let row = rowsStack.arrangedSubviews.first
            if let row {
                let f = row.convert(row.bounds, to: stage)
                checkView.frame = CGRect(x: f.maxX - 34, y: f.midY - 11, width: 22, height: 22)
            }
        }
    }

    private func updateDots(_ idx: Int) {
        for (i, d) in dotViews.enumerated() {
            let on = i == idx
            d.backgroundColor = on ? .label : .tertiaryLabel
            d.transform = on ? CGAffineTransform(scaleX: 1.5, y: 1.5) : .identity
        }
    }

    // MARK: - 减弱动态：静态分镜淡入、不循环不位移
    private func buildReducedMotion() {
        link?.invalidate()
        showSceneStatic(0)
        var delay: TimeInterval = 0
        for i in 1..<scenes.count {
            delay += 2.0
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.showSceneStatic(i) }
        }
    }

    private func showSceneStatic(_ idx: Int) {
        currentScene = idx
        let s = scenes[idx]
        navTitle.text = s.title
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        switchView.removeFromSuperview()
        if s.toggle { switchView.setOn(true, animated: false) }
        for (i, txt) in s.rows.enumerated() {
            rowsStack.addArrangedSubview(makeRow(txt, trailingSwitch: s.toggle && i == 0))
        }
        updateDots(idx)
        ring.isHidden = true
        finger.isHidden = true
        UIView.transition(with: stage, duration: 0.3, options: .transitionCrossDissolve) {}
    }

    // MARK: - 动作
    @objc private func replayTapped() {
        if UIAccessibility.isReduceMotionEnabled { buildReducedMotion(); return }
        startLoop()
    }

    @objc private func skipTapped() { finish() }

    private func finish() {
        link?.invalidate()
        if let onFinish { onFinish(); return }
        dismiss(animated: true)
    }
}
