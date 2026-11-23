import UIKit

/// 底层依赖（librime 等）许可页：展示随包 `LICENSES/` 目录里的第三方官方许可全文。
/// 目录以「文件夹引用」形式打进 App bundle（保留层级），故按相对路径从 bundleURL 读取。
final class ThirdPartyLicensesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private struct Item {
        let title: String
        let subtitle: String
        let relPath: String?   // nil = 系统库（zlib），无随包全文
    }

    private let table = UITableView(frame: .zero, style: .insetGrouped)

    /// 17 项，与 docs/LICENSE-底层依赖许可清单 一致；relPath 指向随包 LICENSES/ 下的官方全文。
    private let items: [Item] = [
        Item(title: "许可总索引（README）", subtitle: "LICENSES/README.md", relPath: "LICENSES/README.md"),
        Item(title: "librime（Rime 引擎）", subtitle: "1.17.0 · BSD-3-Clause", relPath: "LICENSES/THIRD_PARTY_NOTICES-librime.md"),
        Item(title: "librime-lua（插件）", subtitle: "BSD-3-Clause", relPath: "LICENSES/third-party-notices/plugins/lua.txt"),
        Item(title: "librime-octagram（插件）", subtitle: "BSD-3-Clause（2026-07 由 GPLv3 重许可）", relPath: "LICENSES/third-party-notices/plugins/octagram.txt"),
        Item(title: "librime-predict（插件）", subtitle: "BSD-3-Clause", relPath: "LICENSES/third-party-notices/plugins/predict.txt"),
        Item(title: "darts-clone", subtitle: "0.32 · BSD-3-Clause", relPath: "LICENSES/third-party-notices/vcpkg/darts-clone.txt"),
        Item(title: "utf8-cpp", subtitle: "Boost Software License 1.0", relPath: "LICENSES/third-party-notices/librime/utf8-cpp.txt"),
        Item(title: "Lua", subtitle: "5.4.8 · MIT", relPath: "LICENSES/third-party-notices/vcpkg/lua.txt"),
        Item(title: "leveldb", subtitle: "1.23 · BSD-3-Clause", relPath: "LICENSES/third-party-notices/vcpkg/leveldb.txt"),
        Item(title: "marisa-trie", subtitle: "0.3.1 · BSD-2-Clause", relPath: "LICENSES/third-party-notices/vcpkg/marisa-trie.txt"),
        Item(title: "OpenCC", subtitle: "1.1.9 · Apache-2.0", relPath: "LICENSES/third-party-notices/vcpkg/opencc.txt"),
        Item(title: "yaml-cpp", subtitle: "0.9.0 · MIT", relPath: "LICENSES/third-party-notices/vcpkg/yaml-cpp.txt"),
        Item(title: "glog", subtitle: "0.7.1 · BSD-3-Clause", relPath: "LICENSES/third-party-notices/vcpkg/glog.txt"),
        Item(title: "gflags", subtitle: "2.3.0 · BSD-3-Clause", relPath: "LICENSES/third-party-notices/vcpkg/gflags.txt"),
        Item(title: "boost（algorithm/crc/interprocess/regex/scope-exit/signals2/uuid/vmd 等）", subtitle: "1.91.0 · Boost Software License 1.0（全部 boost-* 随包）", relPath: "LICENSES/third-party-notices/vcpkg/boost-regex.txt"),
        Item(title: "zlib（系统 libz）", subtitle: "zlib License · 系统库，不随包分发", relPath: nil),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = L10n.t("底层依赖许可", "Third-Party Licenses")
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

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { items.count }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        L10n.t("随包官方许可全文（BSD/MIT/Apache/BSL，无 GPL）", "Bundled official license texts (BSD/MIT/Apache/BSL, no GPL)")
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var cfg = cell.defaultContentConfiguration()
        let it = items[indexPath.row]
        cfg.text = it.title
        cfg.secondaryText = it.subtitle
        cfg.secondaryTextProperties.numberOfLines = 2
        cell.contentConfiguration = cfg
        cell.accessoryType = it.relPath != nil ? .disclosureIndicator : .none
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let it = items[indexPath.row]
        guard let rel = it.relPath else { return }
        navigationController?.pushViewController(BundledLicenseViewController(relPath: rel, title: it.title), animated: true)
    }
}

/// 读取 App bundle 内相对路径（LICENSES/ 目录引用保留层级）的许可全文。
final class BundledLicenseViewController: UIViewController {
    private let relPath: String
    init(relPath: String, title: String) { self.relPath = relPath; super.init(nibName: nil, bundle: nil); self.title = title }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let tv = UITextView(); tv.isEditable = false
        tv.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        tv.textColor = .label; tv.translatesAutoresizingMaskIntoConstraints = false
        let url = Bundle.main.bundleURL.appendingPathComponent(relPath)
        if let s = try? String(contentsOf: url, encoding: .utf8) {
            tv.text = s
        } else {
            tv.text = L10n.t("许可全文缺失：\(relPath)", "License text missing: \(relPath)")
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
