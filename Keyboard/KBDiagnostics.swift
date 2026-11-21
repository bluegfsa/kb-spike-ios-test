import UIKit

/// ⚠️ 临时屏内诊断（仅「缝触摸探针包」，定位根因后整文件删除；正式包前 enabled=false 并删本文件）。
/// 探针目标：钉死"空白区触摸到底进没进扩展、进到哪一层"。全部走屏内浮层（本机取不到 os_log）：
///  - 常驻两行：ROOT.screen / KV.screen —— 根视图/键区根在 window 的覆盖矩形（不靠点击也能看）；
///  - 最近 6 条命中日志：前缀 ROOTⓘ / KVⓘ / KTL✓，同点去重（hitTest 每次移动都调，不去重会刷屏）；
///  - 一行几何：最近键＋其 visualFrame＋rowsStack/KeyboardView 的 clipsToBounds。
final class KBDiagnostics {
    static let shared = KBDiagnostics()
    /// 定案出正式包前必须置 false 并删除本文件。
    static let enabled = true

    weak var label: UILabel?

    /// 根视图在 window 的覆盖矩形（ProbeRootView.layoutSubviews 更新）。
    var rootScreen = "-"
    /// 键区根在 window 的覆盖矩形（KeyboardView.layoutSubviews 更新）。
    var kvScreen = "-"
    /// 宿主 window 原点（键盘在独立 window，有原点偏移；用于交叉核对屏幕坐标）。
    var winOrigin = "-"
    /// 最近一次 KTL 触摸处的几何摘要（KeyboardView 计算）。
    private var geometry = "-"
    /// 最近命中日志，最多 6 条。
    private var logs: [String] = []

    /// 追加一条命中日志：同点(整行相同)去重，只留最近 6 条。
    func log(_ line: String) {
        guard Self.enabled else { return }
        logs.removeAll { $0 == line } // 同点去重（含非相邻重复）
        logs.append(line)
        if logs.count > 6 { logs.removeFirst(logs.count - 6) }
        refresh()
    }

    /// 设置最近键几何摘要并刷新。
    func setGeometry(_ text: String) {
        geometry = text
        refresh()
    }

    /// 刷新浮层文本。
    func refresh() {
        guard Self.enabled else { return }
        var lines: [String] = []
        lines.append("ROOT.screen(sc)=" + rootScreen)
        lines.append("KV.screen(sc)=" + kvScreen)
        lines.append("win.origin=" + winOrigin)
        lines.append(contentsOf: logs)
        lines.append("geo=" + geometry)
        label?.text = lines.joined(separator: "\n")
    }

    // 兼容旧调用点（ClosureButton.pressDown / VC.handleKeyText 仍调用），探针阶段不计数。
    func bumpPressDown() {}
    func bumpHandled() {}
}
