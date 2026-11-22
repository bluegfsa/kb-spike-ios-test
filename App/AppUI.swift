import UIKit


// MARK: - 小工具
private func label(_ text: String, size: CGFloat, weight: UIFont.Weight = .regular, color: UIColor = .label) -> UILabel {
    let l = UILabel(); l.text = text; l.font = .systemFont(ofSize: size, weight: weight); l.textColor = color
    l.numberOfLines = 0; l.translatesAutoresizingMaskIntoConstraints = false; return l
}

private func primaryButton(_ title: String, target: Any?, action: Selector) -> UIButton {
    let b = UIButton(type: .system)
    b.setTitle(title, for: .normal)
    b.setTitleColor(.white, for: .normal)
    b.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
    b.backgroundColor = .black
    b.layer.cornerRadius = 12
    b.translatesAutoresizingMaskIntoConstraints = false
    b.heightAnchor.constraint(equalToConstant: 50).isActive = true
    b.addTarget(target, action: action, for: .touchUpInside)
    return b
}

private func textButton(_ title: String, target: Any?, action: Selector) -> UIButton {
    let b = UIButton(type: .system)
    b.setTitle(title, for: .normal)
    b.setTitleColor(UIColor(named: "ink2") ?? UIColor(white: 0.24, alpha: 1), for: .normal)
    b.titleLabel?.font = .systemFont(ofSize: 15)
    b.translatesAutoresizingMaskIntoConstraints = false
    b.heightAnchor.constraint(equalToConstant: 44).isActive = true
    b.addTarget(target, action: action, for: .touchUpInside)
    return b
}

// MARK: - 引导（两屏）
final class OnboardingViewController: UIViewController {
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private var step = 0
    /// 回看入口可直接从「屏2 文字步骤」开始（默认 0=从欢迎页）。
    var startStep = 0
    /// 以「回看引导」方式弹出时的关闭回调（nil＝首启流程，完成后进文档列表）。
    var onFinish: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationController?.setNavigationBarHidden(true, animated: false)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        stack.axis = .vertical; stack.spacing = 12; stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 8),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -20),
        ])
        step = startStep
        render()
        addDocButton()
    }

    /// 右上角文档图标按钮（点开文档/开源许可）。
    private func addDocButton() {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "doc.text"), for: .normal)
        btn.tintColor = .label
        btn.accessibilityLabel = L10n.t("文档与开源许可", "Docs & Licenses")
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(openDocs), for: .touchUpInside)
        view.addSubview(btn)
        NSLayoutConstraint.activate([
            btn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            btn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            btn.widthAnchor.constraint(equalToConstant: 44),
            btn.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    @objc private func openDocs() {
        let vc = DocsListViewController()
        if let nav = navigationController { nav.pushViewController(vc, animated: true) }
        else { present(UINavigationController(rootViewController: vc), animated: true) }
    }

    /// 居中的「开始添加」按钮（纯文字、无箭头，固定宽 200）。
    private func centeredStartButton() -> UIView {
        let holder = UIView()
        let b = primaryButton(L10n.t("开始添加", "Start"), target: self, action: #selector(nextStep))
        holder.addSubview(b)
        NSLayoutConstraint.activate([
            b.centerXAnchor.constraint(equalTo: holder.centerXAnchor),
            b.topAnchor.constraint(equalTo: holder.topAnchor),
            b.bottomAnchor.constraint(equalTo: holder.bottomAnchor),
            b.widthAnchor.constraint(equalToConstant: 200),
        ])
        return holder
    }

    private func clear() { stack.arrangedSubviews.forEach { $0.removeFromSuperview() } }

    private func stepRow(_ n: Int, _ title: String, _ sub: String) -> UIView {
        let row = UIStackView(); row.axis = .horizontal; row.spacing = 14; row.alignment = .top
        let num = label("\(n)", size: 14, weight: .bold)
        num.textAlignment = .center
        num.layer.borderWidth = 2; num.layer.borderColor = UIColor.label.cgColor; num.layer.cornerRadius = 15
        num.widthAnchor.constraint(equalToConstant: 30).isActive = true
        num.heightAnchor.constraint(equalToConstant: 30).isActive = true
        let t = UIStackView(); t.axis = .vertical; t.spacing = 3
        t.addArrangedSubview(label(title, size: 15))
        if !sub.isEmpty { t.addArrangedSubview(label(sub, size: 13, color: .secondaryLabel)) }
        row.addArrangedSubview(num); row.addArrangedSubview(t)
        return row
    }

    private func hint(_ text: String) -> UIView {
        let v = UIView(); v.backgroundColor = .secondarySystemBackground; v.layer.cornerRadius = 12
        let l = label(text, size: 13, color: .secondaryLabel); v.addSubview(l)
        NSLayoutConstraint.activate([
            l.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 14),
            l.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -14),
            l.topAnchor.constraint(equalTo: v.topAnchor, constant: 12),
            l.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -12),
        ])
        return v
    }

    private func render() {
        clear()
        if step == 0 {
            // 屏1（按用户红框简化）：删标题/说明/跳过/页码；副标题保留，居中的「开始添加」纯文字无箭头
            stack.addArrangedSubview(UIView())
            stack.addArrangedSubview(label(L10n.t("中文打字，边打边看到英文释义。", "Type in Chinese and see English meanings as you go."), size: 15, color: .secondaryLabel))
            stack.addArrangedSubview(centeredStartButton())
            stack.addArrangedSubview(UIView())
        } else if step == 1 {
            // 屏2＝文字步骤（按 PRD §10 红框删除项精简：只留 ‹上一步/标题/步骤①②主行/新灰卡/打开设置/2·3）
            stack.addArrangedSubview(textButton(L10n.t("‹ 上一步", "‹ Back"), target: self, action: #selector(prevStep)))
            stack.addArrangedSubview(label(L10n.t("添加「语桥输入法」", "Add \"WordBridge\""), size: 28, weight: .bold))
            stack.addArrangedSubview(stepRow(1, L10n.t("打开「设置」→「通用」→「键盘」→「键盘」", "Open Settings → General → Keyboard → Keyboards"), ""))
            stack.addArrangedSubview(stepRow(2, L10n.t("点「添加新键盘」→ 选「语桥输入法」", "Tap Add New Keyboard → choose WordBridge"), ""))
            stack.addArrangedSubview(hint(L10n.t("无需「完全访问」：键盘纯本地运行、不联网。添加后在任意输入框页面长按小地球键即可切到「语桥输入法」。", "No \"Full Access\" needed: the keyboard runs fully on-device and offline. After adding, long-press the globe key in any text field to switch to WordBridge.")))
            stack.addArrangedSubview(primaryButton(L10n.t("打开设置", "Open Settings"), target: self, action: #selector(openSettings)))
            let page = label("2 / 3", size: 12, color: .secondaryLabel)
            page.textAlignment = .center
            stack.addArrangedSubview(page)
        } else {
            stack.addArrangedSubview(label(L10n.t("已就绪", "Ready"), size: 28, weight: .bold))
            stack.addArrangedSubview(label(L10n.t("现在可在任意输入框点系统键盘的地球键 🌐 切换到「语桥输入法」。", "Tap the 🌐 key on the system keyboard in any text field to switch to WordBridge."), size: 15, color: .secondaryLabel))
            stack.addArrangedSubview(hint(L10n.t("下面可查看开源许可与关于信息。", "Open-source licenses and about info are below.")))
            stack.addArrangedSubview(primaryButton(L10n.t("进入", "Enter"), target: self, action: #selector(finish)))
        }
    }

    @objc private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
    @objc private func nextStep() {
        step += 1; render()   // 屏1 → 屏2 文字步骤 → 屏3 就绪
    }
    @objc private func prevStep() {
        if step > 0 { step -= 1; render() }
    }
    @objc private func finish() {
        UserDefaults.standard.set(true, forKey: AppDocs.onboardingKey)
        if let onFinish { onFinish(); return }
        if let nav = navigationController {
            nav.setViewControllers([DocsListViewController()], animated: true)
        } else {
            view.window?.rootViewController = UINavigationController(rootViewController: DocsListViewController())
        }
    }
}

// MARK: - 文档列表
final class DocsListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let table = UITableView(frame: .zero, style: .insetGrouped)
    private let docs = AppDocs.docs

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = L10n.t("语桥输入法", "WordBridge")
        navigationController?.setNavigationBarHidden(false, animated: false)
        table.dataSource = self; table.delegate = self
        table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        table.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(table)
        NSLayoutConstraint.activate([
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table.topAnchor.constraint(equalTo: view.topAnchor),
            table.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    func numberOfSections(in tableView: UITableView) -> Int { 2 }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? docs.count : 3
    }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? L10n.t("关于与开源许可", "About & Licenses") : L10n.t("应用", "App")
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var cfg = cell.defaultContentConfiguration()
        if indexPath.section == 0 {
            let d = docs[indexPath.row]
            cfg.text = d.title
            cfg.secondaryText = d.subtitle
        } else if indexPath.row == 0 {
            cfg.text = L10n.t("使用引导", "How to Use")
            cfg.secondaryText = L10n.t("重新查看添加键盘步骤", "Replay the keyboard setup tutorial")
        } else if indexPath.row == 1 {
            cfg.text = L10n.t("联系我们", "Contact Us")
            cfg.secondaryText = L10n.t("海外 Gmail · 国内 163", "Overseas Gmail · China 163")
        } else {
            cfg.text = L10n.t("隐私政策", "Privacy Policy")
            cfg.secondaryText = L10n.t("不收集任何个人数据", "Collects no personal data")
        }
        cell.contentConfiguration = cfg
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            navigationController?.pushViewController(DocDetailViewController(doc: docs[indexPath.row]), animated: true)
        } else if indexPath.row == 0 {
            // 回看入口：直接从「屏2 文字步骤」开始（不回欢迎页、不改 onboardingDone）
            let vc = OnboardingViewController()
            vc.startStep = 1
            vc.modalPresentationStyle = .fullScreen
            vc.onFinish = { [weak vc] in vc?.dismiss(animated: true) }
            present(vc, animated: true)
        } else if indexPath.row == 1 {
            contactSheet()   // 联系我们：弹两个邮箱（海外 Gmail 在前 / 国内 163）
        } else {
            navigationController?.pushViewController(DocDetailViewController(doc: AppDocs.privacyDoc), animated: true)
        }
    }

    /// 联系我们：让用户选海外(Gmail)或国内(163)，各自 mailto。
    private func contactSheet() {
        let subject = L10n.t("语桥输入法 反馈", "WordBridge Feedback")
        let enc = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let sheet = UIAlertController(title: L10n.t("联系我们", "Contact Us"), message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: L10n.t("海外用户 · Gmail", "Overseas · Gmail"), style: .default) { [weak self] _ in
            self?.openMail(AppDocs.supportEmailOverseas, subject: enc)
        })
        sheet.addAction(UIAlertAction(title: L10n.t("国内用户 · 163", "China · 163"), style: .default) { [weak self] _ in
            self?.openMail(AppDocs.supportEmailCN, subject: enc)
        })
        sheet.addAction(UIAlertAction(title: L10n.t("取消", "Cancel"), style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        }
        present(sheet, animated: true)
    }

    private func openMail(_ address: String, subject: String) {
        if let url = URL(string: "mailto:\(address)?subject=\(subject)") { UIApplication.shared.open(url) }
    }
}

// MARK: - 文档详情 / 许可全文
final class DocDetailViewController: UIViewController {
    private let doc: LicenseDoc
    init(doc: LicenseDoc) { self.doc = doc; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = doc.title
        let scroll = UIScrollView(); scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        let stack = UIStackView(); stack.axis = .vertical; stack.spacing = 12; stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 12),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
        ])
        stack.addArrangedSubview(label(doc.subtitle, size: 13, color: .secondaryLabel))
        stack.addArrangedSubview(label(doc.body, size: 15, color: .secondaryLabel))
        if let file = doc.licenseFile {
            stack.addArrangedSubview(primaryButton("查看许可全文", target: self, action: #selector(openLicense)))
            objc_setAssociatedObject(self, &DocDetailViewController.fileKey, file, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    private static var fileKey: UInt8 = 0
    @objc private func openLicense() {
        guard let file = objc_getAssociatedObject(self, &DocDetailViewController.fileKey) as? String else { return }
        navigationController?.pushViewController(LicenseTextViewController(fileName: file, title: "\(doc.subtitle) 许可全文"), animated: true)
    }
}

final class LicenseTextViewController: UIViewController {
    private let fileName: String
    init(fileName: String, title: String) { self.fileName = fileName; super.init(nibName: nil, bundle: nil); self.title = title }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let tv = UITextView(); tv.isEditable = false; tv.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        tv.textColor = .secondaryLabel; tv.translatesAutoresizingMaskIntoConstraints = false
        // fileName 为包内完整文件名（含 .txt），整串作为 resource 名直取，避免拆分多段文件名出错
        if let url = Bundle.main.url(forResource: fileName, withExtension: nil),
           let s = try? String(contentsOf: url, encoding: .utf8) {
            tv.text = s
        } else {
            tv.text = "许可全文缺失"
        }
        view.addSubview(tv)
        NSLayoutConstraint.activate([
            tv.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tv.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            tv.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tv.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}
