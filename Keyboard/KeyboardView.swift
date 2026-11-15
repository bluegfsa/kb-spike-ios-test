import UIKit

/// 键盘按键布局态：字母（A/B 帧）与数字符号（C 帧）。
enum KeyboardLayoutMode {
    case letters
    case symbols
}

/// 纯 UIKit 键盘视图（不依赖引擎/模型，靠闭包回报交互）。
/// 按 UI 线框 v0.3.3：候选两行（拼音在上、候选在下、每候选带译文、可横滑）＋四行键；
/// 尺寸按内容＋底部安全区自适应（不写死总高），系统色跟随深浅色。
/// 状态由 VC 通过 `update(...)` 注入，本类只管画与回报点击。
/// 配色与辅助按钮见 `KeyboardViewStyle.swift`。
final class KeyboardView: UIView {
    // MARK: - 尺寸常量（UI v0.3）
    private let candidateBarHeight: CGFloat = 56
    private let keyHeight: CGFloat = 42
    private let keyGap: CGFloat = 6
    private let keyCorner: CGFloat = 6
    private let rowCount = 4
    private let rowsTopGap: CGFloat = 6
    private let rowsBottomPad: CGFloat = 4

    private enum KeyKind { case letter, function }

    // MARK: - 交互回调（由 VC 注入）
    var onKeyText: ((String) -> Void)?
    var onBackspace: (() -> Void)?          // 单击删 1 / 长按由本类定时重复调用
    var onSpace: (() -> Void)?
    var onReturn: (() -> Void)?
    var onToggleMode: (() -> Void)?         // 中/英（#13 最高优先，任意态可点）
    var onTogglePunctuation: (() -> Void)?  // 数字态标点全/半角（#12）
    var onAdvanceKeyboard: (() -> Void)?    // 🌐 系统切键盘（#4 按 HIG 必须保留）
    var onCandidate: ((Int) -> Void)?

    // MARK: - 外部注入状态
    private var isChinese = true
    private var punctuationFullWidth = true
    private var layoutMode: KeyboardLayoutMode = .letters

    // MARK: - 子视图
    private let candidateBar = UIView()
    private let pinyinLabel = UILabel()
    private let candidateScroll = UIScrollView()
    private let candidateStack = UIStackView()
    private let rowsStack = UIStackView()
    private weak var modeKeyButton: ModeToggleButton?

    // MARK: - 长按连删（#14）
    private var deleteTimer: Timer?
    private var deleteInterval: TimeInterval = 0.12

    // MARK: - init
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = KBColor.background
        setupCandidateBar()
        setupRows()
        setLayoutMode(.letters)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 键盘总高（内容＋底部安全区），供 VC 设高度约束（#2/#3 自适应，不写死）。
    func intrinsicKeyboardHeight(bottomInset: CGFloat) -> CGFloat {
        candidateBarHeight + rowsTopGap
            + CGFloat(rowCount) * keyHeight + CGFloat(rowCount - 1) * keyGap
            + rowsBottomPad + bottomInset
    }

    // MARK: - 候选区（拼音上 / 候选下，每候选带译文）
    private func setupCandidateBar() {
        candidateBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(candidateBar)

        pinyinLabel.font = .systemFont(ofSize: 13)
        pinyinLabel.textColor = KBColor.pinyin
        pinyinLabel.textAlignment = .left
        pinyinLabel.lineBreakMode = .byTruncatingTail
        pinyinLabel.translatesAutoresizingMaskIntoConstraints = false
        candidateBar.addSubview(pinyinLabel)

        candidateScroll.showsHorizontalScrollIndicator = false
        candidateScroll.alwaysBounceHorizontal = true
        candidateScroll.translatesAutoresizingMaskIntoConstraints = false
        candidateBar.addSubview(candidateScroll)

        candidateStack.axis = .horizontal
        candidateStack.alignment = .center
        candidateStack.spacing = 16
        candidateStack.translatesAutoresizingMaskIntoConstraints = false
        candidateScroll.addSubview(candidateStack)

        NSLayoutConstraint.activate([
            candidateBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            candidateBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            candidateBar.topAnchor.constraint(equalTo: topAnchor),
            candidateBar.heightAnchor.constraint(equalToConstant: candidateBarHeight),

            pinyinLabel.leadingAnchor.constraint(equalTo: candidateBar.leadingAnchor, constant: 10),
            pinyinLabel.trailingAnchor.constraint(equalTo: candidateBar.trailingAnchor, constant: -10),
            pinyinLabel.topAnchor.constraint(equalTo: candidateBar.topAnchor, constant: 3),
            pinyinLabel.heightAnchor.constraint(equalToConstant: 18),

            candidateScroll.leadingAnchor.constraint(equalTo: candidateBar.leadingAnchor, constant: 10),
            candidateScroll.trailingAnchor.constraint(equalTo: candidateBar.trailingAnchor, constant: -10),
            candidateScroll.topAnchor.constraint(equalTo: pinyinLabel.bottomAnchor, constant: 1),
            candidateScroll.heightAnchor.constraint(equalToConstant: 32),
            candidateScroll.bottomAnchor.constraint(equalTo: candidateBar.bottomAnchor, constant: -2),

            candidateStack.leadingAnchor.constraint(equalTo: candidateScroll.contentLayoutGuide.leadingAnchor),
            candidateStack.trailingAnchor.constraint(equalTo: candidateScroll.contentLayoutGuide.trailingAnchor),
            candidateStack.topAnchor.constraint(equalTo: candidateScroll.contentLayoutGuide.topAnchor),
            candidateStack.bottomAnchor.constraint(equalTo: candidateScroll.contentLayoutGuide.bottomAnchor),
            candidateStack.heightAnchor.constraint(equalTo: candidateScroll.frameLayoutGuide.heightAnchor),
        ])
    }

    private func setupRows() {
        rowsStack.axis = .vertical
        rowsStack.spacing = keyGap
        rowsStack.distribution = .fillEqually
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rowsStack)
        NSLayoutConstraint.activate([
            rowsStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: keyGap),
            rowsStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -keyGap),
            rowsStack.topAnchor.constraint(equalTo: candidateBar.bottomAnchor, constant: rowsTopGap),
            rowsStack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -rowsBottomPad),
        ])
    }

    // MARK: - 布局切换（字母 / 数字符号）
    private func setLayoutMode(_ mode: KeyboardLayoutMode) {
        layoutMode = mode
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let rows: [UIView]
        switch mode {
        case .letters:
            rows = [makeLetterRow("qwertyuiop"),
                    makeLetterRow("asdfghjkl"),
                    makeHomeEdgeRow(),
                    makeBottomRow()]
        case .symbols:
            rows = [makeSymbolRow("1234567890"),
                    makeSymbolRow("-/:;()$&@\""),
                    makeSymbolEdgeRow(),
                    makeBottomRow()]
        }
        rows.forEach { rowsStack.addArrangedSubview($0) }
    }

    /// 强制切到字母键盘（#13：数字态点中英切换后回字母）。
    func showLetters() { setLayoutMode(.letters) }

    // MARK: - 行构建
    private func makeRow() -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = keyGap
        row.distribution = .fillEqually
        row.alignment = .fill
        return row
    }

    private func makeLetterRow(_ letters: String) -> UIStackView {
        let row = makeRow()
        for ch in letters {
            row.addArrangedSubview(makeKey(String(ch), font: 22, accessibility: "字母 \(ch)") { [weak self] in
                self?.onKeyText?(String(ch))
            })
        }
        return row
    }

    private func makeSymbolRow(_ symbols: String) -> UIStackView {
        let row = makeRow()
        for ch in symbols {
            let glyph = symbolGlyph(ch)
            row.addArrangedSubview(makeKey(glyph, font: 20, kind: .function, accessibility: "符号 \(glyph)") { [weak self] in
                self?.onKeyText?(glyph)
            })
        }
        return row
    }

    /// 字母态第三行：#10 中文态无大写 → 左侧放「符」符号键；英文态放禁用 ⇧。
    private func makeHomeEdgeRow() -> UIStackView {
        let row = makeRow()
        if isChinese {
            row.addArrangedSubview(makeKey("符", font: 16, kind: .function, accessibility: "符号键盘") { [weak self] in
                self?.setLayoutMode(.symbols)
            })
        } else {
            let shift = makeKey("⇧", font: 18, kind: .function, accessibility: "上档") { }
            shift.isEnabled = false
            shift.alpha = 0.5
            row.addArrangedSubview(shift)
        }
        for ch in "zxcvbnm" {
            row.addArrangedSubview(makeKey(String(ch), font: 22, accessibility: "字母 \(ch)") { [weak self] in
                self?.onKeyText?(String(ch))
            })
        }
        row.addArrangedSubview(makeBackspaceKey())
        return row
    }

    /// 数字态第三行：#11「←」返回字母；标点键随全/半角变；⌫。
    private func makeSymbolEdgeRow() -> UIStackView {
        let row = makeRow()
        row.addArrangedSubview(makeKey("←", font: 20, kind: .function, accessibility: "返回字母键盘") { [weak self] in
            self?.setLayoutMode(.letters)
        })
        for ch in ".,?!'" {
            let glyph = symbolGlyph(ch)
            row.addArrangedSubview(makeKey(glyph, font: 20, kind: .function, accessibility: "符号 \(glyph)") { [weak self] in
                self?.onKeyText?(glyph)
            })
        }
        row.addArrangedSubview(makeBackspaceKey())
        return row
    }

    /// 底行：字母态 `123 ｜ 🌐 ｜ 空格 ｜ 中/英 ｜ 换行`；
    /// 数字态 `，。 ｜ 🌐 ｜ 空格 ｜ 中/英 ｜ 换行`（左键换成标点全/半角切换 #12）。
    private func makeBottomRow() -> UIStackView {
        let row = makeRow()
        if layoutMode == .letters {
            row.addArrangedSubview(makeKey("123", font: 15, kind: .function, accessibility: "数字符号键盘") { [weak self] in
                self?.setLayoutMode(.symbols)
            })
        } else {
            let title = punctuationFullWidth ? "，。" : ",."
            row.addArrangedSubview(makeKey(title, font: 15, kind: .function, accessibility: "标点全半角切换") { [weak self] in
                self?.onTogglePunctuation?()
            })
        }
        row.addArrangedSubview(makeKey("🌐", font: 18, kind: .function, accessibility: "切换到下一个键盘") { [weak self] in
            self?.onAdvanceKeyboard?()
        })
        row.addArrangedSubview(makeKey("空格", font: 15, kind: .function, accessibility: "空格") { [weak self] in
            self?.onSpace?()
        })
        let modeButton = ModeToggleButton(frame: .zero)
        modeButton.addTarget(self, action: #selector(toggleModeTapped), for: .touchUpInside)
        modeButton.configure(isChinese: isChinese)
        modeButton.accessibilityLabel = "切换中英文"
        modeKeyButton = modeButton
        row.addArrangedSubview(modeButton)
        row.addArrangedSubview(makeKey("换行", font: 15, kind: .function, accessibility: "换行") { [weak self] in
            self?.onReturn?()
        })
        return row
    }

    // MARK: - 组件工厂
    private func makeKey(
        _ title: String,
        font: CGFloat,
        kind: KeyKind = .letter,
        accessibility: String,
        onTap: @escaping () -> Void
    ) -> ClosureButton {
        let button = ClosureButton(frame: .zero)
        button.onTap = onTap
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: font)
        button.setTitleColor(KBColor.keyText, for: .normal)
        button.backgroundColor = (kind == .function) ? KBColor.functionKey : KBColor.letterKey
        button.layer.cornerRadius = keyCorner
        button.clipsToBounds = true
        button.accessibilityLabel = accessibility
        if kind == .letter {
            button.layer.borderWidth = 0.5
            button.layer.borderColor = KBColor.keyBorder.cgColor
        }
        return button
    }

    /// ⌫ 键：单击删 1；长按 0.4s 起连删、间隔 0.12→0.03s（#14）。
    private func makeBackspaceKey() -> ClosureButton {
        let button = makeKey("⌫", font: 18, kind: .function, accessibility: "删除") { }
        button.onTap = nil
        let long = UILongPressGestureRecognizer(target: self, action: #selector(backspaceLongPressed(_:)))
        long.minimumPressDuration = 0.4
        let tap = UITapGestureRecognizer(target: self, action: #selector(backspaceTapped))
        tap.require(toFail: long) // 长按识别后不再触发单击删除
        button.addGestureRecognizer(long)
        button.addGestureRecognizer(tap)
        return button
    }

    // MARK: - 外部状态注入
    /// 刷新候选/译文/输入串/语言/标点宽度。由 VC 在 model.onChange 后调用（主线程）。
    func update(candidates: [String], translations: [String?], buffer: String,
                isChinese: Bool, punctuationFullWidth: Bool) {
        let modeChanged = (isChinese != self.isChinese)
        let punctChanged = (punctuationFullWidth != self.punctuationFullWidth)
        self.isChinese = isChinese
        self.punctuationFullWidth = punctuationFullWidth
        if modeChanged || punctChanged {
            setLayoutMode(layoutMode) // 重建以反映 ⇧/符 键与标点键面
        } else {
            modeKeyButton?.configure(isChinese: isChinese)
        }

        pinyinLabel.text = buffer
        pinyinLabel.isHidden = buffer.isEmpty

        candidateStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, text) in candidates.enumerated() {
            let translation: String? = index < translations.count ? translations[index] : nil
            candidateStack.addArrangedSubview(
                makeCandidateItem(text: text, translation: translation, highlight: index == 0, index: index)
            )
        }
        candidateScroll.isHidden = candidates.isEmpty
    }

    /// 单个候选：汉字 19pt（首选加粗＋下划线）＋译文 11pt 灰，间距 4；候选间 16。
    private func makeCandidateItem(text: String, translation: String?, highlight: Bool, index: Int) -> UIView {
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
        container.isUserInteractionEnabled = true
        container.tag = index
        container.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(candidateTapped(_:))))
        return container
    }

    // MARK: - 标点全/半角映射（#12：，。？！：；↔ ,.?!:;）
    private func symbolGlyph(_ ch: Character) -> String {
        guard punctuationFullWidth else {
            switch ch {
            case "，": return ","
            case "。": return "."
            case "？": return "?"
            case "！": return "!"
            case "：": return ":"
            case "；": return ";"
            default: return String(ch)
            }
        }
        switch ch {
        case ",": return "，"
        case ".": return "。"
        case "?": return "？"
        case "!": return "！"
        case ":": return "："
        case ";": return "；"
        default: return String(ch)
        }
    }

    // MARK: - 手势/定时器
    @objc private func toggleModeTapped() { onToggleMode?() }
    @objc private func candidateTapped(_ sender: UITapGestureRecognizer) { onCandidate?(sender.view?.tag ?? 0) }
    @objc private func backspaceTapped() { onBackspace?() }

    @objc private func backspaceLongPressed(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            deleteInterval = 0.12
            scheduleDeleteTick()
        case .ended, .cancelled, .failed:
            stopDelete()
        default:
            break
        }
    }

    private func scheduleDeleteTick() {
        deleteTimer?.invalidate()
        let timer = Timer(timeInterval: deleteInterval, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.onBackspace?()
            self.deleteInterval = max(0.03, self.deleteInterval * 0.85)
            self.scheduleDeleteTick()
        }
        RunLoop.main.add(timer, forMode: .common)
        deleteTimer = timer
    }

    private func stopDelete() {
        deleteTimer?.invalidate()
        deleteTimer = nil
    }
}
