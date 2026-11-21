import UIKit

/// C2 键行：外壳（真实按钮）满格相接、底色＝透明（键间缝露出与键盘上下同一系统背景）；内部圆角白卡＝键面。
/// 白卡只在「朝相邻键/相邻行」的方向外扩到缝≈1.5pt；末行不向下扩（保留 rowsBottomPad 灰缝），圆角完整不裁。
/// 外壳按切点格铺满整行（最左/最右顶到行边，行与行相接），触摸走真实按钮，不靠触摸层/判最近键。
final class C2RowView: UIView {
    struct Entry { let button: UIButton; let weight: CGFloat }
    private(set) var entries: [Entry] = []
    /// 该行 1.49 的水平键距（row1=6、row2=5、其余=6）。
    var spacing: CGFloat = 6
    /// 该行 1.49 的左右外侧留白（row1=3、row2=20、其余=0）。
    var sideInset: CGFloat = 0
    /// 该行 1.49 的可见键上/下边距（首行 6/6.5、中间 6.5/6.5、末行 6.5/4）。
    var visualTop: CGFloat = 6.5
    var visualBottom: CGFloat = 6.5
    /// 白卡是否朝本行上/下方向外扩（末行 expandsBottom=false：保留 rowsBottomPad 底部灰缝、圆角不被裁）。
    var expandsTop = true
    var expandsBottom = true
    private let cardTag = 9_001

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
        // 1) 1.49 可见键 frame（原公式；竖直方向按显式上/下边距，键高恒 41）
        let visH = max(0, H - visualTop - visualBottom)
        var vis: [CGRect] = []
        var x = sideInset
        for e in entries {
            let w = max(0, avail * e.weight / totalW)
            vis.append(CGRect(x: x, y: visualTop, width: w, height: visH))
            x += w + spacing
        }
        // 白卡放大：水平相邻缝→1.5；竖直方向——中间行沿用 1.61 的对称外扩（像素级不变），
        // 键盘首/末边距那一侧不外扩（末行不向下扩，保留 rowsBottomPad 灰缝＋完整圆角）
        let dH = max(0, (spacing - 1.5) / 2)
        let halfGap: CGFloat = 0.75
        let dVsym = max(0, ((visualTop + visualBottom) - 1.5) / 2)
        let dVUp: CGFloat
        let dVDown: CGFloat
        if expandsTop && expandsBottom {
            dVUp = dVsym; dVDown = dVsym
        } else {
            dVUp = expandsTop ? max(0, visualTop - halfGap) : 0
            dVDown = expandsBottom ? max(0, visualBottom - halfGap) : 0
        }
        for i in 0..<n {
            let v = vis[i]
            // 外壳裁到「首键左沿…末键右沿」：外圈留白（row2 两侧 20pt 等）不铺深色、露键盘底色、不可点（同 iOS/微信内缩）
            let cellL = i == 0 ? v.minX : (vis[i - 1].maxX + v.minX) / 2
            let cellR = i == n - 1 ? v.maxX : (v.maxX + vis[i + 1].minX) / 2
            let btn = entries[i].button
            btn.frame = CGRect(x: cellL, y: 0, width: max(0, cellR - cellL), height: H)
            btn.backgroundColor = .clear // 键间缝＝透明，露出与键盘上下空白同一块系统背景（不再有 209 浅灰方块）
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
                card.backgroundColor = KBColor.letterKey
                card.layer.cornerRadius = 7
                card.clipsToBounds = true
                btn.insertSubview(card, at: 0)
            }
            // 白卡：内部键缝对称放大到≈1.5；边缘键朝外留白那侧不越出键沿（外留白露键盘底、不可点）
            let cardMinX = i == 0 ? v.minX : v.minX - dH
            let cardMaxX = i == n - 1 ? v.maxX : v.maxX + dH
            let cardRect = CGRect(x: cardMinX, y: v.minY - dVUp,
                                  width: max(0, cardMaxX - cardMinX), height: visH + dVUp + dVDown)
            card.frame = CGRect(x: cardRect.minX - cellL, y: cardRect.minY,
                                width: cardRect.width, height: cardRect.height)
            // 内容中心显式钉到「可见白卡」中心（默认内容中心＝外壳整格中心，平移到白卡中心即可；边缘键不再偏）
            let cellCenterX = (cellL + cellR) / 2
            let dx = cardRect.midX - cellCenterX
            let dy = cardRect.midY - H / 2
            let insets = UIEdgeInsets(top: max(0, dy * 2), left: max(0, dx * 2),
                                      bottom: max(0, -dy * 2), right: max(0, -dx * 2))
            if let sb = btn as? ShiftKeyButton {
                // ⇧ 箭头(imageView) 与 锁定横杠(capsBar) 用同一 (dx,dy)，锁定态共竖轴
                sb.setContentOffset(dx: dx, dy: dy)
            } else if btn is ClosureButton || btn is ModeToggleButton {
                btn.titleEdgeInsets = insets
            }
        }
    }
}
