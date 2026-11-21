import UIKit

/// ⚠️ 临时屏内诊断（仅测试取证包，定位「点键缝为何不上字」后必须整文件删除；正式包前 enabled=false 并删本文件）。
/// 点一下键盘，底部浮层显示：
///  tap(x,y) / hitTest 命中类名 + superview 链 / 命中视图 isUserInteractionEnabled·hidden·alpha·frame /
///  纯几何(是否在键区、是否在某键内、最近键与距离) / 计数(pressDown 触发数、handleKeyText 处理数) /
///  点上方直接子视图 z 序(带交互属性) / 最近键可见 frame / 键区 frame。
final class KBDiagnostics {
    static let shared = KBDiagnostics()
    /// 定案出正式包前必须置 false 并删除本文件。
    static let enabled = true

    /// UIControl .touchDown 触发次数（ClosureButton.pressDown 里累加）。
    private(set) var pressDownCount = 0
    /// 按键上字链路被处理次数（KeyboardViewController.handleKeyText 里累加）。
    private(set) var handledCount = 0

    weak var hitView: UIView?
    var hitClassName = "-"
    var lastPoint: CGPoint = .zero
    weak var label: UILabel?

    func bumpPressDown() { pressDownCount += 1 }
    func bumpHandled() { handledCount += 1 }

    /// 刷新浮层文本；extra 为几何/遮挡等附加行。
    func report(extra: [String]) {
        guard Self.enabled else { return }
        var lines: [String] = []
        lines.append(String(format: "tap(%.0f,%.0f) hit=%@", lastPoint.x, lastPoint.y, hitClassName))
        // superview 链
        var chain: [String] = []
        var v = hitView
        while let cur = v {
            chain.append(String(describing: type(of: cur)))
            if cur is UIWindow { break }
            v = cur.superview
        }
        lines.append("chain=" + (chain.isEmpty ? "-" : chain.joined(separator: ">")))
        if let hv = hitView, let win = hv.window {
            let f = hv.convert(hv.bounds, to: win)
            lines.append(String(format: "hit.ui=%d hid=%d a=%.2f f=(%.0f,%.0f,%.0f,%.0f)",
                                hv.isUserInteractionEnabled ? 1 : 0, hv.isHidden ? 1 : 0, hv.alpha,
                                f.origin.x, f.origin.y, f.size.width, f.size.height))
        } else {
            lines.append("hit.ui=? (no view/window)")
        }
        lines.append("cnt: down=\(pressDownCount) handled=\(handledCount)")
        lines.append(contentsOf: extra)
        label?.text = lines.joined(separator: "\n")
    }
}
