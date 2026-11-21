import UIKit

/// ⚠️ 临时探针：扩展根视图子类。只覆写 hitTest 记录 `ROOTⓘ` 命中与自身 bounds 覆盖情况，
/// 用于判断"空白区触摸到底有没有进扩展视图树"（第一关）。正式包前随 KBDiagnostics 一并删除。
final class ProbeRootView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let v = super.hitTest(point, with: event)
        if KBDiagnostics.enabled, event != nil {
            let cls = v.map { String(describing: type(of: $0)) } ?? "nil"
            let inB = bounds.contains(point) ? 1 : 0
            KBDiagnostics.shared.log(String(
                format: "ROOTⓘ(%.0f,%.0f)→%@ b=(%.0f,%.0f,%.0f,%.0f) in=%d",
                point.x, point.y, cls,
                bounds.minX, bounds.minY, bounds.width, bounds.height, inB))
        }
        return v
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard KBDiagnostics.enabled, let win = window else { return }
        let r = convert(bounds, to: win)
        KBDiagnostics.shared.rootScreen = String(
            format: "(%.0f,%.0f,%.0f,%.0f)", r.minX, r.minY, r.width, r.height)
        KBDiagnostics.shared.refresh()
    }
}

/// ⚠️ 临时探针：铺满整块键区的透明 UIControl（最上层）。探针阶段只记录 `KTL✓(x,y)`、**不上字**。
/// 若"缝点"能到这里，说明整块键区放一个自身覆盖全区的控件即可接管空白触摸（方案 B 成立）。
final class KeyTouchLayer: UIControl {
    /// 触摸开始回调（探针：仅上报坐标，由 KeyboardView 计算最近键几何）。
    var onBegan: ((CGPoint) -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let t = touches.first else { return }
        let p = t.location(in: self)
        KBDiagnostics.shared.log(String(format: "KTL✓(%.0f,%.0f)", p.x, p.y))
        onBegan?(p)
    }
}
