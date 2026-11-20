import UIKit

/// 设置面板线性图标（24×24 自绘，纯黑白灰；不引 SF Symbols 资产，风格参考 Feather Icons MIT）。
/// `.sound`＝喇叭（开带双声波）；`.vibration`＝手机＋两侧锯齿（用户选款）；`.check`＝✓（完成）。
/// 关闭态叠加斜杠。`playToggleAnimation(toOn:)` 做一次性过渡（不循环：平时静止）。
final class SettingsIconView: UIView {
    enum Kind { case sound, vibration, check }

    let kind: Kind
    var isOn: Bool = true { didSet { setNeedsDisplay() } }

    init(kind: Kind) {
        self.kind = kind
        super.init(frame: .zero)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 开＝黑（深色模式白），关＝灰。
    private var strokeColor: UIColor { isOn ? .label : .systemGray }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let s = min(bounds.width, bounds.height) / 24
        ctx.translateBy(x: (bounds.width - 24 * s) / 2, y: (bounds.height - 24 * s) / 2)
        ctx.scaleBy(x: s, y: s)
        strokeColor.setStroke()

        func line(_ build: (UIBezierPath) -> Void) {
            let p = UIBezierPath()
            build(p)
            p.lineWidth = 2
            p.lineCapStyle = .round
            p.lineJoinStyle = .round
            p.stroke()
        }

        switch kind {
        case .sound: drawSound(line)
        case .vibration: drawVibration(line)
        case .check: drawCheck(line)
        }
        if !isOn && kind != .check {
            line { p in p.move(to: CGPoint(x: 3, y: 3)); p.addLine(to: CGPoint(x: 21, y: 21)) }
        }
    }

    private func drawSound(_ line: ((UIBezierPath) -> Void) -> Void) {
        line { p in
            p.move(to: CGPoint(x: 11, y: 5))
            p.addLine(to: CGPoint(x: 6, y: 9))
            p.addLine(to: CGPoint(x: 2, y: 9))
            p.addLine(to: CGPoint(x: 2, y: 15))
            p.addLine(to: CGPoint(x: 6, y: 15))
            p.addLine(to: CGPoint(x: 11, y: 19))
            p.close()
        }
        if isOn {
            line { p in p.addArc(withCenter: CGPoint(x: 11, y: 12), radius: 4.6, startAngle: -1.05, endAngle: 1.05, clockwise: true) }
            line { p in p.addArc(withCenter: CGPoint(x: 11, y: 12), radius: 8.0, startAngle: -1.05, endAngle: 1.05, clockwise: true) }
        }
    }

    private func drawVibration(_ line: ((UIBezierPath) -> Void) -> Void) {
        line { p in p.append(UIBezierPath(roundedRect: CGRect(x: 9, y: 3, width: 6, height: 18), cornerRadius: 2)) }
        line { p in p.append(UIBezierPath(ovalIn: CGRect(x: 10.7, y: 16.9, width: 2.6, height: 1.4))) }
        if isOn {
            let left = [CGPoint(x: 6.2, y: 8), CGPoint(x: 4.2, y: 10), CGPoint(x: 6.2, y: 12), CGPoint(x: 4.2, y: 14), CGPoint(x: 6.2, y: 16)]
            let right = [CGPoint(x: 17.8, y: 8), CGPoint(x: 19.8, y: 10), CGPoint(x: 17.8, y: 12), CGPoint(x: 19.8, y: 14), CGPoint(x: 17.8, y: 16)]
            for pts in [left, right] {
                line { p in
                    p.move(to: pts[0])
                    for q in pts.dropFirst() { p.addLine(to: q) }
                }
            }
        }
    }

    private func drawCheck(_ line: ((UIBezierPath) -> Void) -> Void) {
        line { p in p.append(UIBezierPath(ovalIn: CGRect(x: 2.8, y: 2.8, width: 18.4, height: 18.4))) }
        line { p in
            p.move(to: CGPoint(x: 8.2, y: 12.4))
            p.addLine(to: CGPoint(x: 10.8, y: 15))
            p.addLine(to: CGPoint(x: 15.8, y: 9.8))
        }
    }

    /// 一次性过渡动效（不循环）：开＝声音声波弹一下 / 震动抖一下；关＝缩一下。
    func playToggleAnimation(toOn: Bool) {
        if toOn {
            if kind == .vibration {
                let a = CAKeyframeAnimation(keyPath: "transform.rotation.z")
                a.values = [0, -0.10, 0.10, -0.06, 0]
                a.duration = 0.34
                layer.add(a, forKey: "shake")
            } else {
                let a = CAKeyframeAnimation(keyPath: "transform.scale")
                a.values = [0.82, 1.06, 1.0]
                a.duration = 0.30
                layer.add(a, forKey: "pop")
            }
        } else {
            let a = CAKeyframeAnimation(keyPath: "transform.scale")
            a.values = [1.0, 0.88, 1.0]
            a.duration = 0.24
            layer.add(a, forKey: "shrink")
        }
    }
}
