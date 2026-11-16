import UIKit

/// 键盘布局态：字母（A/B 帧）与数字符号（C 帧）。
enum KeyboardLayoutMode {
    case letters
    case symbols
}

/// 纯 UIKit 键盘视图：候选两行（拼音上 / 候选下 / 每候选带译）＋四行键；
/// 高度按内容＋底部安全区自适应（#2/#3）。交互经闭包回报 VC；配色与按钮见 KeyboardViewStyle.swift。
final class KeyboardView: UIView {
    // 尺寸（UI v0.3.3）
    private let candidateBarHeight: CGFloat = 56
    private let keyHeight: CGFloat = 42
    private let keyGap: CGFloat = 6
    private let keyCorner: CGFloat = 6
    private let rowCount = 4
    private let rowsTopGap: CGFloat = 6
    private let rowsBottomPad: CGFloat = 4

    private enum KeyKind { case letter, function }

    // 交互回调（由 VC 注入）
    var onKeyText: ((String) -> Void)?
    var onBackspace: (() -> Void)?
    var onSpace: (() -> Void)?
    var onReturn: (() -> Void)?
    var onToggleMode: (() -> Void)?
    var onTogglePunctuation: (() -> Void)?
    var onCandidate: ((Int) -> Void)?

    // 注入状态
    private var isChinese = true
    private var punctuationFullWidth = true
    private var isShiftActive = false
    private var layoutMode: KeyboardLayoutMode = .letters

    // 子视图
    private let candidateBar = UIView()
    private let pinyinLabel = UILabel()
    private let candidateScroll = UIScrollView()
    private let candidateStack = UIStackView()
    private let rowsStack = UIStackView()
    private weak var modeKeyButton: ModeToggleButton?
    private weak var returnKeyButton: ClosureButton?
    /// 回车键标题，随宿主 App 的 returnKeyType 变（#15/规格 §D·§G2），默认换行。
    private var returnKeyTitle = "换行"

    // 长按连删（#14）
    private var deleteTimer: Timer?
    private var deleteInterval: TimeInterval = 0.12

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = KBColor.background
        setupCandidateBar()
        setupRows()
        setLayoutMode(.letters)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 键盘总高（内容＋底部安全区），供 VC 设高度约束。
    func intrinsicKeyboardHeight(bottomInset: CGFloat) -> CGFloat {
        candidateBarHeight + rowsTopGap + CGFloat(rowCount) * keyHeight
            + CGFloat(rowCount - 1) * keyGap + rowsBottomPad + bottomInset
    }

    // MARK: - 候选区（拼音上 / 候选下）
    private func setupCandidateBar() {
        candidateBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(candidateBar)
        pinyinLabel.font = .systemFont(ofSize: 13)
        pinyinLabel.textColor = KBColor.pinyin
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

    // MARK: - 布局切换
    private func setLayoutMode(_ mode: KeyboardLayoutMode) {
        layoutMode = mode
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let rows: [UIView]
        switch mode {
        case .letters:
            rows = [makeLetterRow("qwertyuiop"), makeLetterRow("asdfghjkl"), makeHomeEdgeRow(), makeBottomRow()]
        case .symbols:
            rows = [makeSymbolRow("1234567890"), makeSymbolRow("-/:;()$&@\""), makeSymbolEdgeRow(), makeBottomRow()]
        }
        rows.forEach { rowsStack.addArrangedSubview($0) }
    }

    /// 强制切到字母键盘（#13：数字态点中英切换后回字母）。
    func showLetters() { setLayoutMode(.letters) }

    /// 按宿主 App 的 `returnKeyType` 设置回车键标题（发送/搜索/前往/完成/换行…）。
    /// 动作始终为换行符，具体是发送还是换行由宿主决定（规格 §D/§G2）。
    func setReturnKeyTitle(_ title: String) {
        guard title != returnKeyTitle else { return }
        returnKeyTitle = title
        returnKeyButton?.setTitle(title, for: .normal)
    }

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
            row.addArrangedSubview(makeKey(displayLetter(ch), font: 22, accessibility: "字母 \(ch)") { [weak self] in
                self?.handleLetterTap(ch)
            })
        }
        return row
    }

    private func makeSymbolRow(_ symbols: String) -> UIStackView {
        let row = makeRow()
        for ch in symbols {
            row.addArrangedSubview(makeKey(String(ch), font: 20, kind: .function, accessibility: "符号 \(ch)") { [weak self] in
                self?.onKeyText?(String(ch))
            })
        }
        return row
    }

    /// 第三行（字母态）：中文态「符」符号键（#10 无大写）；英文态可用 ⇧ 切大小写（修 bug）。
    private func makeHomeEdgeRow() -> UIStackView {
        let row = makeRow()
        if isChinese {
            row.addArrangedSubview(makeKey("符", font: 16, kind: .function, accessibility: "符号键盘") { [weak self] in
                self?.setLayoutMode(.symbols)
            })
        } else {
            let shift = makeKey("⇧", font: 18, kind: .function, accessibility: "上档") { [weak self] in
                self?.isShiftActive.toggle()
                self?.setLayoutMode(.letters)
            }
            if isShiftActive { shift.backgroundColor = KBColor.letterKey }
            row.addArrangedSubview(shift)
        }
        for ch in "zxcvbnm" {
            row.addArrangedSubview(makeKey(displayLetter(ch), font: 22, accessibility: "字母 \(ch)") { [weak self] in
                self?.handleLetterTap(ch)
            })
        }
        row.addArrangedSubview(makeBackspaceKey())
        return row
    }

    /// 第三行（数字态）：#11「←」返回字母；#12 五个标点键随全/半角变；⌫。
    private func makeSymbolEdgeRow() -> UIStackView {
        let row = makeRow()
        row.addArrangedSubview(makeKey("←", font: 20, kind: .function, accessibility: "返回字母键盘") { [weak self] in
            self?.setLayoutMode(.letters)
        })
        for i in 0..<KeyboardLogic.punctFull.count {
            let glyph = KeyboardLogic.punctuationGlyph(fullWidth: punctuationFullWidth, index: i)
            row.addArrangedSubview(makeKey(glyph, font: 20, kind: .function, accessibility: "标点 \(glyph)") { [weak self] in
                self?.onKeyText?(glyph)
            })
        }
        row.addArrangedSubview(makeBackspaceKey())
        return row
    }

    /// 底行：字母态 `123｜空格｜中/英｜回车`；数字态 `，。｜空格｜中/英｜回车`。
    /// 地球键已按用户要求删除；回车键面随 returnKeyType 变、动作统一换行符。
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
        row.addArrangedSubview(makeKey("空格", font: 15, kind: .function, accessibility: "空格") { [weak self] in
            self?.onSpace?()
        })
        let modeButton = ModeToggleButton(frame: .zero)
        modeButton.addTarget(self, action: #selector(toggleModeTapped), for: .touchUpInside)
        modeButton.configure(isChinese: isChinese)
        modeButton.accessibilityLabel = "切换中英文"
        modeKeyButton = modeButton
        row.addArrangedSubview(modeButton)
        let returnKey = makeKey(returnKeyTitle, font: 15, kind: .function, accessibility: "回车") { [weak self] in
            self?.onReturn?()
        }
        returnKeyButton = returnKey
        row.addArrangedSubview(returnKey)
        return row
    }

    // MARK: - 组件工厂
    private func makeKey(_ title: String, font: CGFloat, kind: KeyKind = .letter,
                         accessibility: String, onTap: @escaping () -> Void) -> ClosureButton {
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
        tap.require(toFail: long)
        button.addGestureRecognizer(long)
        button.addGestureRecognizer(tap)
        return button
    }

    // MARK: - 外部状态注入
    /// 刷新候选/译文/输入串/语言/标点宽度。由 VC 在 model.onChange 后调用（主线程）。
    func update(candidates: [String], translations: [String?], buffer: String, isChinese: Bool, punctuationFullWidth: Bool, selectable: Bool) {
        let modeChanged = (isChinese != self.isChinese)
        let punctChanged = (punctuationFullWidth != self.punctuationFullWidth)
        self.isChinese = isChinese
        self.punctuationFullWidth = punctuationFullWidth
        if isChinese { isShiftActive = false }
        if modeChanged || punctChanged {
            setLayoutMode(layoutMode)
        } else {
            modeKeyButton?.configure(isChinese: isChinese)
        }
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

    /// 单个候选：汉字 19pt（首选加粗＋下划线）＋译文 11pt 灰，间距 4；候选间 16。
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

    // MARK: - 字母大小写 / 手势 / 定时器
    private func displayLetter(_ ch: Character) -> String {
        KeyboardLogic.letter(ch, isChinese: isChinese, shift: isShiftActive)
    }

    private func handleLetterTap(_ ch: Character) {
        onKeyText?(displayLetter(ch))
        if !isChinese && isShiftActive {
            isShiftActive = false
            setLayoutMode(.letters)
        }
    }

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
            self.deleteInterval = KeyboardLogic.nextDeleteInterval(from: self.deleteInterval)
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
