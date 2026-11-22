import UIKit

// MARK: - 文档模型
struct LicenseDoc {
    let title: String
    let subtitle: String
    let body: String
    let licenseFile: String?   // 包内许可全文（nil=仅正文）
}

enum AppDocs {
    static let onboardingKey = "kb.onboardingDone"
    static var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
    }
    static let docs: [LicenseDoc] = [
        LicenseDoc(
            title: "中英对照词库 · 青简 Qingjian",
            subtitle: "CC BY-SA 4.0",
            body: """
            本应用的简体中文—英文对照词库部分内容来自「青简 Qingjian」的中英释义表（https://github.com/qingjian-team/qingjian-dicts），由原作者以 CC BY-SA 4.0 许可发布（https://creativecommons.org/licenses/by-sa/4.0/）。

            本应用对该词库作了格式转换、检索索引改造，并对同词多义条目做了合并与排序；除上述改动外未修改词条内容。

            该词库部分内容由机器学习模型自动生成。

            基于上述词库产生的衍生数据同样以 CC BY-SA 4.0 许可提供。
            """,
            licenseFile: "LICENSE.cc-by-sa-4.0.txt"),
        LicenseDoc(
            title: "CC-CEDICT 汉英词典",
            subtitle: "CC BY-SA 4.0",
            body: """
            中→英短译表（zh2en.txt）由 CC-CEDICT 数据生成。

            项目：CC-CEDICT (Chinese-English Dictionary)
            来源：https://www.mdbg.net/chinese/dictionary?page=cc-cedict
            许可：CC BY-SA 4.0（https://creativecommons.org/licenses/by-sa/4.0/）
            """,
            licenseFile: "LICENSE.cc-cedict.txt"),
        LicenseDoc(
            title: "ECDICT 词库",
            subtitle: "MIT License",
            body: """
            英→中短译表（en2zh.txt）由 ECDICT 数据生成，仅取常用词并抽取主译短义。

            项目：ECDICT (Free English to Chinese Dictionary Database)
            作者：skywind3000
            来源：https://github.com/skywind3000/ECDICT
            许可：MIT License（Copyright (c) skywind3000）
            """,
            licenseFile: "LICENSE.ecdict.txt"),
        LicenseDoc(
            title: "拼音词典 · jieba 词频",
            subtitle: "MIT · © 2013 Sun Junyi",
            body: """
            本键盘的拼音候选词频由 jieba 中文分词词频数据（https://github.com/fxsjy/jieba）构建，按 MIT 许可使用。

            处理说明：格式转换为「词-音节-词频」、同词合并去重、按词频排序；除上述外未修改原始数据。
            """,
            licenseFile: "LICENSE.jieba.txt"),
        LicenseDoc(
            title: "拼音数据 · pinyin-data",
            subtitle: "MIT · © 2016 mozillazg",
            body: """
            汉字拼音读音数据来自 pinyin-data（https://github.com/mozillazg/pinyin-data），按 MIT 许可使用。
            """,
            licenseFile: "LICENSE.pinyin-data.txt"),
        LicenseDoc(
            title: "拼音数据 · phrase-pinyin-data",
            subtitle: "MIT · © 2017 mozillazg",
            body: """
            词语拼音数据来自 phrase-pinyin-data（https://github.com/mozillazg/phrase-pinyin-data），按 MIT 许可使用。
            """,
            licenseFile: "LICENSE.phrase-pinyin-data.txt"),
        LicenseDoc(
            title: "拼音方案 · pinyin-simp",
            subtitle: "Apache License 2.0 · Rime",
            body: """
            拼音输入方案 pinyin-simp（https://github.com/rime/rime-pinyin-simp）来自 Rime 官方，按 Apache License 2.0 使用。
            """,
            licenseFile: "LICENSE.pinyin-simp.txt"),
        LicenseDoc(
            title: "Rime 基础配置 · prelude",
            subtitle: "LGPL-3.0 · Rime",
            body: """
            Rime 基础配置 rime-prelude（default/key_bindings/punctuation/symbols 等，https://github.com/rime/rime-prelude）按 GNU Lesser General Public License v3.0 使用，许可全文随应用附于本页「查看许可全文」。

            署名：rime-prelude / Rime 项目（https://github.com/rime）。

            修改说明：本应用对 default.yaml 等配置作了裁剪与精简（去除未使用的输入方案与部分快捷键绑定），标点与符号映射数据本身未改动。

            可替换说明：上述配置文件以独立数据文件形式随应用打包，用户可自行查看、修改，或用同格式文件替换。
            """,
            licenseFile: "LICENSE.prelude.txt"),
        LicenseDoc(
            title: "关于双译键盘",
            subtitle: "版本 \(version)",
            body: """
            双译键盘：边打字边看中英词/短语对照的输入法辅助。

            词库全部离线、不联网；输入内容只在本机处理。

            词库数据以 CC BY-SA 4.0 公开发布：https://github.com/bluegfsa/kb-lexicon
            """,
            licenseFile: nil
        ),
    ]
}

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
        render()
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
        t.addArrangedSubview(label(sub, size: 13, color: .secondaryLabel))
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
            stack.addArrangedSubview(label("双译键盘", size: 28, weight: .bold))
            stack.addArrangedSubview(label("边打字边看中英词/短语对照，纯本地、不联网。", size: 15, color: .secondaryLabel))
            stack.addArrangedSubview(hint("词库与输入内容都只存在你的手机上，键盘不上传任何内容。"))
            stack.addArrangedSubview(primaryButton("开始设置", target: self, action: #selector(nextStep)))
            stack.addArrangedSubview(textButton("跳过，直接进入 →", target: self, action: #selector(finish)))
        } else if step == 1 {
            stack.addArrangedSubview(label("添加「双译键盘」", size: 28, weight: .bold))
            stack.addArrangedSubview(label("3 步，约 1 分钟。加好后回到这里点「下一步」。", size: 15, color: .secondaryLabel))
            stack.addArrangedSubview(stepRow(1, "打开「设置」→ 通用 → 键盘", "在键盘页里点「键盘」进入键盘列表"))
            stack.addArrangedSubview(stepRow(2, "点「添加新键盘」→ 选「双译键盘」", "中文/英文都勾选，点右上角「完成」"))
            stack.addArrangedSubview(stepRow(3, "回到本 App，点下面的「下一步」", "已添加可跳过这屏"))
            stack.addArrangedSubview(hint("提示：添加后在任意输入框点系统键盘的地球键 🌐 即可切到「双译键盘」。无需完全访问也能用。"))
            stack.addArrangedSubview(primaryButton("打开设置", target: self, action: #selector(openSettings)))
            stack.addArrangedSubview(textButton("已添加，下一步 →", target: self, action: #selector(nextStep)))
        } else {
            stack.addArrangedSubview(label("已就绪", size: 28, weight: .bold))
            stack.addArrangedSubview(label("现在可在任意输入框点系统键盘的地球键 🌐 切换到「双译键盘」。", size: 15, color: .secondaryLabel))
            stack.addArrangedSubview(hint("下面可查看开源许可与关于信息。"))
            stack.addArrangedSubview(primaryButton("进入", target: self, action: #selector(finish)))
        }
    }

    @objc private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
    @objc private func nextStep() { step += 1; render() }
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
        title = "双译键盘"
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
        section == 0 ? docs.count : 1
    }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "关于与开源许可" : "应用"
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var cfg = cell.defaultContentConfiguration()
        if indexPath.section == 0 {
            let d = docs[indexPath.row]
            cfg.text = d.title
            cfg.secondaryText = d.subtitle
        } else {
            cfg.text = "使用引导"
            cfg.secondaryText = "重新查看添加键盘步骤"
        }
        cell.contentConfiguration = cfg
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            navigationController?.pushViewController(DocDetailViewController(doc: docs[indexPath.row]), animated: true)
        } else {
            let vc = OnboardingViewController()
            vc.modalPresentationStyle = .fullScreen
            vc.onFinish = { [weak vc] in vc?.dismiss(animated: true) }
            present(vc, animated: true)
        }
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
