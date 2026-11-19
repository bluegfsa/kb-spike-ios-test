import UIKit

/// 中/EN 切换键（#7）：单行「中/EN」，当前语种加大加粗加黑，另一语种常规灰。
final class ModeToggleButton: UIButton {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = KBColor.letterKey
        layer.cornerRadius = 6
        clipsToBounds = true
        titleLabel?.textAlignment = .center
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 按当前语言重建「中/英」归属文本：默认同行同号，当前语言那字加大加粗加黑。
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
}

/// 带闭包的按钮（UIButton 不支持 target/action 直接闭包）。#10 按下时弹按键预览气泡。
final class ClosureButton: UIButton {
    var onTap: (() -> Void)?
    private let keyPreview = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        addTarget(self, action: #selector(showPreview), for: .touchDown)
        addTarget(self, action: #selector(hidePreview), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        keyPreview.isHidden = true
        keyPreview.textAlignment = .center
        keyPreview.textColor = .label
        keyPreview.backgroundColor = KBColor.letterKey
        keyPreview.layer.cornerRadius = 10
        keyPreview.layer.masksToBounds = false // 允许投影；背景仍按 cornerRadius 圆角
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleTap() { onTap?() }

    @objc private func showPreview() {
        // #10 气泡放大：宽=键宽+16、高=键高+28、圆角10、字号+2、加投影；底边距键顶≥6，浮在指尖上方。
        // 挂到整块按键区容器（跨行不被别的行盖住）。
        guard let title = title(for: .normal), !title.isEmpty,
              let holder = superview?.superview ?? superview else { return }
        let h = bounds.height + 28
        let w = bounds.width + 16
        keyPreview.text = title
        keyPreview.font = .systemFont(ofSize: (titleLabel?.font.pointSize ?? 20) + 2)
        keyPreview.layer.cornerRadius = 10
        keyPreview.layer.shadowColor = UIColor.black.cgColor
        keyPreview.layer.shadowOpacity = 0.22
        keyPreview.layer.shadowRadius = 8
        keyPreview.layer.shadowOffset = CGSize(width: 0, height: 3)
        let origin = holder.convert(bounds, from: self)
        keyPreview.frame = CGRect(x: origin.midX - w / 2, y: origin.minY - h - 6, width: w, height: h)
        if keyPreview.superview !== holder {
            keyPreview.removeFromSuperview()
            holder.addSubview(keyPreview)
        }
        holder.bringSubviewToFront(keyPreview)
        keyPreview.isHidden = false
    }

    @objc private func hidePreview() { keyPreview.isHidden = true }
}

/// 上档/大写键（#4）：空心箭头↔实心箭头；锁定大写时箭头与其下方短粗横杠均为实心。
final class ShiftKeyButton: UIButton {
    enum ShiftState { case off, shift, caps }
    var onTap: (() -> Void)?
    var shiftState: ShiftState = .off { didSet { setNeedsDisplay() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = KBColor.letterKey
        layer.cornerRadius = 6
        clipsToBounds = true
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleTap() { onTap?() }

    /// 自绘 ⇧：向上箭头＋（锁定大写时）下方短粗横杠；off 空心、shift/caps 实心。
    override func draw(_ rect: CGRect) {
        let color = KBColor.keyText.resolvedColor(with: traitCollection)
        let w = rect.width, h = rect.height
        let arrowW = min(w * 0.5, 20)
        let arrowH = min(h * 0.42, 18)
        let barH = max(2.0, h * 0.055)
        let gap = max(2.0, h * 0.06)
        let startY = (h - (arrowH + gap + barH)) / 2
        let ax = (w - arrowW) / 2
        // 向上箭头轮廓（屋顶形＋竖直箭杆）
        let p = UIBezierPath()
        p.move(to: CGPoint(x: ax + arrowW * 0.5, y: startY))
        p.addLine(to: CGPoint(x: ax + arrowW, y: startY + arrowH * 0.46))
        p.addLine(to: CGPoint(x: ax + arrowW * 0.62, y: startY + arrowH * 0.46))
        p.addLine(to: CGPoint(x: ax + arrowW * 0.62, y: startY + arrowH))
        p.addLine(to: CGPoint(x: ax + arrowW * 0.38, y: startY + arrowH))
        p.addLine(to: CGPoint(x: ax + arrowW * 0.38, y: startY + arrowH * 0.46))
        p.addLine(to: CGPoint(x: ax, y: startY + arrowH * 0.46))
        p.close()
        // 下方短粗横杠（锁定大写标识）
        let barW = arrowW * 0.62
        let bar = UIBezierPath(roundedRect: CGRect(x: (w - barW) / 2, y: startY + arrowH + gap, width: barW, height: barH), cornerRadius: barH * 0.5)
        if shiftState == .off {
            color.setStroke(); p.lineWidth = 1.6; p.stroke()
            color.setStroke(); bar.lineWidth = 1.2; bar.stroke()
        } else {
            color.setFill(); p.fill()
            if shiftState == .caps { color.setFill(); bar.fill() }
            else { color.setStroke(); bar.lineWidth = 1.2; bar.stroke() }
        }
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
