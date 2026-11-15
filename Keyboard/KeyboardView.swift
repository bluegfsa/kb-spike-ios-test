import UIKit

/// 键盘按键布局态：字母（A/B 帧）与数字符号（C 帧）。
enum KeyboardLayoutMode {
    case letters
    case symbols
}

/// 纯 UIKit 键盘视图骨架（不依赖引擎/模型，靠闭包回报交互）。
/// 布局按 UI 线框 v0.2：候选栏 46 + 四行 44 + 键距 6；系统色跟随深浅色；无品牌色。
/// 状态由外部（KeyboardViewController）通过 `update(...)` 注入，本类只管画与回报点击。
final class KeyboardView: UIView {
    // MARK: - 尺寸常量（线框 v0.2）
    private let candidateBarHeight: CGFloat = 46
    private let keyHeight: CGFloat = 44
    private let keyGap: CGFloat = 6
    private let keyCorner: CGFloat = 6

    // MARK: - 交互回调（由 VC 注入）
    var onKeyText: ((String) -> Void)?          // 字母/数字/符号字符键
    var onBackspace: (() -> Void)?
    var onSpace: (() -> Void)?
    var onReturn: (() -> Void)?
    var onToggleMode: (() -> Void)?             // 中 / EN
    var onAdvanceKeyboard: (() -> Void)?        // 🌐 系统切键盘
    var onCandidate: ((Int) -> Void)?           // 点候选

    // MARK: - 子视图
    private let candidateBar = UIStackView()
    private let bufferLabel = UILabel()
    private let candidatesStack = UIStackView()
    private let glossCard = UILabel()
    private let rowsStack = UIStackView()
    private var isChinese = true
    private var layoutMode: KeyboardLayoutMode = .letters

    // MARK: - init
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        setupCandidateBar()
        setupRows()
        setLayoutMode(.letters)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - 候选栏 + 译词卡
    private func setupCandidateBar() {
        bufferLabel.font = .systemFont(ofSize: 14)
        bufferLabel.textColor = .secondaryLabel
        bufferLabel.setContentHuggingPriority(.required, for: .horizontal)

        candidatesStack.axis = .horizontal
        candidatesStack.spacing = 12
        candidatesStack.alignment = .center

        glossCard.font = .systemFont(ofSize: 14, weight: .medium)
        glossCard.textAlignment = .center
        glossCard.textColor = .secondaryLabel
        glossCard.backgroundColor = .tertiarySystemBackground
        glossCard.layer.cornerRadius = keyCorner
        glossCard.clipsToBounds = true
        glossCard.setContentHuggingPriority(.required, for: .horizontal)
        glossCard.widthAnchor.constraint(lessThanOrEqualToConstant: 132).isActive = true
        glossCard.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true

        candidateBar.axis = .horizontal
        candidateBar.alignment = .center
        candidateBar.spacing = 8
        candidateBar.addArrangedSubview(bufferLabel)
        candidateBar.addArrangedSubview(candidatesStack)
        candidateBar.addArrangedSubview(glossCard)
        candidateBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(candidateBar)

        NSLayoutConstraint.activate([
            candidateBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            candidateBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            candidateBar.topAnchor.constraint(equalTo: topAnchor),
            candidateBar.heightAnchor.constraint(equalToConstant: candidateBarHeight),
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
            rowsStack.topAnchor.constraint(equalTo: candidateBar.bottomAnchor, constant: 4),
            rowsStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
    }

    // MARK: - 布局切换（内部处理 123 / ABC）
    private func setLayoutMode(_ mode: KeyboardLayoutMode) {
        layoutMode = mode
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        switch mode {
        case .letters:
            rowsStack.addArrangedSubview(makeLetterRow("qwertyuiop"))
            rowsStack.addArrangedSubview(makeLetterRow("asdfghjkl"))
            rowsStack.addArrangedSubview(makeHomeEdgeRow())
            rowsStack.addArrangedSubview(makeBottomRow())
        case .symbols:
            rowsStack.addArrangedSubview(makeSymbolRow("1234567890"))
            rowsStack.addArrangedSubview(makeSymbolRow("-/:;()$&@\""))
            rowsStack.addArrangedSubview(makeSymbolEdgeRow())
            rowsStack.addArrangedSubview(makeBottomRow())
        }
    }

    // MARK: - 行构建
    private func makeLetterRow(_ letters: String) -> UIStackView {
        let row = makeHorizontalRow()
        for ch in letters {
            row.addArrangedSubview(makeKey(String(ch), accessibility: "字母 \(ch)") { [weak self] in
                self?.onKeyText?(String(ch))
            })
        }
        return row
    }

    private func makeSymbolRow(_ symbols: String) -> UIStackView {
        let row = makeHorizontalRow()
        for ch in symbols {
            row.addArrangedSubview(makeKey(String(ch), accessibility: "符号 \(ch)") { [weak self] in
                self?.onKeyText?(String(ch))
            })
        }
        return row
    }

    /// 第三行（字母态）：⇧ + 中排 + ⌫
    private func makeHomeEdgeRow() -> UIStackView {
        let row = makeHorizontalRow()
        row.addArrangedSubview(makeKey("⇧", font: 18, accessibility: "上档") { })
        for ch in "zxcvbnm" {
            row.addArrangedSubview(makeKey(String(ch), accessibility: "字母 \(ch)") { [weak self] in
                self?.onKeyText?(String(ch))
            })
        }
        row.addArrangedSubview(makeKey("⌫", font: 18, accessibility: "删除") { [weak self] in
            self?.onBackspace?()
        })
        return row
    }

    /// 第三行（符号态）：ABC 切换 + 若干符号 + ⌫
    private func makeSymbolEdgeRow() -> UIStackView {
        let row = makeHorizontalRow()
        row.addArrangedSubview(makeKey("ABC", font: 15, accessibility: "字母键盘") { [weak self] in
            self?.setLayoutMode(.letters)
        })
        for ch in ".,?!'" {
            row.addArrangedSubview(makeKey(String(ch), accessibility: "符号 \(ch)") { [weak self] in
                self?.onKeyText?(String(ch))
            })
        }
        row.addArrangedSubview(makeKey("⌫", font: 18, accessibility: "删除") { [weak self] in
            self?.onBackspace?()
        })
        return row
    }

    /// 底行：123/ABC ｜ 🌐 ｜ 空格 ｜ 中·EN ｜ 换行
    private func makeBottomRow() -> UIStackView {
        let row = makeHorizontalRow()
        let layoutTitle = layoutMode == .letters ? "123" : "ABC"
        row.addArrangedSubview(makeKey(layoutTitle, font: 15, accessibility: "数字符号键盘") { [weak self] in
            guard let self else { return }
            self.setLayoutMode(self.layoutMode == .letters ? .symbols : .letters)
        })
        row.addArrangedSubview(makeKey("🌐", font: 18, accessibility: "切换到下一个键盘") { [weak self] in
            self?.onAdvanceKeyboard?()
        })
        row.addArrangedSubview(makeKey("空格", font: 15, accessibility: "空格") { [weak self] in
            self?.onSpace?()
        })
        row.addArrangedSubview(makeKey(isChinese ? "中" : "EN", font: 15, accessibility: "切换中英文") { [weak self] in
            self?.onToggleMode?()
        })
        row.addArrangedSubview(makeKey("换行", font: 15, accessibility: "换行") { [weak self] in
            self?.onReturn?()
        })
        return row
    }

    // MARK: - 组件工厂
    private func makeHorizontalRow() -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = keyGap
        row.distribution = .fillEqually
        row.alignment = .fill
        return row
    }

    private func makeKey(
        _ title: String,
        font: CGFloat = 22,
        accessibility: String,
        onTap: @escaping () -> Void
    ) -> UIButton {
        let button = ClosureButton(type: .system)
        button.onTap = onTap
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: font)
        button.setTitleColor(.label, for: .normal)
        button.backgroundColor = .secondarySystemBackground
        button.layer.cornerRadius = keyCorner
        button.clipsToBounds = true
        button.accessibilityLabel = accessibility
        return button
    }

    // MARK: - 外部状态注入
    /// 刷新候选/输入串/译词/模式。由 VC 在 model.onChange 后调用（主线程）。
    func update(candidates: [String], buffer: String, gloss: String?, isChinese: Bool) {
        self.isChinese = isChinese
        bufferLabel.text = buffer
        bufferLabel.isHidden = buffer.isEmpty

        candidatesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, text) in candidates.enumerated() {
            let label = UILabel()
            label.text = text
            label.font = .systemFont(ofSize: 17, weight: index == 0 ? .bold : .regular)
            label.textColor = .label
            label.isUserInteractionEnabled = true
            let tap = UITapGestureRecognizer(target: self, action: #selector(onCandidateTap(_:)))
            label.addGestureRecognizer(tap)
            label.tag = index
            candidatesStack.addArrangedSubview(label)
        }

        if let gloss {
            glossCard.text = gloss
            glossCard.textColor = .label
        } else {
            glossCard.text = "—"
            glossCard.textColor = .tertiaryLabel
        }
        glossCard.isHidden = false
        refreshBottomModeKey()
    }

    /// 只更新底行「中/EN」键标题。
    private func refreshBottomModeKey() {
        guard let row = rowsStack.arrangedSubviews.last as? UIStackView else { return }
        if let modeButton = row.arrangedSubviews.dropLast(1).last as? UIButton {
            modeButton.setTitle(isChinese ? "中" : "EN", for: .normal)
        }
    }

    @objc private func onCandidateTap(_ sender: UITapGestureRecognizer) {
        onCandidate?(sender.view?.tag ?? 0)
    }
}

/// 带闭包的按钮（UIButton 不支持 target/action 直接闭包，做一个轻封装）。
private final class ClosureButton: UIButton {
    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleTap() {
        onTap?()
    }
}
