import UIKit

/// 键盘顶部 44pt 功能条（UI v1.2）：左 ⚙ 设置圆钮 · 中间两行（上行拼音串14 / 下行候选26横滚）· 右 ↓ 收起圆钮。
/// 取代原「26 空上探 + 56 独立候选栏」的 82pt 空顶；候选点击/拼音显示都在这里，拼音串不丢。
/// 交互（1.27 反馈）：空态才显示 ⚙/↓ 两钮，一输入/有候选就隐藏两钮、候选占满整条不挡；图标走细体。
final class KeyboardTopBar: UIView {
    static let height: CGFloat = 44

    var onSettings: (() -> Void)?
    var onDismiss: (() -> Void)?
    var onCandidate: ((Int) -> Void)?

    private let settingsButton = UIButton(type: .system)
    private let dismissButton = UIButton(type: .system)
    private let pinyinLabel = UILabel()
    private let candidateScroll = UIScrollView()
    private let candidateStack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear // 透明，露系统毛玻璃背板
        setupMiddle()
        setupButtons()          // 后加 → 在候选层之上，保证可点
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 两个 32×32 圆形按钮：左 ⚙ 设置、右 ↓ 收起键盘。图标细体（同「搜索/发送」字重），空态才显示。
    private func setupButtons() {
        let cfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        let items: [(UIButton, String, String)] = [
            (settingsButton, "gearshape", "设置"),
            (dismissButton, "chevron.down", "收起键盘"),
        ]
        for (btn, symbol, label) in items {
            btn.setImage(UIImage(systemName: symbol, withConfiguration: cfg), for: .normal)
            btn.tintColor = KBColor.keyText
            btn.backgroundColor = KBColor.letterKey
            btn.layer.cornerRadius = 16
            btn.clipsToBounds = true
            btn.isUserInteractionEnabled = true
            btn.accessibilityLabel = label
            btn.translatesAutoresizingMaskIntoConstraints = false
            addSubview(btn)
        }
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        NSLayoutConstraint.activate([
            settingsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            settingsButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 32),
            settingsButton.heightAnchor.constraint(equalToConstant: 32),
            dismissButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            dismissButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            dismissButton.widthAnchor.constraint(equalToConstant: 32),
            dismissButton.heightAnchor.constraint(equalToConstant: 32),
        ])
    }

    /// 中间两行：上行拼音串（14pt，过长省略）、下行候选（26pt，横向滚动）。整条占满（两钮隐藏时不被挡）。
    private func setupMiddle() {
        pinyinLabel.font = .systemFont(ofSize: 12)
        pinyinLabel.textColor = KBColor.pinyin
        pinyinLabel.lineBreakMode = .byTruncatingTail
        pinyinLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pinyinLabel)
        candidateScroll.showsHorizontalScrollIndicator = false
        candidateScroll.alwaysBounceHorizontal = true
        candidateScroll.delaysContentTouches = false          // BUG-1：候选 tap 不被滚动延迟/取消
        candidateScroll.canCancelContentTouches = false
        candidateScroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(candidateScroll)
        candidateStack.axis = .horizontal
        candidateStack.alignment = .center
        candidateStack.spacing = 16
        candidateStack.translatesAutoresizingMaskIntoConstraints = false
        candidateScroll.addSubview(candidateStack)
        NSLayoutConstraint.activate([
            pinyinLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            pinyinLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            pinyinLabel.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            pinyinLabel.heightAnchor.constraint(equalToConstant: 14),
            candidateScroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            candidateScroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            candidateScroll.topAnchor.constraint(equalTo: pinyinLabel.bottomAnchor),
            candidateScroll.heightAnchor.constraint(equalToConstant: 26),
            candidateStack.leadingAnchor.constraint(equalTo: candidateScroll.contentLayoutGuide.leadingAnchor),
            candidateStack.trailingAnchor.constraint(equalTo: candidateScroll.contentLayoutGuide.trailingAnchor),
            candidateStack.topAnchor.constraint(equalTo: candidateScroll.contentLayoutGuide.topAnchor),
            candidateStack.bottomAnchor.constraint(equalTo: candidateScroll.contentLayoutGuide.bottomAnchor),
            candidateStack.heightAnchor.constraint(equalTo: candidateScroll.frameLayoutGuide.heightAnchor),
        ])
    }

    /// 刷新拼音串/候选。由 KeyboardView 在 model.onChange 后调用（主线程）。
    /// 空态（无拼音、无候选）才显示两钮；一输入/有候选即隐藏两钮，候选占满整条。
    func update(buffer: String, candidates: [String], translations: [String?], selectable: Bool) {
        let typing = !(buffer.isEmpty && candidates.isEmpty)
        settingsButton.isHidden = typing
        dismissButton.isHidden = typing
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
