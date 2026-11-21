import UIKit

/// 【C2 实验·口径A】一行按键：外壳（真实按钮）满格无缝相接、底色＝不透明深分隔色；内部圆角白卡＝键面。
/// 白卡以 1.49 可见键中心为基准**对称放大**（相邻白卡≈1.5pt 缝，四角由外壳深色填满＝零透明真空）；
/// 外壳按切点格铺满整行（最左/最右顶到行边，行与行相接），触摸走真实按钮，不靠 KTL/判最近键。
final class C2RowView: UIView {
    struct Entry { let button: UIButton; let weight: CGFloat }
    private(set) var entries: [Entry] = []
    /// 该行 1.49 的水平键距（row1=6、row2=5、其余=6）。
    var spacing: CGFloat = 6
    /// 该行 1.49 的左右外侧留白（row1=3、row2=20、其余=0）。
    var sideInset: CGFloat = 0
    private let cardTag = 9_001
    /// 键高固定 41（与 1.49 一致），行内垂直居中 → 行基线不变。
    private let keyH: CGFloat = 41

    /// 外壳（分隔）色：浅 #8A8A90 / 深 #48484A，随深浅色。
    static let separator = UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark ? UIColor(hex: 0x48484A) : UIColor(hex: 0x8A8A90)
    })

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
        // 1) 1.49 可见键 frame（原公式，垂直居中 keyH=41）
        let vTop = max(0, (H - keyH) / 2)
        var vis: [CGRect] = []
        var x = sideInset
        for e in entries {
            let w = max(0, avail * e.weight / totalW)
            vis.append(CGRect(x: x, y: vTop, width: w, height: keyH))
            x += w + spacing
        }
        // 白卡相对可见键的对称放大：内部缝 → ≈1.5pt
        let dH = max(0, (spacing - 1.5) / 2)
        let dV = max(0, ((H - keyH) - 1.5) / 2)
        for i in 0..<n {
            let v = vis[i]
            let cellL = i == 0 ? 0 : (vis[i - 1].maxX + v.minX) / 2
            let cellR = i == n - 1 ? W : (v.maxX + vis[i + 1].minX) / 2
            let btn = entries[i].button
            // 外壳＝切点格（满格、与相邻相接、到行边），触摸由它接
            btn.frame = CGRect(x: cellL, y: 0, width: max(0, cellR - cellL), height: H)
            btn.backgroundColor = C2RowView.separator
            btn.layer.cornerRadius = 0
            btn.clipsToBounds = true
            btn.isUserInteractionEnabled = true
            let card: UIView
            if let ex = btn.viewWithTag(cardTag) {
                card = ex
            } else {
                card = UIView()
                card.tag = cardTag
                card.isUserInteractionEnabled = false
                card.backgroundColor = KBColor.letterKey // 键面（浅=白 / 深=键灰）
                card.layer.cornerRadius = 7
                card.clipsToBounds = true
                btn.insertSubview(card, at: 0)
            }
            let cardRect = CGRect(x: v.minX - dH, y: v.minY - dV,
                                  width: v.width + 2 * dH, height: v.height + 2 * dV)
            card.frame = CGRect(x: cardRect.minX - cellL, y: cardRect.minY,
                                width: cardRect.width, height: cardRect.height)
            // 内容（字母/中英/⇧图标）居中到白卡（=1.49 键心），而非外壳格心 → 边缘键不被外壳带偏
            let cellCenterX = (cellL + cellR) / 2
            let dx = v.midX - cellCenterX
            let dy = v.midY - H / 2
            let insets = UIEdgeInsets(top: max(0, dy * 2), left: max(0, dx * 2),
                                      bottom: max(0, -dy * 2), right: max(0, -dx * 2))
            if btn is ClosureButton || btn is ModeToggleButton {
                btn.titleEdgeInsets = insets
            } else if let sb = btn as? ShiftKeyButton {
                sb.imageEdgeInsets = insets
            }
        }
    }
}
