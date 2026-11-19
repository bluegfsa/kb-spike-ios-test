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
    /// #8：半透明磨砂背景层，跟随 iOS 观感（铺满整块键盘，blur 采样身后 App 内容）。
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    private let kbTopStrip = UIView() // 诊断：顶部醒目色条
#if DEBUG
    private let memHUD = UILabel()
    private var memTimer: Timer?
    private var hudOn = false
#endif
    private var returnKeyTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        // #8：背景改半透明磨砂跟随 iOS——view/键盘/候选栏透明，底下垫 UIVisualEffectView 采样身后内容。
        view.backgroundColor = .clear
        view.isOpaque = false
        keyboardView.backgroundColor = .clear
        setupBlurBackground()
        setupKeyboardView()
        setupStatusBanner()
        setupKbTopStrip()
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
        // #6：系统分配高度若只比内容高度略高（差 ≤80pt，符合顶部露白 ~25pt 的量级），说明是我们视图没吃满，
        // 才铺满到系统高度；差 >80pt 视为宿主/系统整块容器，不误当键盘高度——防止自反馈把键盘越撑越高。
        let sysH = view.superview?.bounds.height ?? 0
        let canFill = sysH > intrinsic + 1 && sysH <= intrinsic + 80
        let target = canFill ? sysH : intrinsic
        if let constraint = heightConstraint, abs(constraint.constant - target) > 0.5 {
            constraint.constant = target
            view.layoutIfNeeded()
        }
        NSLog("[KBH] view=%@ super=%@ win=%@ input=%@ safeB=%.1f intrinsic=%.1f target=%.1f",
              NSCoder.string(for: view.frame),
              view.superview.map { NSCoder.string(for: $0.bounds) } ?? "nil",
              view.window.map { NSCoder.string(for: $0.bounds) } ?? "nil",
              inputView.map { NSCoder.string(for: $0.frame) } ?? "nil",
              view.safeAreaInsets.bottom, intrinsic, target)
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
            let before = self.model.mode
            self.model.toggleMode()
            NSLog("[KBT] toggle %@ -> %@", String(describing: before), String(describing: self.model.mode))
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
        NSLog("[KBR] mode=%@ isChinese=%d buffer='%@' cands=%d prim=%@", String(describing: model.mode), isChinese ? 1 : 0, model.buffer, model.candidates.count, model.primaryTranslation ?? "nil")
        var candidates = model.candidates
        var translations = model.candidateTranslations
        // 英文态无候选、只有首选译词：仅当正在打词（buffer 非空）时显示，词边界不残留（#6）
        if !isChinese, candidates.isEmpty, !model.buffer.isEmpty, let translation = model.primaryTranslation {
            candidates = [translation]
            translations = [nil]
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
            NSLog("[KBI] letter='%@' mode=%@ buffer='%@' cands=%d prim=%@", String(character), String(describing: model.mode), model.buffer, model.candidates.count, model.primaryTranslation ?? "nil")
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
        let shown = text.isEmpty ? " " : text
        textDocumentProxy.insertText(shown) // S2-03：中文态空拼音按空格不再被吞
        NSLog("[KBS] space mode=%@ buffer='%@' inserted='%@'", String(describing: model.mode), model.buffer, shown)
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

    deinit {
#if DEBUG
        memTimer?.invalidate()
#endif
        returnKeyTimer?.invalidate()
    }
}

extension KeyboardViewController {
    /// 诊断：顶部叠 24pt 醒目粉条，真机复截看白带/圆角归属。
    func setupKbTopStrip() {
        kbTopStrip.backgroundColor = UIColor.systemPink
        kbTopStrip.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(kbTopStrip)
        NSLayoutConstraint.activate([
            kbTopStrip.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            kbTopStrip.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            kbTopStrip.topAnchor.constraint(equalTo: view.topAnchor),
            kbTopStrip.heightAnchor.constraint(equalToConstant: 24),
        ])
        view.bringSubviewToFront(kbTopStrip)
    }

    /// #8：磨砂背景铺满整块键盘（垫在最底层，blur 采样身后 App 内容）。
    func setupBlurBackground() {
        blurView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(blurView, at: 0)
        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            blurView.topAnchor.constraint(equalTo: view.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}

extension KeyboardViewController: UIGestureRecognizerDelegate {
    /// 允许双指轻点与其他手势并存（不打断单指打字）。
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}