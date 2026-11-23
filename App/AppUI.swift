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
    b.contentHorizontalAlignment = .leading
    b.translatesAutoresizingMaskIntoConstraints = false
    b.heightAnchor.constraint(equalToConstant: 44).isActive = true
    b.addTarget(target, action: action, for: .touchUpInside)
    return b
}

// MARK: - 引导（欢迎页 + 文字步骤页 + 就绪页）
final class OnboardingViewController: UIViewController {
    private var step = 0
    /// 回看入口可直接从「屏2 文字步骤」开始（默认 0=从欢迎页）。
    var startStep = 0
    /// 以「回看引导」方式弹出时的关闭回调（nil＝首启流程，完成后进文档列表）。
    var onFinish: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        step = startStep
        render()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 关键：每次显示都重新隐藏导航栏。否则从文档页返回时导航栏恢复显示，
        // 会把整屏内容整体往下压（用户反馈的「返回后画面下移」bug 根因）。
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    private func clearAll() { view.subviews.forEach { $0.removeFromSuperview() } }

    private func docButton() -> UIButton {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "doc.text"), for: .normal)
        btn.tintColor = .label
        btn.accessibilityLabel = L10n.t("文档与开源许可", "Docs & Licenses")
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(openDocs), for: .touchUpInside)
        return btn
    }

    @objc private func openDocs() {
        let vc = DocsListViewController()
        if let nav = navigationController { nav.pushViewController(vc, animated: true) }
        else { present(UINavigationController(rootViewController: vc), animated: true) }
    }

    private func stepRow(_ n: Int, _ title: String) -> UIView {
        let row = UIStackView(); row.axis = .horizontal; row.spacing = 14; row.alignment = .center
        let num = label("\(n)", size: 14, weight: .bold)
        num.textAlignment = .center
        num.layer.borderWidth = 2; num.layer.borderColor = UIColor.label.cgColor; num.layer.cornerRadius = 15
        num.widthAnchor.constraint(equalToConstant: 30).isActive = true
        num.heightAnchor.constraint(equalToConstant: 30).isActive = true
        row.addArrangedSubview(num); row.addArrangedSubview(label(title, size: 15))
        return row
    }

    private func hint(_ text: String) -> UIView {
        let v = UIView(); v.backgroundColor = .secondarySystemBackground; v.layer.cornerRadius = 12
        v.translatesAutoresizingMaskIntoConstraints = false
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
        clearAll()
        switch step {
        case 0: buildWelcome()
        case 1: buildSteps()
        default: buildReady()
        }
    }

    /// 屏1（按用户红框简化）：删标题/副标题/说明/跳过/页码；「开始添加」纯文字无箭头、屏幕正中。
    private func buildWelcome() {
        let doc = docButton()
        let start = primaryButton(L10n.t("开始添加", "Start"), target: self, action: #selector(nextStep))
        view.addSubview(doc); view.addSubview(start)
        NSLayoutConstraint.activate([
            doc.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            doc.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            doc.widthAnchor.constraint(equalToConstant: 44),
            doc.heightAnchor.constraint(equalToConstant: 44),
            // 屏幕正中（水平 + 垂直都居中）
            start.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            start.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            start.widthAnchor.constraint(equalToConstant: 200),
        ])
    }

    /// 屏2＝文字步骤：‹上一步 在左上角；标题/步骤①②/新灰卡在中部；打开设置按钮固定在屏幕底部；无页码、无副标小字、无步骤③。
    private func buildSteps() {
        let back = textButton(L10n.t("‹ 上一步", "‹ Back"), target: self, action: #selector(prevStep))
        let openBtn = primaryButton(L10n.t("打开设置", "Open Settings"), target: self, action: #selector(openSettings))

        let scroll = UIScrollView(); scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.contentInsetAdjustmentBehavior = .never
        let content = UIStackView(); content.axis = .vertical; content.spacing = 24
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)

        let title = label(L10n.t("添加「词桥输入法」", "Add \"Vocabridge\""), size: 28, weight: .bold)
        let steps = UIStackView(); steps.axis = .vertical; steps.spacing = 18
        steps.addArrangedSubview(stepRow(1, L10n.t("打开「设置」→「通用」→「键盘」→「键盘」", "Open Settings → General → Keyboard → Keyboards")))
        steps.addArrangedSubview(stepRow(2, L10n.t("点「添加新键盘」→ 选「词桥输入法」", "Tap Add New Keyboard → choose Vocabridge")))
        content.addArrangedSubview(title)
        content.addArrangedSubview(steps)
        content.addArrangedSubview(hint(L10n.t("无需「完全访问」：键盘纯本地运行、不联网。添加后在任意输入框页面长按小地球键即可切到「词桥输入法」。", "No \"Full Access\" needed: the keyboard runs fully on-device and offline. After adding, long-press the globe key in any text field to switch to Vocabridge.")))

        view.addSubview(back); view.addSubview(scroll); view.addSubview(openBtn)
        NSLayoutConstraint.activate([
            back.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            back.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),

            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: back.bottomAnchor, constant: 12),
            scroll.bottomAnchor.constraint(equalTo: openBtn.topAnchor, constant: -16),

            content.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -20),
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40),

            openBtn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            openBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            openBtn.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])
    }

    private func buildReady() {
        let title = label(L10n.t("已就绪", "Ready"), size: 28, weight: .bold)
        let enter = primaryButton(L10n.t("进入", "Enter"), target: self, action: #selector(finish))
        view.addSubview(title); view.addSubview(enter)
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            title.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            title.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 48),
            enter.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            enter.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            enter.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])
    }

    @objc private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
    @objc private func nextStep() {
        step += 1; render()   // 屏1 → 屏2 文字步骤
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
        title = L10n.t("词桥输入法", "Vocabridge")
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

    // 三个分组：0 关于与开源许可（数据词库等）｜1 底层依赖（librime 等，随包全文）｜2 应用
    func numberOfSections(in tableView: UITableView) -> Int { 3 }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 { return docs.count }
        if section == 1 { return 1 }
        return appSectionRowCount
    }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return L10n.t("关于与开源许可", "About & Licenses")
        case 1: return L10n.t("底层依赖（librime 等）", "Third-Party Libraries")
        default: return L10n.t("应用", "App")
        }
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var cfg = cell.defaultContentConfiguration()
        if indexPath.section == 0 {
            let d = docs[indexPath.row]
            cfg.text = d.title
            cfg.secondaryText = d.subtitle
        } else if indexPath.section == 1 {
            cfg.text = L10n.t("底层依赖许可（17 项·随包全文）", "Third-Party Licenses (17 items, bundled)")
            cfg.secondaryText = L10n.t("librime / leveldb / OpenCC / boost 等 · BSD/MIT/Apache/BSL，无 GPL",
                                       "librime / leveldb / OpenCC / boost etc. · BSD/MIT/Apache/BSL, no GPL")
        } else {
            let entry = appEntry(at: indexPath.row)
            cfg.text = entry.title
            cfg.secondaryText = entry.subtitle
        }
        cell.contentConfiguration = cfg
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            navigationController?.pushViewController(DocDetailViewController(doc: docs[indexPath.row]), animated: true)
        } else if indexPath.section == 1 {
            navigationController?.pushViewController(ThirdPartyLicensesViewController(), animated: true)
        } else {
            selectAppRow(indexPath.row)
        }
    }

    // MARK: - 「应用」分组行（隐私/支持入口；AppLinks 常量为空时整行隐藏，避免死链）
    private var appSectionRowCount: Int {
        1 + (AppLinks.privacyPolicyURL.isEmpty ? 0 : 1) + (AppLinks.supportURL.isEmpty ? 0 : 1)
    }
    private func appEntry(at row: Int) -> (title: String, subtitle: String) {
        if row == 0 {
            return (L10n.t("隐私政策", "Privacy Policy"), L10n.t("不收集任何个人数据", "Collects no personal data"))
        }
        var idx = 1
        if !AppLinks.privacyPolicyURL.isEmpty {
            if row == idx { return (L10n.t("隐私政策（线上版）", "Privacy Policy (online)"), AppLinks.privacyPolicyURL) }
            idx += 1
        }
        return (L10n.t("支持与反馈", "Support"), AppLinks.supportURL)
    }
    private func selectAppRow(_ row: Int) {
        if row == 0 {
            navigationController?.pushViewController(DocDetailViewController(doc: AppDocs.privacyDoc), animated: true)
            return
        }
        var idx = 1
        if !AppLinks.privacyPolicyURL.isEmpty {
            if row == idx { openURLString(AppLinks.privacyPolicyURL); return }
            idx += 1
        }
        openURLString(AppLinks.supportURL)
    }
    private func openURLString(_ s: String) {
        guard !s.isEmpty, let url = URL(string: s) else { return }
        UIApplication.shared.open(url)
    }}

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
