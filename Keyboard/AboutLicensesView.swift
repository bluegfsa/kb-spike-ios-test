import UIKit

/// 设置 →「关于 · 开源许可与数据来源」页：展示词库署名 + CC BY-SA 4.0 许可全文（可滚动）。
/// 纯黑白灰、不点蓝；正文 13pt。满足 CC BY-SA 4.0「随包附许可全文＋署名」义务。
final class AboutLicensesView: UIView {
    var onClose: (() -> Void)?

    private static let attribution = """
    中英对照词库 · 数据来源与许可

    1) 青简 Qingjian — 中英释义表（CC BY-SA 4.0）
       https://github.com/qingjian-team/qingjian-dicts
    2) CC-CEDICT — 中→英词库（CC BY-SA 4.0）
       https://www.mdbg.net/chinese/dictionary?page=cc-cedict
    3) ECDICT — 英→中词库（MIT）
       https://github.com/skywind3000/ECDICT

    本应用对上述词库作了格式转换、检索索引改造，并对同词多义条目做了合并与排序（≤3 义）、去重、按 key 排序；除上述改动外未修改词条内容。青简部分的词条由机器学习模型自动生成。
    基于上述词库产生的衍生数据同样以 CC BY-SA 4.0 许可提供。
    词库版本：v1.69-lexicon
    公开数据仓：https://github.com/bluegfsa/kb-lexicon
    """

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textColor = .label
        textView.font = .systemFont(ofSize: 13)
        textView.text = Self.attribution + "\n\n" + Self.licenseText()
        textView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textView)

        let done = UIButton(type: .system)
        done.setTitle("完成", for: .normal)
        done.setTitleColor(.label, for: .normal)
        done.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        done.translatesAutoresizingMaskIntoConstraints = false
        done.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        addSubview(done)

        NSLayoutConstraint.activate([
            done.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            done.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            textView.topAnchor.constraint(equalTo: done.bottomAnchor, constant: 6),
            textView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
        ])
    }

    /// 依次附上三份许可全文（CC BY-SA 4.0 / CC-CEDICT 同 CC BY-SA 4.0 / ECDICT MIT）。
    private static func licenseText() -> String {
        var parts: [String] = []
        parts.append("=== CC BY-SA 4.0 许可全文 ===\n" + bundled("LICENSE.cc-by-sa-4.0.txt",
                     fallback: "https://creativecommons.org/licenses/by-sa/4.0/legalcode"))
        parts.append("=== CC-CEDICT 许可（CC BY-SA 4.0） ===\n" + bundled("LICENSE.cc-cedict.txt",
                     fallback: "https://creativecommons.org/licenses/by-sa/4.0/"))
        parts.append("=== ECDICT 许可（MIT） ===\n" + bundled("LICENSE.ecdict.txt",
                     fallback: "https://github.com/skywind3000/ECDICT/blob/master/LICENSE"))
        return parts.joined(separator: "\n\n")
    }

    private static func bundled(_ name: String, fallback: String) -> String {
        let ns = name as NSString
        if let url = Bundle.main.url(forResource: ns.deletingPathExtension, withExtension: ns.pathExtension),
           let s = try? String(contentsOf: url, encoding: .utf8) {
            return s
        }
        return fallback
    }

    @objc private func closeTapped() { onClose?() }
}
