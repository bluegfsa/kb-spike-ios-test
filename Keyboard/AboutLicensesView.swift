import UIKit

/// 设置 →「关于 · 开源许可与数据来源」页：展示词库署名 + CC BY-SA 4.0 许可全文（可滚动）。
/// 纯黑白灰、不点蓝；正文 13pt。满足 CC BY-SA 4.0「随包附许可全文＋署名」义务。
final class AboutLicensesView: UIView {
    var onClose: (() -> Void)?

    private static let attribution = """
    中英对照词库 · 青简 Qingjian

    本应用的简体中文—英文对照词库部分内容来自「青简 Qingjian」的中英释义表
    （https://github.com/qingjian-team/qingjian-dicts），由原作者以 CC BY-SA 4.0
    许可发布（https://creativecommons.org/licenses/by-sa/4.0/）。
    本应用对该词库作了格式转换、检索索引改造，并对同词多义条目做了合并与排序；
    除上述改动外未修改词条内容。该词库部分内容由机器学习模型自动生成。
    基于上述词库产生的衍生数据同样以 CC BY-SA 4.0 许可提供。
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

    private static func licenseText() -> String {
        if let url = Bundle.main.url(forResource: "LICENSE.cc-by-sa-4.0", withExtension: "txt"),
           let s = try? String(contentsOf: url, encoding: .utf8) {
            return "CC BY-SA 4.0 许可全文\n\n" + s
        }
        return "CC BY-SA 4.0 许可全文见 https://creativecommons.org/licenses/by-sa/4.0/legalcode"
    }

    @objc private func closeTapped() { onClose?() }
}
