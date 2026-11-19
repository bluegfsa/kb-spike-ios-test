import UIKit

/// 按键预览气泡（#10）：圆角、融进按键，参考 iOS 原生——底边贴键顶无缝隙、圆角 7、键色、只加轻阴影。
/// 挂到整块按键区容器（跨行不被别的行盖住）。字母/功能/上档/中英键共用这一份实现。
final class KeyBubble: UIView {
    private let bg = UIView()
    private let label = UILabel()

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        // 轻阴影挂在最外层容器（圆角由里层 bg 裁剪保证，两者互不影响）
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 1)
        bg.backgroundColor = KBColor.letterKey
        bg.layer.cornerRadius = 7
        bg.clipsToBounds = true
        bg.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bg)
        label.textAlignment = .center
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(label)
        NSLayoutConstraint.activate([
            bg.leadingAnchor.constraint(equalTo: leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: trailingAnchor),
            bg.topAnchor.constraint(equalTo: topAnchor),
            bg.bottomAnchor.constraint(equalTo: bottomAnchor),
            label.centerXAnchor.constraint(equalTo: bg.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: bg.centerYAnchor),
        ])
        isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 在 source 键正上方弹出，底边贴住键顶（融入按键）；text 为内容，baseFontSize 为该键字号（气泡字号=+2）。
    func show(text: String, baseFontSize: CGFloat, source: UIView) {
        guard !text.isEmpty, let holder = source.superview?.superview ?? source.superview else { return }
        let h = source.bounds.height + 28
        let w = source.bounds.width + 16
        label.text = text
        label.font = .systemFont(ofSize: baseFontSize + 2)
        let origin = holder.convert(source.bounds, from: source)
        // 底边正好落在键顶（无缝隙，iOS 同款「融入按键」）
        frame = CGRect(x: origin.midX - w / 2, y: origin.minY - h, width: w, height: h)
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 7).cgPath
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

/// 上档/大写键（#4）：箭头形状全程不变——off=空心 `shift`，激活=实心 `shift.fill`；
/// **仅锁定大写**时在箭头下方自绘一根实心短粗横杠（绝不换成 capslock 图标，避免“换了图标”）。
final class ShiftKeyButton: UIButton {
    enum ShiftState { case off, shift, caps }
    var onTap: (() -> Void)?
    var shiftState: ShiftState = .off { didSet { applyIcon() } }
    private let bubble = KeyBubble()
    private let capsBar = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = KBColor.letterKey
        layer.cornerRadius = 6
        clipsToBounds = true
        imageView?.contentMode = .center
        capsBar.backgroundColor = KBColor.keyText
        capsBar.layer.cornerRadius = 1.5
        capsBar.isHidden = true
        capsBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(capsBar)
        NSLayoutConstraint.activate([
            capsBar.centerXAnchor.constraint(equalTo: centerXAnchor),
            capsBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            capsBar.widthAnchor.constraint(equalToConstant: 12),
            capsBar.heightAnchor.constraint(equalToConstant: 3),
        ])
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

    /// 箭头：off 空心 shift、激活/锁定均是实心 shift.fill（同款箭头）；横杠只在锁定大写出现。
    private func applyIcon() {
        let name = (shiftState == .off) ? "shift" : "shift.fill"
        let cfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        setImage(UIImage(systemName: name, withConfiguration: cfg), for: .normal)
        tintColor = KBColor.keyText
        capsBar.isHidden = (shiftState != .caps)
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
