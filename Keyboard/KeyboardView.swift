import UIKit

/// 键盘布局态：字母（A/B 帧）与数字符号（C 帧）。
enum KeyboardLayoutMode {
    case letters
    case symbols
}

/// 纯 UIKit 键盘视图：顶部功能条（KeyboardTopBar）＋四行键；高度自适应；配色/按钮见 KeyboardViewStyle.swift。
final class KeyboardView: UIView {
    // 尺寸
    private let keyHeight: CGFloat = 44
    private let keyGap: CGFloat = 6      // 水平键距
    private let rowGap: CGFloat = 12     // 行间距（竖直，微信同款）
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
    var onSettings: (() -> Void)?

    private var isChinese = true
    private var punctuationFullWidth = true
    private var isShiftActive = false
    private var isCapsLocked = false
    private var lastShiftTap = Date.distantPast
    private var layoutMode: KeyboardLayoutMode = .letters

    private let topBar = KeyboardTopBar()
    private let rowsStack = UIStackView()
    private weak var modeKeyButton: ModeToggleButton?
    private weak var returnKeyButton: ClosureButton?
    /// 回车键标题，随宿主 App 的 returnKeyType 变（#15/规格 §D·§G2），默认换行。
    private var returnKeyTitle = "换行"

    // 长按连删（#14）
    private var deleteTimer: Timer?
    private var deleteInterval: TimeInterval = 0.12

    override init(frame: CGRect) {
        super.init(frame: frame); isMultipleTouchEnabled = true // BUG-2 多指同按不丢键
        backgroundColor = KBColor.background
        setupTopBar()
        setupRows()
        setLayoutMode(.letters)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 键盘总高（内容＋底部安全区），供 VC 设高度约束。
    func intrinsicKeyboardHeight(bottomInset: CGFloat) -> CGFloat {
        KeyboardTopBar.height + rowsTopGap + CGFloat(rowCount) * keyHeight
            + CGFloat(rowCount - 1) * rowGap + rowsBottomPad + bottomInset
    }

    private func setupTopBar() {
        topBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(topBar)
        NSLayoutConstraint.activate([
            topBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            topBar.topAnchor.constraint(equalTo: topAnchor),
            topBar.heightAnchor.constraint(equalToConstant: KeyboardTopBar.height),
        ])
        topBar.onCandidate = { [weak self] index in self?.onCandidate?(index) }
        topBar.onDismiss = { [weak self] in self?.inputViewController?.dismissKeyboard() } // 右↓收起键盘
        topBar.onSettings = { [weak self] in self?.onSettings?() }                          // 左⚙ 设置（面板待 UI 稿）
    }

    private func setupRows() {
        rowsStack.axis = .vertical; rowsStack.isMultipleTouchEnabled = true
        rowsStack.spacing = rowGap
        rowsStack.distribution = .fillEqually
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rowsStack)
        NSLayoutConstraint.activate([
            rowsStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: keyGap),
            rowsStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -keyGap),
            rowsStack.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: rowsTopGap),
            rowsStack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -rowsBottomPad),
        ])
    }

    private func setLayoutMode(_ mode: KeyboardLayoutMode) {
        layoutMode = mode
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let rows: [UIView]
        switch mode {
        case .letters:
            rows = [makeLetterRow("qwertyuiop", sideInset: 3), makeLetterRow("asdfghjkl", sideInset: 20, spacing: 5), makeHomeEdgeRow(), makeBottomRow()]
        case .symbols:
            rows = [makeSymbolRow("1234567890"), makeSymbolRow("-/:;()$&@\""), makeSymbolEdgeRow(), makeBottomRow()]
        }
        rows.forEach { rowsStack.addArrangedSubview($0) }
    }

    func showLetters() { setLayoutMode(.letters) } // 强制回字母键盘（#13）

    func setReturnKeyTitle(_ title: String) {
        guard title != returnKeyTitle else { return }
        returnKeyTitle = title
        returnKeyButton?.setTitle(title, for: .normal)
    }

    private func makeRow() -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal; row.isMultipleTouchEnabled = true
        row.spacing = keyGap
        row.distribution = .fillEqually
        row.alignment = .fill
        return row
    }

    private func makeLetterRow(_ letters: String, sideInset: CGFloat = 0, spacing: CGFloat? = nil) -> UIStackView {
        let row = makeRow()
        if sideInset > 0 { // #3 苹果式倒三角：本行左右留白、键更紧
            row.isLayoutMarginsRelativeArrangement = true
            row.layoutMargins = UIEdgeInsets(top: 0, left: sideInset, bottom: 0, right: sideInset)
        }
        if let spacing { row.spacing = spacing }
        for ch in letters {
            row.addArrangedSubview(makeKey(displayLetter(ch), font: 23, accessibility: "字母 \(ch)") { [weak self] in
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

    private func makeHomeEdgeRow() -> UIStackView {
        let row = makeRow()
        let shift = ShiftKeyButton(frame: .zero) // #4 自绘⇧：空心↔实心，锁定时横杠也实心
        shift.shiftState = isCapsLocked ? .caps : (isShiftActive ? .shift : .off); shift.accessibilityLabel = "上档"
        shift.onTap = { [weak self] in
            guard let self else { return }
            if self.isChinese {
                self.onToggleMode?()      // #9 中文态点 ⇧＝切英文
                self.isShiftActive = true // #9 并进入大写态（一次性）
                self.isCapsLocked = false
            } else {
                // #4 英文态：单击＝一次性大写，0.3s 内双击＝锁大写；再点解除回空心
                let now = Date()
                if now.timeIntervalSince(self.lastShiftTap) < 0.3 {
                    self.isCapsLocked = true; self.isShiftActive = true
                } else {
                    self.isCapsLocked = false; self.isShiftActive.toggle()
                }
                self.lastShiftTap = now
            }
            self.setLayoutMode(.letters)
        }
        row.addArrangedSubview(shift)
        for ch in "zxcvbnm" {
            row.addArrangedSubview(makeKey(displayLetter(ch), font: 23, accessibility: "字母 \(ch)") { [weak self] in
                self?.handleLetterTap(ch)
            })
        }
        row.addArrangedSubview(makeBackspaceKey())
        // #3 两边功能键(⇧/⌫)收窄到 1.15，把宽度让给字母键（仿 iOS 原生留白）
        row.distribution = .fill
        let ks = row.arrangedSubviews
        if ks.count > 2 {
            for k in ks.dropFirst().dropLast() { k.widthAnchor.constraint(equalTo: ks[1].widthAnchor).isActive = true }
            ks.first?.widthAnchor.constraint(equalTo: ks[1].widthAnchor, multiplier: 1.15).isActive = true
            ks.last?.widthAnchor.constraint(equalTo: ks[1].widthAnchor, multiplier: 1.15).isActive = true
        }
        return row
    }

    private func makeSymbolEdgeRow() -> UIStackView {
        let row = makeRow()
        let toggleTitle = punctuationFullWidth ? "，。" : ",."
        row.addArrangedSubview(makeKey(toggleTitle, font: 15, kind: .function, accessibility: "标点全半角切换") { [weak self] in
            self?.onTogglePunctuation?()
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

    private func makeBottomRow() -> UIStackView {
        let row = makeRow()
        if layoutMode == .letters {
            row.addArrangedSubview(makeKey("123", font: 15, kind: .function, accessibility: "数字符号键盘") { [weak self] in
                self?.setLayoutMode(.symbols)
            })
        } else {
            row.addArrangedSubview(makeKey("←", font: 20, kind: .function, accessibility: "返回字母键盘") { [weak self] in
                self?.setLayoutMode(.letters)
            })
        }
        row.addArrangedSubview(makeKey(isChinese ? "空格" : "space", font: 15, kind: .function, accessibility: "空格") { [weak self] in
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

    private func makeKey(_ title: String, font: CGFloat, kind: KeyKind = .letter,
                         accessibility: String, onTap: @escaping () -> Void) -> ClosureButton {
        let button = ClosureButton(frame: .zero)
        button.onTap = onTap
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: font)
        button.setTitleColor(KBColor.keyText, for: .normal)
        button.backgroundColor = KBColor.letterKey // #11 所有键统一字母键颜色
        button.layer.cornerRadius = keyCorner
        button.clipsToBounds = true
        button.accessibilityLabel = accessibility
        return button
    }

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

    /// 刷新候选/译文/输入串/语言/标点宽度。由 VC 在 model.onChange 后调用（主线程）。
    func update(candidates: [String], translations: [String?], buffer: String, isChinese: Bool, punctuationFullWidth: Bool, selectable: Bool) {
        let modeChanged = (isChinese != self.isChinese)
        let punctChanged = (punctuationFullWidth != self.punctuationFullWidth)
        self.isChinese = isChinese
        self.punctuationFullWidth = punctuationFullWidth
        if isChinese { isShiftActive = false; isCapsLocked = false }
        if modeChanged || punctChanged {
            setLayoutMode(layoutMode)
        } else {
            modeKeyButton?.configure(isChinese: isChinese)
        }
        topBar.update(buffer: buffer, candidates: candidates, translations: translations, selectable: selectable)
    }

    private func displayLetter(_ ch: Character) -> String {
        KeyboardLogic.letter(ch, isChinese: isChinese, shift: isShiftActive)
    }

    private func handleLetterTap(_ ch: Character) {
        onKeyText?(displayLetter(ch))
        if !isChinese && isShiftActive && !isCapsLocked { // #4 锁大写时不自动复位
            isShiftActive = false
            setLayoutMode(.letters)
        }
    }

    @objc private func toggleModeTapped() { onToggleMode?() }
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
