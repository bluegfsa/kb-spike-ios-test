import UIKit

/// 键盘扩展入口：只绑 `KeyboardModeling`（B1 用 `MockKeyboardModel`），不碰引擎/词库细节。
/// 交互按实现级接口 v0.2 §6 + 按键行为规格（#11~#15）执行；引擎接上后换成真实 `KeyboardModel`，本文件零改动。
final class KeyboardViewController: UIInputViewController {
    private let keyboardView = KeyboardView()
    private let statusBanner = UILabel()
    private var model: KeyboardModeling = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return KeyboardModel(sharedDir: base.appendingPathComponent("rime/shared"), userDir: base.appendingPathComponent("rime/user"))
    }()
    private var heightConstraint: NSLayoutConstraint?
    /// #8（微信输入法同款）：键盘顶部比原生多垫高一段，用我们自己的半透明底把那截白圆角盖住。
    private let kbTopCover: CGFloat = 0 // 顶部上探归零：改由前端 44pt 顶栏(候选+两圆钮)在键盘视图内覆盖白圆角，总高≈300
#if DEBUG
    private let memHUD = UILabel()
    private var memTimer: Timer?
    private var hudOn = false
#endif
    private var returnKeyTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()        // #8（微信输入法同款）：自己做「半透明底」不依赖采壁纸（UI v0.8：浅 #F2F3F5 / 深 #1C1C1E，alpha 0.88）；
        // 键盘/候选栏透明露出底色，配合键盘顶部上探 kbTopCover 盖住系统那条白圆角。
        // #8（微信同款）：不铺不透明色、不自绘模糊——背景全透明，让 iOS 系统键盘自带的原生毛玻璃背板透出。
        view.backgroundColor = .clear
        view.isOpaque = false
        keyboardView.backgroundColor = .clear
        setupKeyboardView()
        setupStatusBanner()
#if DEBUG
        setupMemHUD()
        // 双指轻点键盘：开/关内存读数叠加（仅 debug，正式包不留入口，见 #1）
        let twoFingerTap = UITapGestureRecognizer(target: self, action: #selector(toggleMemHUD))
        twoFingerTap.numberOfTouchesRequired = 2
        twoFingerTap.cancelsTouchesInView = false
        twoFingerTap.delegate = self
        view.addGestureRecognizer(twoFingerTap)
#endif
        model.onChange = { [weak self] in self?.render() }
        render()
    }

    /// #2/#3：高度按内容＋底部安全区自适应（不写死 291），露白/挡输入框问题由此解决。
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        syncReturnKeyTitle()
        let intrinsic = keyboardView.intrinsicKeyboardHeight(bottomInset: view.safeAreaInsets.bottom)
        // #8：内容高度 + 顶部上探 kbTopCover（多出来这段用半透明底盖住系统白圆角）；上限防自反馈撑高。
        let target = min(intrinsic + kbTopCover, intrinsic + 120)
        if let constraint = heightConstraint, abs(constraint.constant - target) > 0.5 {
            constraint.constant = target
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
            keyboardView.topAnchor.constraint(equalTo: view.topAnchor, constant: kbTopCover),
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

#if DEBUG
    // MARK: - 内存读数叠加（调试，仅真机验收用）
    private func setupMemHUD() {
        memHUD.font = .monospacedSystemFont(ofSize: 11, weight: .bold)
        memHUD.textColor = .white
        memHUD.backgroundColor = UIColor.systemRed.withAlphaComponent(0.85)
        memHUD.textAlignment = .center
        memHUD.layer.cornerRadius = 4
        memHUD.clipsToBounds = true
        memHUD.numberOfLines = 1
        memHUD.isHidden = true
        memHUD.translatesAutoresizingMaskIntoConstraints = false
        memHUD.text = ""
        view.addSubview(memHUD)
        NSLayoutConstraint.activate([
            memHUD.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            memHUD.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            memHUD.heightAnchor.constraint(equalToConstant: 18),
            memHUD.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
        ])
        view.bringSubviewToFront(memHUD)
    }

    @objc private func toggleMemHUD() {
        hudOn.toggle()
        memHUD.isHidden = !hudOn
        if hudOn {
            updateMemHUD()
            memTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.updateMemHUD()
            }
        } else {
            memTimer?.invalidate()
            memTimer = nil
        }
    }

    private func updateMemHUD() {
        let cur = DebugFootprint.sample()
        memHUD.text = String(format: "内存 %.1fMB / 峰值 %.1fMB", cur, DebugFootprint.peakMB)
        view.bringSubviewToFront(memHUD)
    }
#endif

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        syncReturnKeyTitle()
        // 键盘每次出现都重置引擎 composition，避免上一次未提交拼音残留成候选（如 tazai 显示上次输入）
        if let m = model as? KeyboardModel { m.resetSession() }
        // S2-02：同一 App 内切换输入框不会触发 viewWillAppear，用轻量轮询同步回车键面。
        returnKeyTimer?.invalidate()
        returnKeyTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.syncReturnKeyTitle()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        returnKeyTimer?.invalidate()
        returnKeyTimer = nil
    }

    private func syncReturnKeyTitle() {
        keyboardView.setReturnKeyTitle(currentReturnKeyTitle())
    }

    /// 读宿主 App 期望的回车键类型，映射键面文字；动作统一为换行符（规格 §D/§G2）。
    private func currentReturnKeyTitle() -> String {
        let zh = model.mode == .zh2en
        switch textDocumentProxy.returnKeyType {
        case .send?: return zh ? "发送" : "send"
        case .search?: return zh ? "搜索" : "search"
        case .go?: return zh ? "前往" : "go"
        case .done?: return zh ? "完成" : "done"
        case .next?: return zh ? "下一项" : "next"
        case .continue?: return zh ? "继续" : "continue"
        default: return zh ? "换行" : "return"
        }
    }

    // MARK: - 渲染（model.onChange 主线程回调后执行）
    private func render() {
        keyboardView.setReturnKeyTitle(currentReturnKeyTitle())
        let isChinese = model.mode == .zh2en
        var candidates = model.candidates
        var translations = model.candidateTranslations
        // 英文态无候选、只有首选译词：仅当正在打词（buffer 非空）时显示，词边界不残留（#6）
        if !isChinese, candidates.isEmpty, !model.buffer.isEmpty, let translation = model.primaryTranslation {
            candidates = [translation]
            translations = [nil]
        }
        // BUG-7 兜底：中文态 buffer 已空则强制清候选，杜绝残留（与 model.backspace 双保险）
        if isChinese && model.buffer.isEmpty {
            candidates = []; translations = []
        }
        keyboardView.update(
            candidates: candidates,
            translations: translations,
            buffer: model.buffer,
            isChinese: isChinese,
            punctuationFullWidth: model.punctuationFullWidth,
            selectable: isChinese // 英文态译文占位不可点（S3-02）
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
            // 数字/符号：直接上屏；中文态若还有未提交的拼音，先把拼音提交再插符号（S2-01，避免候选残留）。
            if model.mode == .zh2en && !model.buffer.isEmpty {
                let committed = model.space()
                if !committed.isEmpty { textDocumentProxy.insertText(committed) }
            }
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
        textDocumentProxy.insertText(text.isEmpty ? " " : text) // S2-03：中文态空拼音按空格不再被吞
    }

    private func handleReturn() {
        let text = model.newline() // #15：只换行（第三方键盘无法程序化发送）
        if !text.isEmpty {
            textDocumentProxy.insertText(text)
        }
    }

    private func handleCandidate(_ index: Int) {
        // BUG-1 兜底：先缓存被点候选文本；selectCandidate 内部已 clearComposition，返回 nil 时直接上屏该文本也不残留
        let fallback = (index >= 0 && index < model.candidates.count) ? model.candidates[index] : nil
        if let text = model.selectCandidate(index) {
            textDocumentProxy.insertText(text)
        } else if let f = fallback {
            textDocumentProxy.insertText(f)
        }
    }

    deinit {
#if DEBUG
        memTimer?.invalidate()
#endif
        returnKeyTimer?.invalidate()
    }
}

extension KeyboardViewController: UIGestureRecognizerDelegate {
    /// 允许双指轻点与其他手势并存（不打断单指打字）。
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

// MARK: - 系统按键音：用户要求键盘不发声，故关闭系统按键音（enableInputClicksWhenVisible=false）
extension KeyboardViewController: UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { false }
}
