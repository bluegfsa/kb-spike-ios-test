import UIKit

/// 键盘布局态：字母（A/B 帧）与数字符号（C 帧）。
enum KeyboardLayoutMode {
    case letters
    case symbols
}

/// 纯 UIKit 键盘视图：顶部功能条（KeyboardTopBar）＋四行键；高度自适应；配色/按钮见 KeyboardViewStyle.swift。
/// 【C2·口径A】行用 C2RowView：外壳满格深色相接＋内部圆角白卡（以 1.49 键心对称放大到≈1.5pt 缝），触摸走真实按钮。
final class KeyboardView: UIView {
    // 尺寸
    private let keyHeight: CGFloat = 41     // ④ 键高 41（对齐微信/iOS）
    private let keyGap: CGFloat = 6      // 水平键距（1.49 口径：供 C2RowView 计算白卡放大）
    private let rowGap: CGFloat = 13     // 行间距（1.49 口径）
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
    private lazy var settingsPanel = KeyboardSettingsPanel()
    private weak var modeKeyButton: ModeToggleButton?
    private weak var returnKeyButton: ClosureButton?
    private var returnKeyTitle = "换行"

    private var deleteTimer: Timer?
    private var deleteInterval: TimeInterval = 0.12

    override init(frame: CGRect) {
        super.init(frame: frame); isMultipleTouchEnabled = true
        backgroundColor = KBColor.background
        setupTopBar()
        setupRows()
        setLayoutMode(.letters)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 键盘总高（内容＋底部安全区），供 VC 设高度约束（与 1.49 逐项一致，总高不变）。
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
        topBar.onDismiss = { [weak self] in
            var responder: UIResponder? = self
            while let r = responder {
                if let vc = r as? UIInputViewController { vc.dismissKeyboard(); return }
                responder = r.next
            }
        }
        topBar.onSettings = { [weak self] in self?.showSettingsPanel() }
    }

    private func showSettingsPanel() {
        settingsPanel.translatesAutoresizingMaskIntoConstraints = false
        topBar.isHidden = true
        rowsStack.isHidden = true
        if settingsPanel.superview == nil {
            addSubview(settingsPanel)
            NSLayoutConstraint.activate([
                settingsPanel.leadingAnchor.constraint(equalTo: leadingAnchor),
                settingsPanel.trailingAnchor.constraint(equalTo: trailingAnchor),
                settingsPanel.topAnchor.constraint(equalTo: topAnchor),
                settingsPanel.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
            settingsPanel.onClose = { [weak self] in
                self?.settingsPanel.removeFromSuperview()
                self?.topBar.isHidden = false
                self?.rowsStack.isHidden = false
            }
        }
        bringSubviewToFront(settingsPanel)
    }

    private func setupRows() {
        // 【C2】行与行 spacing=0、无外边距：整块键区被外壳铺满，零透明真空。
        rowsStack.axis = .vertical; rowsStack.isMultipleTouchEnabled = true
        rowsStack.spacing = 0
        rowsStack.distribution = .fill
        rowsStack.backgroundColor = KBColor.background // 外圈留白露键盘底色（非深色条）
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rowsStack)
        NSLayoutConstraint.activate([
            rowsStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowsStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            rowsStack.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            rowsStack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    private func setLayoutMode(_ mode: KeyboardLayoutMode) {
        layoutMode = mode
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let rows: [C2RowView]
        switch mode {
        case .letters:
            rows = [makeLetterRow("qwertyuiop", sideInset: 3),
                    makeLetterRow("asdfghjkl", sideInset: 20, spacing: 5),
                    makeHomeEdgeRow(),
                    makeBottomRow()]
        case .symbols:
            rows = [makeSymbolRow("1234567890"), makeSymbolRow("-/:;()$&@\""), makeSymbolEdgeRow(), makeBottomRow()]
        }
        // 行高沿用 1.49：首行含 rowsTopGap、末行含 rowsBottomPad、其余对称 rowGap/2 → 总高不变、行基线不变
        let heights: [CGFloat] = [keyHeight + rowsTopGap + rowGap / 2, keyHeight + rowGap, keyHeight + rowGap, keyHeight + rowGap / 2 + rowsBottomPad]
        // 每行可见键的显式上/下边距（首行 6/6.5、中间 6.5/6.5、末行 6.5/4），键高恒 41，行基线严格对 1.49
        let vInsets: [(CGFloat, CGFloat)] = [(rowsTopGap, rowGap / 2), (rowGap / 2, rowGap / 2), (rowGap / 2, rowGap / 2), (rowGap / 2, rowsBottomPad)]
        for (i, r) in rows.enumerated() {
            r.translatesAutoresizingMaskIntoConstraints = false
            r.visualTop = vInsets[i].0
            r.visualBottom = vInsets[i].1
            // 末行白卡不向下外扩，保留 rowsBottomPad 底部灰缝、圆角不被裁（1.62 修底行超界）
            r.expandsBottom = (i < rows.count - 1)
            rowsStack.addArrangedSubview(r)
            r.heightAnchor.constraint(equalToConstant: heights[i]).isActive = true
        }
    }

    func showLetters() { setLayoutMode(.letters) }

    func setReturnKeyTitle(_ title: String) {
        guard title != returnKeyTitle else { return }
        returnKeyTitle = title
        returnKeyButton?.setTitle(title, for: .normal)
    }

    private func makeRow() -> C2RowView {
        let row = C2RowView()
        row.spacing = keyGap
        return row
    }

    private func makeLetterRow(_ letters: String, sideInset: CGFloat = 0, spacing: CGFloat? = nil) -> C2RowView {
        let row = makeRow()
        row.sideInset = sideInset
        if let spacing { row.spacing = spacing }
        for ch in letters {
            row.addKey(makeKey(displayLetter(ch), font: 23, accessibility: "字母 \(ch)", bubble: true) { [weak self] in
                self?.handleLetterTap(ch)
            })
        }
        return row
    }

    private func makeSymbolRow(_ symbols: String) -> C2RowView {
        let row = makeRow()
        for ch in symbols {
            row.addKey(makeKey(String(ch), font: 20, kind: .function, accessibility: "符号 \(ch)") { [weak self] in
                self?.onKeyText?(String(ch))
            })
        }
        return row
    }

    private func makeHomeEdgeRow() -> C2RowView {
        let row = makeRow()
        let shift = ShiftKeyButton(frame: .zero)
        shift.shiftState = isCapsLocked ? .caps : (isShiftActive ? .shift : .off); shift.accessibilityLabel = "上档"
        shift.onTap = { [weak self] in
            guard let self else { return }
            if self.isChinese {
                self.onToggleMode?()
                self.isShiftActive = true
                self.isCapsLocked = false
            } else {
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
        row.addKey(shift, weight: 1.15)
        for ch in "zxcvbnm" {
            row.addKey(makeKey(displayLetter(ch), font: 23, accessibility: "字母 \(ch)", bubble: true) { [weak self] in
                self?.handleLetterTap(ch)
            })
        }
        row.addKey(makeBackspaceKey(), weight: 1.15)
        return row
    }

    private func makeSymbolEdgeRow() -> C2RowView {
        let row = makeRow()
        let toggleTitle = punctuationFullWidth ? "，。" : ",."
        row.addKey(makeKey(toggleTitle, font: 15, kind: .function, accessibility: "标点全半角切换") { [weak self] in
            self?.onTogglePunctuation?()
        })
        for i in 0..<KeyboardLogic.punctFull.count {
            let glyph = KeyboardLogic.punctuationGlyph(fullWidth: punctuationFullWidth, index: i)
            row.addKey(makeKey(glyph, font: 20, kind: .function, accessibility: "标点 \(glyph)") { [weak self] in
                self?.onKeyText?(glyph)
            })
        }
        row.addKey(makeBackspaceKey())
        return row
    }

    private func makeBottomRow() -> C2RowView {
        let row = makeRow()
        if layoutMode == .letters {
            row.addKey(makeKey("123", font: 15, kind: .function, accessibility: "数字符号键盘") { [weak self] in
                self?.setLayoutMode(.symbols)
            })
        } else {
            row.addKey(makeKey("←", font: 20, kind: .function, accessibility: "返回字母键盘") { [weak self] in
                self?.setLayoutMode(.letters)
            })
        }
        // 1.62：底行「中英切换」与「空格」整块对调 —— 顺序 123 → 中英 → 空格 → 回车，宽度/缝色/可点均不变
        let modeButton = ModeToggleButton(frame: .zero)
        modeButton.addTarget(self, action: #selector(toggleModeTapped), for: .touchUpInside)
        modeButton.configure(isChinese: isChinese)
        modeButton.accessibilityLabel = "切换中英文"
        modeKeyButton = modeButton
        row.addKey(modeButton)
        row.addKey(makeKey(isChinese ? "空格" : "space", font: 15, kind: .function, accessibility: "空格") { [weak self] in
            self?.onSpace?()
        })
        let returnKey = makeKey(returnKeyTitle, font: 15, kind: .function, accessibility: "回车") { [weak self] in
            self?.onReturn?()
        }
        returnKeyButton = returnKey
        row.addKey(returnKey)
        return row
    }

    private func makeKey(_ title: String, font: CGFloat, kind: KeyKind = .letter,
                         accessibility: String, bubble: Bool = false, onTap: @escaping () -> Void) -> ClosureButton {
        let button = ClosureButton(frame: .zero)
        button.onTap = onTap
        button.showsBubble = bubble
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: font)
        button.setTitleColor(KBColor.keyText, for: .normal)
        button.backgroundColor = KBColor.letterKey
        button.layer.cornerRadius = keyCorner
        button.clipsToBounds = true
        button.accessibilityLabel = accessibility
        return button
    }

    private func makeBackspaceKey() -> ClosureButton {
        let button = makeKey("⌫", font: 18, kind: .function, accessibility: "删除") { }
        button.onTap = nil
        button.pressInserts = false
        button.autoFeedback = false
        let long = UILongPressGestureRecognizer(target: self, action: #selector(backspaceLongPressed(_:)))
        long.minimumPressDuration = 0.4
        let tap = UITapGestureRecognizer(target: self, action: #selector(backspaceTapped))
        tap.require(toFail: long)
        button.addGestureRecognizer(long)
        button.addGestureRecognizer(tap)
        return button
    }

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
        if !isChinese && isShiftActive && !isCapsLocked {
            isShiftActive = false
            DispatchQueue.main.async { [weak self] in self?.setLayoutMode(.letters) }
        }
    }

    @objc private func toggleModeTapped() { KeyFeedback.shared.play(); onToggleMode?() }
    @objc private func backspaceTapped() { KeyFeedback.shared.playDelete(); onBackspace?() }

    @objc private func backspaceLongPressed(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            KeyFeedback.shared.playDelete()
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
            KeyFeedback.shared.playDelete()
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
