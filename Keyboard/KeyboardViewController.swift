import UIKit

/// 键盘扩展入口：只绑 `KeyboardModeling`（B1 用 `MockKeyboardModel`），不碰引擎/词库细节。
/// 交互按实现级接口 v0.2 §6 + 按键行为规格（#11~#15）执行；引擎接上后换成真实 `KeyboardModel`，本文件零改动。
final class KeyboardViewController: UIInputViewController {
    private let keyboardView = KeyboardView()
    private let statusBanner = UILabel()
    private var model: KeyboardModeling = MockKeyboardModel()
    private var heightConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = keyboardView.backgroundColor
        setupKeyboardView()
        setupStatusBanner()
        model.onChange = { [weak self] in self?.render() }
        render()
    }

    /// #2/#3：高度按内容＋底部安全区自适应（不写死 291），露白/挡输入框问题由此解决。
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let height = keyboardView.intrinsicKeyboardHeight(bottomInset: view.safeAreaInsets.bottom)
        if let constraint = heightConstraint, abs(constraint.constant - height) > 0.5 {
            constraint.constant = height
            view.layoutIfNeeded()
        }
    }

    // MARK: - 视图装配
    private func setupKeyboardView() {
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboardView)
        NSLayoutConstraint.activate([
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.topAnchor.constraint(equalTo: view.topAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        let height = view.heightAnchor.constraint(equalToConstant: 252)
        height.priority = UILayoutPriority(999)
        height.isActive = true
        heightConstraint = height

        keyboardView.onKeyText = { [weak self] text in self?.handleKeyText(text) }
        keyboardView.onBackspace = { [weak self] in self?.handleBackspace() }
        keyboardView.onSpace = { [weak self] in self?.handleSpace() }
        keyboardView.onReturn = { [weak self] in self?.handleReturn() }
        keyboardView.onToggleMode = { [weak self] in
            guard let self else { return }
            self.model.toggleMode()
            self.keyboardView.showLetters() // #13：任意态切中英后回字母键盘
            self.render()                   // 同步再渲染，label/候选立刻翻转
        }
        keyboardView.onTogglePunctuation = { [weak self] in
            guard let self else { return }
            self.model.togglePunctuation()
            self.render()
        }
        keyboardView.onCandidate = { [weak self] index in self?.handleCandidate(index) }
        keyboardView.onAdvanceKeyboard = { [weak self] in self?.advanceToNextInputMode() }
    }

    /// needInit/error 时的静态提示条（不申请完全访问 → 不做扩展内跳转，只提示手动开宿主）。
    private func setupStatusBanner() {
        statusBanner.font = .systemFont(ofSize: 13)
        statusBanner.textColor = .label
        statusBanner.backgroundColor = .secondarySystemBackground
        statusBanner.textAlignment = .center
        statusBanner.numberOfLines = 2
        statusBanner.isHidden = true
        statusBanner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusBanner)
        NSLayoutConstraint.activate([
            statusBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statusBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            statusBanner.topAnchor.constraint(equalTo: view.topAnchor),
            statusBanner.heightAnchor.constraint(equalToConstant: 40),
        ])
        view.bringSubviewToFront(statusBanner)
    }

    // MARK: - 渲染（model.onChange 主线程回调后执行）
    private func render() {
        let isChinese = model.mode == .zh2en
        var candidates = model.candidates
        var translations = model.candidateTranslations
        // 英文态无候选、只有首选译词：用译文占位显示（保留英译中可见性，不带「中/EN」标签 #7）。
        if !isChinese, candidates.isEmpty, let translation = model.primaryTranslation {
            candidates = [translation]
            translations = [nil]
        }
        keyboardView.update(
            candidates: candidates,
            translations: translations,
            buffer: model.buffer,
            isChinese: isChinese,
            punctuationFullWidth: model.punctuationFullWidth
        )
        switch model.status {
        case .ready:
            statusBanner.isHidden = true
        case .needInit:
            statusBanner.text = "请先打开『双译键盘』App 完成首次初始化"
            statusBanner.isHidden = false
        case .error(let message):
            statusBanner.text = "词典未就绪：\(message)"
            statusBanner.isHidden = false
        }
    }

    // MARK: - 交互
    private func handleKeyText(_ text: String) {
        guard text.count == 1, let character = text.first else {
            textDocumentProxy.insertText(text)
            return
        }
        if character.isLetter && character.isASCII {
            model.input(letter: character)
            // 中文态：字母进拼音 buffer（不直接上屏，候选栏显示）；英文态：直入文档。
            if model.mode == .en2zh {
                textDocumentProxy.insertText(String(character))
            }
        } else {
            // 数字/符号：直接上屏，不进拼音 buffer（全/半角标点已在视图层映射好）。
            textDocumentProxy.insertText(text)
        }
    }

    private func handleBackspace() {
        if model.mode == .zh2en && !model.buffer.isEmpty {
            model.backspace() // 只删拼音串，未落文档
        } else {
            textDocumentProxy.deleteBackward() // 先删真实文本
            model.backspace()                  // 再同步 buffer/候选
        }
    }

    private func handleSpace() {
        let text = model.space()
        if !text.isEmpty {
            textDocumentProxy.insertText(text)
        }
    }

    private func handleReturn() {
        let text = model.newline() // #15：只换行（第三方键盘无法程序化发送）
        if !text.isEmpty {
            textDocumentProxy.insertText(text)
        }
    }

    private func handleCandidate(_ index: Int) {
        if let text = model.selectCandidate(index) {
            textDocumentProxy.insertText(text)
        }
    }
}
