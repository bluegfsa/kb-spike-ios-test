import UIKit

/// ⚠️ 临时屏内诊断（真 B 测试包；定案出正式包前整文件删除）。
/// 三行：
///  1) KTL=(frame) sup=KeyboardView#idx tap/R/K near=… —— KTL 是否铺满键区、是否 KeyboardView 直接子视图、各层触摸计数；
///  2) KVhit=(x,y)→类名 —— 最近一次 KeyboardView.hitTest 返回谁（看缝被谁吃）；
///  3) z=… —— KeyboardView 直接子视图 z 序（类名/frame/ui），揪盖在缝上的兄弟视图。
final class KBDiagnostics {
    static let shared = KBDiagnostics()
    /// 定案出正式包前必须置 false 并删除本文件。
    static let enabled = true

    weak var label: UILabel?
    private var ktlInfo = "-"
    private var kvHitInfo = "-"
    private var zorder = "-"
    private var tapCnt = 0
    private var rootCnt = 0
    private var kvCnt = 0
    private var nearest = "-"

    func bumpKTL() { tapCnt += 1; refresh() }
    func bumpRoot() { rootCnt += 1; refresh() }
    func bumpKV() { kvCnt += 1; refresh() }
    func setNearest(_ s: String) { nearest = s; refresh() }
    func setKTLInfo(_ s: String) { ktlInfo = s; refresh() }
    func setKVHit(_ s: String) { kvHitInfo = s; refresh() }
    func setZOrder(_ s: String) { zorder = s; refresh() }

    func refresh() {
        guard Self.enabled else { return }
        let l1 = "KTL=\(ktlInfo) tap=\(tapCnt) R=\(rootCnt) K=\(kvCnt) near=\(nearest)"
        let l2 = "KVhit=\(kvHitInfo)"
        let l3 = "z=\(zorder)"
        label?.text = l1 + "\n" + l2 + "\n" + l3
    }

    // 兼容旧调用点（ClosureButton.pressDown / VC.handleKeyText 仍调用），不计数。
    func bumpPressDown() {}
    func bumpHandled() {}
}
