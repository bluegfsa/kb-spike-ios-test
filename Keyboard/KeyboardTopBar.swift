import UIKit

/// 键盘顶部 44pt 功能条（UI v1.5，照微信输入法两态）：
/// · 空态（无输入/无候选）：左 ⚙ 圆钮32 ＋ 右 ↓ 圆钮32；
/// · 输入态（有输入/有候选）：候选占满，右侧改「裸向下箭头(无圆)＋左侧竖直小分隔线」，⚙ 隐藏；打字中也能一键收键盘。
/// 两态顶栏都 44 高、切换不跳；候选点击/拼音显示都在这里，拼音串不丢。
final class KeyboardTopBar: UIView {
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

    private func styleCircle(_ btn: UIButton, symbol: String, label: String) {
        let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        btn.setImage(UIImage(systemName: symbol, withConfiguration: cfg), for: .normal)
        btn.tintColor = KBColor.pinyin // #3C3C43 / #EBEBF5，非纯黑
        btn.backgroundColor = KBColor.letterKey
        btn.layer.cornerRadius = 16
        btn.clipsToBounds = true
        btn.isUserInteractionEnabled = true
        btn.accessibilityLabel = label
        btn.translatesAutoresizingMaskIntoConstraints = false
        addSubview(btn)
    }

    private func setupControls() {
        // 空态两圆钮
        styleCircle(settingsButton, symbol: "gearshape", label: "设置")
        styleCircle(dismissCircleButton, symbol: "chevron.down", label: "收起键盘")
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside) // ⚙ 占位：可点，B 在 1.27
        dismissCircleButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        // 输入态：裸箭头（无圆/无底/无边框，热区 44）+ 竖直小分隔线
        let arrowCfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        dismissArrowButton.setImage(UIImage(systemName: "chevron.down", withConfiguration: arrowCfg), for: .normal)
        dismissArrowButton.tintColor = KBColor.pinyin
        dismissArrowButton.backgroundColor = .clear
        dismissArrowButton.isUserInteractionEnabled = true
        dismissArrowButton.accessibilityLabel = "收起键盘"
        dismissArrowButton.translatesAutoresizingMaskIntoConstraints = false
        dismissArrowButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        addSubview(dismissArrowButton)
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
        // 收起箭头视觉偏上：两种态的箭头都往下微调 5pt，落到正中
        dismissCircleButton.imageView?.transform = CGAffineTransform(translationX: 0, y: 5)
        dismissArrowButton.imageView?.transform = CGAffineTransform(translationX: 0, y: 5)
    }

    /// 中间两行：上行拼音串（14pt，过长省略）、下行候选（26pt，横向滚动）。留出输入态右侧箭头块位置。
    private func setupMiddle() {
        pinyinLabel.font = .systemFont(ofSize: 12)
        pinyinLabel.textColor = KBColor.pinyin
        pinyinLabel.lineBreakMode = .byTruncatingTail
        pinyinLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pinyinLabel)
        candidateScroll.showsHorizontalScrollIndicator = false
        candidateScroll.alwaysBounceHorizontal = true
        candidateScroll.delaysContentTouches = false          // 命中即时
        candidateScroll.canCancelContentTouches = true        // 允许拖动时取消 tap → 候选可横向滑动（之前设 false 导致滑不动）
        candidateScroll.isScrollEnabled = true
        candidateScroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(candidateScroll)
        candidateStack.axis = .horizontal
        candidateStack.alignment = .center
        candidateStack.spacing = 16
        candidateStack.translatesAutoresizingMaskIntoConstraints = false
        candidateScroll.addSubview(candidateStack)
        NSLayoutConstraint.activate([
            pinyinLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            pinyinLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inputRightBlock),
            pinyinLabel.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            pinyinLabel.heightAnchor.constraint(equalToConstant: 14),
            candidateScroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            candidateScroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inputRightBlock),
            candidateScroll.topAnchor.constraint(equalTo: pinyinLabel.bottomAnchor),
            candidateScroll.heightAnchor.constraint(equalToConstant: 26),
            candidateStack.leadingAnchor.constraint(equalTo: candidateScroll.contentLayoutGuide.leadingAnchor),
            candidateStack.trailingAnchor.constraint(equalTo: candidateScroll.contentLayoutGuide.trailingAnchor),
            candidateStack.topAnchor.constraint(equalTo: candidateScroll.contentLayoutGuide.topAnchor),
            candidateStack.bottomAnchor.constraint(equalTo: candidateScroll.contentLayoutGuide.bottomAnchor),
            candidateStack.heightAnchor.constraint(equalTo: candidateScroll.frameLayoutGuide.heightAnchor),
        ])
    }

    /// 刷新拼音串/候选。空态显示圆钮（⚙/↓），输入态显裸箭头＋分隔线、隐 ⚙。
    func update(buffer: String, candidates: [String], translations: [String?], selectable: Bool) {
        let typing = !(buffer.isEmpty && candidates.isEmpty)
        settingsButton.isHidden = typing
        dismissCircleButton.isHidden = typing
        dismissArrowButton.isHidden = !typing
        separatorView.isHidden = !typing
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
        let container = UIView()
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
        container.isUserInteractionEnabled = selectable
        container.tag = index
        if selectable {
            container.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(candidateTapped(_:))))
        }
        return container
    }

    @objc private func settingsTapped() { onSettings?() }
    @objc private func dismissTapped() { onDismiss?() }
    @objc private func candidateTapped(_ sender: UITapGestureRecognizer) { onCandidate?(sender.view?.tag ?? 0) }
}
