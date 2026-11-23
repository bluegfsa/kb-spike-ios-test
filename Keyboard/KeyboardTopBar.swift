import UIKit

/// 键盘顶部 44pt 功能条（UI v1.5，照微信输入法两态）：
/// · 空态（无输入/无候选）：左 ⚙ 圆钮32 ＋ 右 ↓ 圆钮32；
/// · 输入态（有输入/有候选）：候选占满，右侧改「裸向下箭头(无圆)＋左侧竖直小分隔线」，⚙ 隐藏；打字中也能一键收键盘。
/// 两态顶栏都 44 高、切换不跳；候选点击/拼音显示都在这里，拼音串不丢。
final class KeyboardTopBar: UIView, UIGestureRecognizerDelegate {
    static let height: CGFloat = 44

    var onSettings: (() -> Void)?
    var onDismiss: (() -> Void)?
    var onCandidate: ((Int) -> Void)?

    private let settingsButton = UIButton(type: .system)      // 空态：⚙ 圆钮
    private let dismissCircleButton = UIButton(type: .system) // 空态：↓ 圆钮
    private let dismissArrowButton = UIButton(type: .system)  // 输入态：裸箭头
    private let separatorView = UIView()                      // 输入态：竖直小分隔线
    private let pinyinLabel = UILabel()
    private let candidateScroll = UIScrollView()
    private let candidateStack = UIStackView()
    private var pinyinTrailing: NSLayoutConstraint!
    private var candidateTrailing: NSLayoutConstraint!
    /// 当前候选是否可点选（update 时同步）。
    private var candidatesSelectable = false

    /// 输入态右侧整块宽：候选↔线10 + 线0.5 + 线↔箭头6 + 箭头热区44 + 右边距8 ≈ 68.5。
    private let inputRightBlock: CGFloat = 68.5

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear // 透明，露系统毛玻璃背板
        setupMiddle()
        setupControls()          // 后加 → 在候选层之上，保证可点
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func styleCircle(_ btn: UIButton, symbol: String, pointSize: CGFloat, label: String) {
        btn.backgroundColor = KBColor.letterKey
        btn.layer.cornerRadius = 16
        btn.clipsToBounds = true
        btn.isUserInteractionEnabled = true
        btn.accessibilityLabel = label
        btn.translatesAutoresizingMaskIntoConstraints = false
        addSubview(btn)
        addCenteredImage(to: btn, symbol: symbol, pointSize: pointSize, weight: .regular, opticalY: 0)
    }

    /// 用独立 `UIImageView` 约束几何居中（不再用 `imageView.transform`：UIButton 布局时会重排/覆盖 transform，
    /// 且圆钮 `clipsToBounds` 会把下移的箭头下半裁掉——这正是之前 +2/+5 怎么挪都不居中的真根因）。
    /// opticalY 仅做 1~2pt 光学补偿；图标本身是 SF Symbol，几何居中。
    private func addCenteredImage(to button: UIButton, symbol: String, pointSize: CGFloat, weight: UIImage.SymbolWeight, opticalY: CGFloat) {
        button.setImage(nil, for: .normal)
        let cfg = UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        let iv = UIImageView(image: UIImage(systemName: symbol, withConfiguration: cfg))
        iv.tintColor = KBColor.pinyin
        iv.contentMode = .center
        iv.isUserInteractionEnabled = false
        iv.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(iv)
        NSLayoutConstraint.activate([
            iv.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            iv.centerYAnchor.constraint(equalTo: button.centerYAnchor, constant: opticalY),
        ])
    }

    private func setupControls() {
        // 空态两圆钮
        styleCircle(settingsButton, symbol: "gearshape", pointSize: 15, label: "设置")
        styleCircle(dismissCircleButton, symbol: "chevron.down", pointSize: 13, label: "收起键盘")
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside) // ⚙ 占位：可点，B 在 1.27
        dismissCircleButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        // 输入态：裸箭头（无圆/无底/无边框，热区 44）+ 竖直小分隔线
        dismissArrowButton.backgroundColor = .clear
        dismissArrowButton.isUserInteractionEnabled = true
        dismissArrowButton.accessibilityLabel = "收起键盘"
        dismissArrowButton.translatesAutoresizingMaskIntoConstraints = false
        dismissArrowButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        addSubview(dismissArrowButton)
        addCenteredImage(to: dismissArrowButton, symbol: "chevron.down", pointSize: 13, weight: .medium, opticalY: 0)
        separatorView.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 235/255, green: 235/255, blue: 245/255, alpha: 0.30)
                : UIColor(red: 60/255, green: 60/255, blue: 67/255, alpha: 0.25)
        }
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separatorView)
        NSLayoutConstraint.activate([
            settingsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            settingsButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 32),
            settingsButton.heightAnchor.constraint(equalToConstant: 32),
            dismissCircleButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            dismissCircleButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            dismissCircleButton.widthAnchor.constraint(equalToConstant: 32),
            dismissCircleButton.heightAnchor.constraint(equalToConstant: 32),
            dismissArrowButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            dismissArrowButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            dismissArrowButton.widthAnchor.constraint(equalToConstant: 44),
            dismissArrowButton.heightAnchor.constraint(equalToConstant: 44),
            separatorView.trailingAnchor.constraint(equalTo: dismissArrowButton.leadingAnchor, constant: -6),
            separatorView.centerYAnchor.constraint(equalTo: centerYAnchor),
            separatorView.widthAnchor.constraint(equalToConstant: 0.5),
            separatorView.heightAnchor.constraint(equalToConstant: 18),
        ])
        // 箭头居中已由 addCenteredImage 的 centerYAnchor 约束保证（不再用 imageView.transform）。
    }

    /// 中间：整条候选栏是一条**原生横向 UIScrollView**（覆盖整个 44pt 高＝拼音行＋候选行＋字间空隙＋空白），
    /// 用它自带的位移/惯性减速（decelerationRate），不再自写 1:1 pan —— 解决「涩、无惯性」＋「空隙滑不动」。
    private func setupMiddle() {
        // 原生横向滚动条：整条 bar 高度，含拼音行/字间空隙/空白，任意落点起手都能滑，松手有惯性。
        candidateScroll.showsHorizontalScrollIndicator = false
        candidateScroll.showsVerticalScrollIndicator = false
        candidateScroll.alwaysBounceHorizontal = true
        candidateScroll.delaysContentTouches = false          // 命中即时
        candidateScroll.canCancelContentTouches = true        // 拖动时取消 tap → 可横滑且不误选
        candidateScroll.isScrollEnabled = true
        candidateScroll.decelerationRate = .normal            // 松手按 velocity 自然减速（微信式轻盈惯性）
        candidateScroll.clipsToBounds = true
        candidateScroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(candidateScroll)
        // REQ-§9.8：候选行（英文/汉字）由每个候选 cell 自己的 tap 负责（见 makeCandidateItem，1.82 已验证可用）；
        // 顶部拼音/空白由下面的独立透明层负责。不再在 scroll 上挂统一 tap（真机反馈不稳）。

        candidateStack.axis = .horizontal
        candidateStack.alignment = .center
        candidateStack.spacing = 16
        candidateStack.translatesAutoresizingMaskIntoConstraints = false
        candidateScroll.addSubview(candidateStack)

        // 拼音串叠在滚动条之上、但不吃手势（isUserInteractionEnabled=false → 触点落到下面 scroll，照样能滑）。
        pinyinLabel.font = .systemFont(ofSize: 12)
        pinyinLabel.textColor = KBColor.pinyin
        pinyinLabel.lineBreakMode = .byTruncatingTail
        pinyinLabel.isUserInteractionEnabled = false
        pinyinLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pinyinLabel)

        // 顶部拼音/空白区：不做独立可点层。candidateScroll 覆盖整栏全高、候选字贴底，
        // 上方空白 touch 直接落到 scroll → 拖动＝原生惯性翻页；轻点由 scroll 上一个「只接管候选行以上」的 tap（delegate 限 y）处理。
        let blankTap = UITapGestureRecognizer(target: self, action: #selector(candidateAreaTapped(_:)))
        blankTap.cancelsTouchesInView = false
        blankTap.require(toFail: candidateScroll.panGestureRecognizer)
        blankTap.delegate = self
        candidateScroll.addGestureRecognizer(blankTap)

        pinyinTrailing = pinyinLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inputRightBlock)
        candidateTrailing = candidateScroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inputRightBlock)
        NSLayoutConstraint.activate([
            // scroll 覆盖整个 44pt 顶栏：拼音行、候选行、字间空隙都归它，任意处起手都能滑
            candidateScroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            candidateTrailing,
            candidateScroll.topAnchor.constraint(equalTo: topAnchor),
            candidateScroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            // 内容区高度 = 可视高度；候选行贴底 26pt，上面 14pt 留给拼音（拼音是 overlay，不随滚动移动）
            candidateScroll.contentLayoutGuide.heightAnchor.constraint(equalTo: candidateScroll.frameLayoutGuide.heightAnchor),
            candidateStack.leadingAnchor.constraint(equalTo: candidateScroll.contentLayoutGuide.leadingAnchor),
            candidateStack.trailingAnchor.constraint(equalTo: candidateScroll.contentLayoutGuide.trailingAnchor),
            candidateStack.bottomAnchor.constraint(equalTo: candidateScroll.contentLayoutGuide.bottomAnchor),
            candidateStack.heightAnchor.constraint(equalToConstant: 26),
            // 拼音 overlay（在 scroll 之上，但不吃手势）
            pinyinLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            pinyinTrailing,
            pinyinLabel.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            pinyinLabel.heightAnchor.constraint(equalToConstant: 14),
        ])
    }

    /// 刷新拼音串/候选。空态显示圆钮（⚙/↓），输入态显裸箭头＋分隔线、隐 ⚙。
    func update(buffer: String, candidates: [String], translations: [String?], selectable: Bool) {
        let typing = !(buffer.isEmpty && candidates.isEmpty)
        let hasCandidates = !candidates.isEmpty
        candidatesSelectable = selectable
        settingsButton.isHidden = typing
        dismissCircleButton.isHidden = typing
        // ⑤ 候选条「有内容」即隐藏收起键盘按钮（含分隔线）：中文候选 / 英文译词 / 英文当前词都算内容。
        //    旧逻辑只看 candidates 是否为空，英文态 candidates 为空但 buffer、译文在显示 → 被误判"无候选"。
        let hasBarContent = hasCandidates || !buffer.isEmpty
            || translations.contains(where: { !($0 ?? "").isEmpty })
        let showDismiss = typing && !hasBarContent
        dismissArrowButton.isHidden = !showDismiss
        separatorView.isHidden = !showDismiss
        let trailingInset: CGFloat = hasCandidates ? -8 : -inputRightBlock
        pinyinTrailing.constant = trailingInset
        candidateTrailing.constant = trailingInset
        pinyinLabel.text = buffer
        pinyinLabel.isHidden = buffer.isEmpty
        candidateStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, text) in candidates.enumerated() {
            let translation: String? = index < translations.count ? translations[index] : nil
            candidateStack.addArrangedSubview(
                makeCandidateItem(text: text, translation: translation, highlight: selectable && index == 0, index: index, selectable: selectable)
            )
        }
        candidateScroll.isHidden = candidates.isEmpty
    }

    private func makeCandidateItem(text: String, translation: String?, highlight: Bool, index: Int, selectable: Bool) -> UIView {
        let container = HitExpandView()
        container.hitExpandX = 0 // ② 不再横向扩热区：字间空隙归整条 scroll，任意落点都能拖动（空隙不再是死区）
        let hanzi = UILabel()
        if highlight {
            let attr = NSMutableAttributedString(string: text)
            attr.addAttributes([
                .font: UIFont.systemFont(ofSize: 19, weight: .bold),
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: KBColor.candidateText,
            ], range: NSRange(location: 0, length: attr.length))
            hanzi.attributedText = attr
        } else {
            hanzi.text = text
            hanzi.font = .systemFont(ofSize: 19)
            hanzi.textColor = KBColor.candidateText
        }
        hanzi.setContentHuggingPriority(.required, for: .horizontal)
        let stack = UIStackView(arrangedSubviews: [hanzi])
        stack.axis = .horizontal
        stack.isUserInteractionEnabled = false // BUG-1：点击命中容器(带tap手势)而非内部 stack
        stack.alignment = .firstBaseline
        stack.spacing = 4
        if let translation, !translation.isEmpty {
            let label = UILabel()
            label.text = translation
            label.font = .systemFont(ofSize: 11)
            label.textColor = KBColor.translation
            label.setContentHuggingPriority(.required, for: .horizontal)
            stack.addArrangedSubview(label)
        }
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        // 候选行（汉字/英文）点选：每个 cell 自带 tap（1.82 已验证可用）；内层 stack 不拦手势。
        container.isUserInteractionEnabled = selectable
        container.tag = index
        if selectable {
            container.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(candidateCellTapped(_:))))
        }
        return container
    }

    @objc private func settingsTapped() { onSettings?() }
    @objc private func dismissTapped() { onDismiss?() }
    // REQ-§9.8：顶部拼音/空白层点击 → 按落点 x 归到对应候选列（列外/无候选不选）。
    // location(in: candidateStack) 取的是内容坐标，已含 contentOffset；横滑由 scroll 的 canCancelContentTouches 保证不误选。
    @objc private func candidateAreaTapped(_ sender: UITapGestureRecognizer) {
        guard candidatesSelectable, !candidateStack.arrangedSubviews.isEmpty else { return }
        let p = sender.location(in: candidateStack)
        let half = candidateStack.spacing / 2
        for v in candidateStack.arrangedSubviews where p.x >= v.frame.minX - half && p.x <= v.frame.maxX + half {
            KeyFeedback.shared.play(); onCandidate?(v.tag); return
        }
        // 列外（最后一个候选以右的空白等）：不选
    }

    /// 候选 cell 自身点选（汉字/英文行）：直接按 cell 的 tag 上屏。
    @objc private func candidateCellTapped(_ sender: UITapGestureRecognizer) {
        KeyFeedback.shared.play()
        onCandidate?(sender.view?.tag ?? 0)
    }

    /// 只让「候选行以上」的空白由 scroll 的 blankTap 处理；候选行内交给 cell 自带 tap（避免重复/误触）。
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let y = touch.location(in: self).y
        let candidateRowTop = bounds.height - 26
        return y < candidateRowTop
    }
}
