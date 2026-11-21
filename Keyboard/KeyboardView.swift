import UIKit

/// 键盘布局态：字母（A/B 帧）与数字符号（C 帧）。
enum KeyboardLayoutMode {
    case letters
    case symbols
}

/// 纯 UIKit 键盘视图：顶部功能条（KeyboardTopBar）＋四行键；高度自适应；配色/按钮见 KeyboardViewStyle.swift。
final class KeyboardView: UIView, UIGestureRecognizerDelegate {
    // 尺寸
    private let keyHeight: CGFloat = 41     // ④ 键高 44→41（对齐微信/iOS，几乎无差）
    private let keyGap: CGFloat = 6      // 水平键距
    private let rowGap: CGFloat = 13     // 行间距 12→13（键块 4×41+3×13=203=微信/iOS）
    private let keyCorner: CGFloat = 6
    private let rowCount = 4
    private let rowsTopGap: CGFloat = 6    // 顶栏→首行间距（总高 44+6+203+4+34≈291，对齐微信/iOS）
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
    private let diagLabel = UILabel()            // ⚠️ 临时诊断浮层（测试取证包）
    private weak var diagHitView: UIView?         // 最近一次真实触摸 hitTest 命中视图
    private lazy var settingsPanel = KeyboardSettingsPanel()
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
        setupDiagnostics()
        setLayoutMode(.letters)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - ⚠️ 临时屏内诊断（测试取证包；定案出正式包前整段+浮层+本文件删除）
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let v = super.hitTest(point, with: event)
        if KBDiagnostics.enabled, event != nil {
            diagHitView = v
            KBDiagnostics.shared.hitView = v
            KBDiagnostics.shared.hitClassName = v.map { String(describing: type(of: $0)) } ?? "nil"
            KBDiagnostics.shared.lastPoint = point
        }
        return v
    }

    private func setupDiagnostics() {
        guard KBDiagnostics.enabled else { return }
        diagLabel.font = .monospacedSystemFont(ofSize: 8, weight: .regular)
        diagLabel.textColor = .white
        diagLabel.backgroundColor = UIColor.black.withAlphaComponent(0.72)
        diagLabel.numberOfLines = 9
        diagLabel.isUserInteractionEnabled = false // 不挡触摸
        diagLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(diagLabel)
        NSLayoutConstraint.activate([
            diagLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            diagLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            diagLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
            diagLabel.heightAnchor.constraint(equalToConstant: 104),
        ])
        KBDiagnostics.shared.label = diagLabel
        let tap = UITapGestureRecognizer(target: self, action: #selector(diagTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        addGestureRecognizer(tap)
    }

    @objc private func diagTap(_ g: UITapGestureRecognizer) {
        let p = g.location(in: self)
        let keys = allKeyButtons()
        let inGrid = rowsStack.convert(rowsStack.bounds, to: self).contains(p)
        var insideKey = "-"
        var nearestT = "-"
        var nearestD = CGFloat.greatestFiniteMagnitude
        var nearestFrame = CGRect.zero
        for k in keys {
            let cellF = k.convert(k.bounds, to: self)
            let vf: CGRect = (k.viewWithTag(9001).map { $0.convert($0.bounds, to: self) }) ?? cellF
            if vf.contains(p) { insideKey = k.title(for: .normal) ?? "?" }
            let dx = max(max(vf.minX - p.x, 0), p.x - vf.maxX)
            let dy = max(max(vf.minY - p.y, 0), p.y - vf.maxY)
            let d = dx * dx + dy * dy
            if d < nearestD { nearestD = d; nearestT = k.title(for: .normal) ?? "?"; nearestFrame = vf }
        }
        var over: [String] = []
        for v in subviews where v !== diagLabel {
            let f = v.convert(v.bounds, to: self)
            if f.contains(p) {
                over.append(String(format: "%@(ui=%d,hid=%d,a=%.2f)", String(describing: type(of: v)),
                                   v.isUserInteractionEnabled ? 1 : 0, v.isHidden ? 1 : 0, v.alpha))
            }
        }
        let gridF = rowsStack.frame
        let extra = [
            String(format: "geo: inGrid=%d inKey=%@ nearest=%@ d=%.0f", inGrid ? 1 : 0, insideKey, nearestT, sqrt(nearestD)),
            "nearF=(\(Int(nearestFrame.minX)),\(Int(nearestFrame.minY)),\(Int(nearestFrame.width)),\(Int(nearestFrame.height)))",
            "gridF=(\(Int(gridF.minX)),\(Int(gridF.minY)),\(Int(gridF.width)),\(Int(gridF.height)))",
            "over=[" + over.joined(separator: ",") + "]",
        ]
        KBDiagnostics.shared.report(extra: extra)
    }

    /// 递归收集所有按键（UIButton）。
    private func allKeyButtons() -> [UIButton] {
        var out: [UIButton] = []
        func walk(_ v: UIView) { for s in v.subviews { if let b = s as? UIButton { out.append(b) } else { walk(s) } } }
        walk(self)
        return out
    }

    func gestureRecognizer(_ g: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

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
        topBar.onDismiss = { [weak self] in
            // 右↓收起键盘：沿响应链找 UIInputViewController 再 dismiss（直接 inputViewController 未必取得到）
            var responder: UIResponder? = self
            while let r = responder {
                if let vc = r as? UIInputViewController { vc.dismissKeyboard(); return }
                responder = r.next
            }
        }
        topBar.onSettings = { [weak self] in self?.showSettingsPanel() } // 左⚙ 键盘内设置面板(A)
    }

    /// 弹键盘内设置面板（占满原键盘区，不跳 App）。打开时隐藏键区/顶栏，面板透明→直接复用键盘主背景成一整块。
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
        // 方案 A′：rowsStack 铺满整个键区全宽全高；行距/键距/切点格交给 CellRowView 处理。
        rowsStack.axis = .vertical; rowsStack.isMultipleTouchEnabled = true
        rowsStack.spacing = 0
        rowsStack.distribution = .fill
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
        let rows: [CellRowView]
        switch mode {
        case .letters:
            rows = [makeLetterRow("qwertyuiop", sideInset: 3), makeLetterRow("asdfghjkl", sideInset: 20, spacing: 5), makeHomeEdgeRow(), makeBottomRow()]
        case .symbols:
            rows = [makeSymbolRow("1234567890"), makeSymbolRow("-/:;()$&@\""), makeSymbolEdgeRow(), makeBottomRow()]
        }
        // 行高/上下内缩：首行上含 rowsTopGap、末行下含 rowsBottomPad、其余对称 rowGap/2 → 可见键高=41、行距=13、总高不变
        let midH = keyHeight + rowGap
        let heights: [CGFloat] = [keyHeight + rowsTopGap + rowGap / 2, midH, midH, keyHeight + rowGap / 2 + rowsBottomPad]
        let vInsets: [(CGFloat, CGFloat)] = [(rowsTopGap, rowGap / 2), (rowGap / 2, rowGap / 2), (rowGap / 2, rowGap / 2), (rowGap / 2, rowsBottomPad)]
        for (i, r) in rows.enumerated() {
            r.translatesAutoresizingMaskIntoConstraints = false
            r.visualTop = vInsets[i].0
            r.visualBottom = vInsets[i].1
            rowsStack.addArrangedSubview(r)
            r.heightAnchor.constraint(equalToConstant: heights[i]).isActive = true
        }
    }

    func showLetters() { setLayoutMode(.letters) } // 强制回字母键盘（#13）

    func setReturnKeyTitle(_ title: String) {
        guard title != returnKeyTitle else { return }
        returnKeyTitle = title
        returnKeyButton?.setTitle(title, for: .normal)
    }

    private func makeRow() -> CellRowView {
        let row = CellRowView()
        row.spacing = keyGap
        return row
    }

    private func makeLetterRow(_ letters: String, sideInset: CGFloat = 0, spacing: CGFloat? = nil) -> CellRowView {
        let row = makeRow()
        row.sideInset = sideInset // #3 苹果式倒三角：本行左右留白、最外格吸收该边距
        if let spacing { row.spacing = spacing }
        for ch in letters {
            row.addKey(makeKey(displayLetter(ch), font: 23, accessibility: "字母 \(ch)", bubble: true) { [weak self] in
                self?.handleLetterTap(ch)
            })
        }
        return row
    }

    private func makeSymbolRow(_ symbols: String) -> CellRowView {
        let row = makeRow()
        for ch in symbols {
            row.addKey(makeKey(String(ch), font: 20, kind: .function, accessibility: "符号 \(ch)") { [weak self] in
                self?.onKeyText?(String(ch))
            })
        }
        return row
    }

    private func makeHomeEdgeRow() -> CellRowView {
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
        row.addKey(shift, weight: 1.15) // #3 ⇧/⌫ 1.15×，把宽度让给字母键
        for ch in "zxcvbnm" {
            row.addKey(makeKey(displayLetter(ch), font: 23, accessibility: "字母 \(ch)", bubble: true) { [weak self] in
                self?.handleLetterTap(ch)
            })
        }
        row.addKey(makeBackspaceKey(), weight: 1.15)
        return row
    }

    private func makeSymbolEdgeRow() -> CellRowView {
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

    private func makeBottomRow() -> CellRowView {
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
        row.addKey(makeKey(isChinese ? "空格" : "space", font: 15, kind: .function, accessibility: "空格") { [weak self] in
            self?.onSpace?()
        })
        let modeButton = ModeToggleButton(frame: .zero)
        modeButton.addTarget(self, action: #selector(toggleModeTapped), for: .touchUpInside)
        modeButton.configure(isChinese: isChinese)
        modeButton.accessibilityLabel = "切换中英文"
        modeKeyButton = modeButton
        row.addKey(modeButton)
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
        button.backgroundColor = KBColor.letterKey // #11 所有键统一字母键颜色
        button.layer.cornerRadius = keyCorner
        button.clipsToBounds = true
        button.accessibilityLabel = accessibility
        return button
    }

    private func makeBackspaceKey() -> ClosureButton {
        let button = makeKey("⌫", font: 18, kind: .function, accessibility: "删除") { }
        button.onTap = nil
        button.pressInserts = false // 删除键走手势（tap/长按），不用按下即上字，避免与手势二次删除
        button.autoFeedback = false // 用删除键独立音（playDelete），避免自动 play 普通键音
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
            // 立即上字后，延到下一次 runloop 再重建键盘：避免在 touchDown 处理中销毁当前按键
            DispatchQueue.main.async { [weak self] in self?.setLayoutMode(.letters) }
        }
    }

    @objc private func toggleModeTapped() { KeyFeedback.shared.play(); onToggleMode?() }
    @objc private func backspaceTapped() { KeyFeedback.shared.playDelete(); onBackspace?() } // 删除键独立音+震

    @objc private func backspaceLongPressed(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            KeyFeedback.shared.playDelete() // 长按删除起手：删除键独立音
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
            KeyFeedback.shared.playDelete() // 长按连发每 tick：删除键独立音
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
