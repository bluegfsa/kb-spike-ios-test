import UIKit

/// 键盘扩展入口：只绑 `KeyboardModeling`（B1 用 `MockKeyboardModel`），不碰引擎/词库细节。
/// 交互按实现级接口 v0.2 §6 执行；引擎接上后换成真实 `KeyboardModel`，本文件零改动。
final class KeyboardViewController: UIInputViewController {
    private let keyboardView = KeyboardView()
    private let statusBanner = UILabel()
    private var model: KeyboardModeling = MockKeyboardModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupKeyboardView()
        setupStatusBanner()
        model.onChange = { [weak self] in self?.render() }
        render()
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
            keyboardView.heightAnchor.constraint(equalToConstant: 291),
        ])

        keyboardView.onKeyText = { [weak self] text in self?.handleKeyText(text) }
        keyboardView.onBackspace = { [weak self] in self?.handleBackspace() }
        keyboardView.onSpace = { [weak self] in self?.handleSpace() }
        keyboardView.onReturn = { [weak self] in self?.handleReturn() }
        keyboardView.onToggleMode = { [weak self] in self?.model.toggleMode() }
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
        let gloss: String? = model.primaryTranslation.map { isChinese ? "EN \($0)" : "中 \($0)" }
        keyboardView.update(
            candidates: model.candidates,
            buffer: model.buffer,
            gloss: gloss,
            isChinese: isChinese
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
            // 数字/符号：直接上屏，不进拼音 buffer。
            textDocumentProxy.insertText(text)
        }
    }

    private func handleBackspace() {
        if model.mode == .zh2en && !model.buffer.isEmpty {
            model.backspace() // 只删拼音串，未落文档
        } else {
            textDocumentProxy.deleteBackward() // 先删真实文本
            model.backspace() // 再同步 buffer/候选
        }
    }

    private func handleSpace() {
        let text = model.space()
        if !text.isEmpty {
            textDocumentProxy.insertText(text)
        }
    }

    private func handleReturn() {
        let text = model.newline()
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
