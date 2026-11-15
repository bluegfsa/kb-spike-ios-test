import UIKit

/// 中/英 双行切换键（#1 照微信样式自绘，不抠素材）。
/// 单键内「中」上「英」下；当前语言加粗加黑、另一语种灰，label 立即反映（#13 同帧刷新）。
final class ModeToggleButton: UIButton {
    private let zhLabel = UILabel()
    private let enLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = KBColor.letterKey
        layer.cornerRadius = 6
        clipsToBounds = true
        zhLabel.text = "中"
        zhLabel.textAlignment = .center
        enLabel.text = "英"
        enLabel.textAlignment = .center
        [zhLabel, enLabel].forEach { $0.isUserInteractionEnabled = false }
        let stack = UIStackView(arrangedSubviews: [zhLabel, enLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = -1
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(isChinese: Bool) {
        zhLabel.font = .systemFont(ofSize: 14, weight: isChinese ? .bold : .regular)
        enLabel.font = .systemFont(ofSize: 10, weight: isChinese ? .regular : .bold)
        zhLabel.textColor = isChinese ? KBColor.activeLang : KBColor.inactiveLang
        enLabel.textColor = isChinese ? KBColor.inactiveLang : KBColor.activeLang
    }
}

/// 带闭包的按钮（UIButton 不支持 target/action 直接闭包）。
final class ClosureButton: UIButton {
    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleTap() { onTap?() }
}

/// 键盘配色：iOS 系统色，跟随深浅色（UI v0.3.3）。
enum KBColor {
    static func dyn(_ light: Int, _ dark: Int) -> UIColor {
        UIColor(dynamicProvider: { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
    static let background = dyn(0xD1D3D9, 0x2C2C2E)      // 底
    static let letterKey = dyn(0xFFFFFF, 0x636366)       // 字母键
    static let functionKey = dyn(0xADB3BD, 0x48484A)     // 功能键
    static let keyBorder = dyn(0xB9BDC4, 0x3A3A3C)       // 字母键描边
    static let keyText = dyn(0x000000, 0xFFFFFF)
    static let pinyin = dyn(0x3C3C43, 0xEBEBF5)          // 拼音串
    static let candidateText = dyn(0x000000, 0xFFFFFF)   // 候选汉字
    static let translation = dyn(0x6B6B70, 0xAEAEB2)     // 候选译文
    static let activeLang = dyn(0x000000, 0xFFFFFF)      // 当前语言
    static let inactiveLang = dyn(0x6B6B70, 0xAEAEB2)    // 另一语种
}

extension UIColor {
    convenience init(hex: Int) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}
