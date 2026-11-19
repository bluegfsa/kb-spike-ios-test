import UIKit

/// 按键预览气泡（#10）：圆角、融进按键，参考 iOS 原生键盘——底边贴着键顶、四角圆角、几乎无投影。
/// 挂到整块按键区容器（跨行不被别的行盖住）。字母/功能/上档/中英键共用这一份实现，避免各画各的。
final class KeyBubble: UIView {
    private let label = UILabel()

    init() {
        super.init(frame: .zero)
        backgroundColor = KBColor.letterKey
        layer.cornerRadius = 10
        clipsToBounds = true // 保证圆角（iOS 原生气泡本身几乎无投影，不靠阴影）
        label.textAlignment = .center
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 在 source 键正上方弹出并贴住键顶（融入按键）；text 为内容，baseFontSize 为该键字号（气泡字号=+2）。
    func show(text: String, baseFontSize: CGFloat, source: UIView) {
        guard !text.isEmpty, let holder = source.superview?.superview ?? source.superview else { return }
        let h = source.bounds.height + 24
        let w = source.bounds.width + 8
        label.text = text
        label.font = .systemFont(ofSize: baseFontSize + 2)
        let origin = holder.convert(source.bounds, from: source)
        // 底边与键顶重叠 1pt，形成「融进按键」的观感（iOS 同款）
        frame = CGRect(x: origin.midX - w / 2, y: origin.minY - h + 1, width: w, height: h)
        if superview !== holder {
            removeFromSuperview()
            holder.addSubview(self)
        }
        holder.bringSubviewToFront(self)
        isHidden = false
    }

    func hide() { isHidden = true }
}

/// 中/EN 切换键（#7）：单行「中/EN」，当前语种加大加粗加黑，另一语种常规灰。#10 按下也弹气泡。
final class ModeToggleButton: UIButton {
    private let bubble = KeyBubble()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = KBColor.letterKey
        layer.cornerRadius = 6
        clipsToBounds = true
        titleLabel?.textAlignment = .center
        addTarget(self, action: #selector(showPreview), for: .touchDown)
        addTarget(self, action: #selector(hidePreview), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 按当前语种重建「中/EN」归属文本：默认同行同号，当前语种那字加大加粗加黑。
    func configure(isChinese: Bool) {
        let base: CGFloat = 12, active: CGFloat = 15
        let s = NSMutableAttributedString()
        s.append(NSAttributedString(string: "中", attributes: [
            .font: UIFont.systemFont(ofSize: isChinese ? active : base, weight: isChinese ? .bold : .regular),
            .foregroundColor: isChinese ? KBColor.activeLang : KBColor.inactiveLang]))
        s.append(NSAttributedString(string: "/", attributes: [
            .font: UIFont.systemFont(ofSize: base), .foregroundColor: KBColor.inactiveLang]))
        s.append(NSAttributedString(string: "EN", attributes: [
            .font: UIFont.systemFont(ofSize: isChinese ? base : active, weight: isChinese ? .regular : .bold),
            .foregroundColor: isChinese ? KBColor.inactiveLang : KBColor.activeLang]))
        setAttributedTitle(s, for: .normal)
    }

    @objc private func showPreview() { bubble.show(text: "中/EN", baseFontSize: 15, source: self) }
    @objc private func hidePreview() { bubble.hide() }
}

/// 带闭包的按钮（UIButton 不支持 target/action 直接闭包）。#10 按下时弹按键预览气泡。
final class ClosureButton: UIButton {
    var onTap: (() -> Void)?
    private let bubble = KeyBubble()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        addTarget(self, action: #selector(showPreview), for: .touchDown)
        addTarget(self, action: #selector(hidePreview), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleTap() { onTap?() }

    @objc private func showPreview() {
        guard let title = title(for: .normal), !title.isEmpty else { return }
        bubble.show(text: title, baseFontSize: titleLabel?.font.pointSize ?? 20, source: self)
    }

    @objc private func hidePreview() { bubble.hide() }
}

/// 上档/大写键（#4）：沿用系统原 ⇧ 图标（SF Symbol），激活变实心；**仅锁定大写**才显示下方横杠。
final class ShiftKeyButton: UIButton {
    enum ShiftState { case off, shift, caps }
    var onTap: (() -> Void)?
    var shiftState: ShiftState = .off {
        didSet { setNeedsLayout(); applyIcon() }
    }
    private let bubble = KeyBubble()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = KBColor.letterKey
        layer.cornerRadius = 6
        clipsToBounds = true
        imageView?.contentMode = .center
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        addTarget(self, action: #selector(showPreview), for: .touchDown)
        addTarget(self, action: #selector(hidePreview), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        applyIcon()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleTap() { onTap?() }
    @objc private func showPreview() { bubble.show(text: shiftState == .caps ? "⇪" : "⇧", baseFontSize: 24, source: self) }
    @objc private func hidePreview() { bubble.hide() }

    /// 原图标不变：off=空心⇧；单击激活=/实心⇧；锁定大写=capslock(实心⇧+横杠)。
    private func applyIcon() {
        let name: String
        switch shiftState {
        case .off: name = "shift"
        case .shift: name = "shift.fill"
        case .caps: name = "capslock.fill"
        }
        let cfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        setImage(UIImage(systemName: name, withConfiguration: cfg), for: .normal)
        tintColor = KBColor.keyText
    }
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
