import UIKit

/// 方案 A′：一行按键＝若干「切点格」。
/// 复用原按键对象（不新建、不转发事件），把每个按键对象的 frame 扩成「整格」——相邻键可见边缘的
/// 中点做切点、两端格顶到行左右边、含上下行距——于是整个键区每个点都落在某个真实按键的 bounds 内，
/// 原生 `.touchDown` 必触发（长按删/气泡/多指天然保留）。可见键块由按键内部一个「内缩的视觉子视图」画出，
/// 内缩量＝实测可见 frame 与该格的差 → 视觉键位逐像素不变。
final class CellRowView: UIView {
    struct Entry { let button: UIButton; let weight: CGFloat }
    private(set) var entries: [Entry] = []
    var spacing: CGFloat = 6
    var sideInset: CGFloat = 0
    var visualTop: CGFloat = 6.5
    var visualBottom: CGFloat = 6.5
    private let bgTag = 9_001

    /// 加入一个按键（weight 用于功能行 ⇧/⌫=1.15× 等相对宽）。
    func addKey(_ button: UIButton, weight: CGFloat = 1) {
        entries.append(Entry(button: button, weight: weight))
        addSubview(button)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let n = entries.count
        guard n > 0 else { return }
        let W = bounds.width, H = bounds.height
        let totalW = entries.reduce(CGFloat(0)) { $0 + $1.weight }
        let avail = W - 2 * sideInset - CGFloat(n - 1) * spacing
        // 1) 先算每键「可见 frame」（与原 stack 布局同公式）
        var vis: [CGRect] = []
        var x = sideInset
        for e in entries {
            let w = max(0, avail * e.weight / totalW)
            vis.append(CGRect(x: x, y: visualTop, width: w, height: max(0, H - visualTop - visualBottom)))
            x += w + spacing
        }
        // 2) 切点格：两端顶到行边、内部取相邻可见边缘中点；键对象 frame＝格，视觉子视图=可见 frame
        for i in 0..<n {
            let v = vis[i]
            let cellL = i == 0 ? 0 : (vis[i - 1].maxX + v.minX) / 2
            let cellR = i == n - 1 ? W : (v.maxX + vis[i + 1].minX) / 2
            let btn = entries[i].button
            btn.frame = CGRect(x: cellL, y: 0, width: max(0, cellR - cellL), height: H)
            btn.backgroundColor = .clear
            btn.clipsToBounds = false
            let bg: UIView
            if let existing = btn.viewWithTag(bgTag) {
                bg = existing
            } else {
                bg = UIView()
                bg.tag = bgTag
                bg.isUserInteractionEnabled = false
                bg.backgroundColor = KBColor.letterKey
                bg.layer.cornerRadius = 6
                bg.clipsToBounds = true
                btn.insertSubview(bg, at: 0)
            }
            bg.frame = CGRect(x: v.minX - cellL, y: v.minY, width: v.width, height: v.height)
            // 把内容（字母/中英/⇧图标）重新居中到“可见键块”，并把 ⇧ 锁定横杠锚回键块底（A′ 按钮＝整格）
            let dx = v.midX - (cellL + cellR) / 2
            let dy = v.midY - H / 2
            let insets = UIEdgeInsets(top: max(0, dy * 2), left: max(0, dx * 2), bottom: max(0, -dy * 2), right: max(0, -dx * 2))
            if btn is ClosureButton || btn is ModeToggleButton {
                btn.titleEdgeInsets = insets
            } else if let sb = btn as? ShiftKeyButton {
                sb.applyCellInsets(visualBottom: visualBottom)
                sb.imageEdgeInsets = insets
            }
        }
    }
}
