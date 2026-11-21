import UIKit

/// 按键预览气泡（#10）：圆角、融进按键，参考 iOS 原生——底边贴键顶无缝隙、圆角 7、键色、只加轻阴影。
/// 挂到整块按键区容器（跨行不被别的行盖住）。字母/功能/上档/中英键共用这一份实现。
final class KeyBubble: UIView {
    /// 全局单个气泡实例（所有键共用）：避免每个键各挂一个到顶层造成残留/「首按能显示、再按不显示」。
    static let shared = KeyBubble()

    private let bg = UIView()
    private let label = UILabel()
    /// 当前气泡所属键：旧键 touchUp 不得隐藏新键气泡（共享单实例跨键竞态根治）。
    private weak var owner: UIView?
    /// 待执行的自动隐藏（可被新一次 show 取消）。
    private var hideWork: DispatchWorkItem?
    /// 本次显示时刻，用于计算最短可见。
    private var shownAt: CFTimeInterval = 0
    /// 最短可见 ≥120ms：保证快按时至少渲染 1–2 帧；长按按住时不受影响（touchUp 才触发 hide）。
    private let minVisible: CFTimeInterval = 0.12

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false // #BUG-2：气泡只做显示，绝不抢邻键触摸
        backgroundColor = .clear
        // 轻阴影挂在最外层容器（圆角由里层 bg 裁剪保证，两者互不影响）
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 1)
        bg.backgroundColor = KBColor.letterKey
        bg.layer.cornerRadius = 8
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

    /// 在「可见键块」正上方弹出，底边贴住键块顶；text 为内容，baseFontSize 为该键字号（气泡字号=+11）。
    /// A′ 下按钮＝整格，故按传入的 visibleRect（按键坐标系里的可见键块）算气泡宽/位置，不能用按钮 bounds。
    func show(text: String, baseFontSize: CGFloat, source: UIView, visibleRect: CGRect) {
        guard !text.isEmpty else { return }
        hideWork?.cancel()
        hideWork = nil
        var top: UIView = source
        while let sup = top.superview { top = sup }
        let holder = top
        source.layoutIfNeeded()
        holder.layoutIfNeeded()
        let h: CGFloat = 46
        let w = visibleRect.width + 12
        label.text = text
        label.font = .systemFont(ofSize: baseFontSize + 11)
        let origin = holder.convert(visibleRect, from: source)
        // x 夹取在容器内：边缘键（q/p 等最左最右列）气泡不越出键盘被裁，向内收（iOS 同款）。
        let maxX = max(0, holder.bounds.width - w)
        let x = min(max(0, origin.midX - w / 2), maxX)
        // y 夹取 ≥0：气泡不超出键盘上边界（顶排只显示一半的根因）。
        let y = max(0, origin.minY - h)
        // 全局单实例：只首次挂到顶层容器，之后只更新位置/状态，不再反复 remove/重挂（避免孤儿/抢层级）。
        if superview !== holder {
            removeFromSuperview()
            holder.addSubview(self)
        }
        owner = source // 记录当前所属键
        alpha = 1
        layer.zPosition = 999 // 最高层级，盖过候选栏/顶栏
        frame = CGRect(x: x, y: y, width: w, height: h)
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 8).cgPath
        holder.bringSubviewToFront(self)
        isHidden = false
        shownAt = CACurrentMediaTime() // 记录显示时刻，供最短可见计算
    }

    /// 仅当当前气泡属于 source 时才隐藏（旧键 touchUp 绝不能隐藏新键气泡）；
    /// 且保证最短可见（≥minVisible），避免快按时 show→hide 落在同一帧、屏幕还没画就隐藏 → “时不时不显示”。
    func hide(ifOwner source: UIView) {
        guard owner === source else { return }
        let elapsed = CACurrentMediaTime() - shownAt
        let delay = max(0, minVisible - elapsed)
        hideWork?.cancel()
        if delay <= 0 {
            performHide()
        } else {
            let work = DispatchWorkItem { [weak self] in self?.performHide() }
            hideWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    }

    private func performHide() {
        isHidden = true
        owner = nil
        hideWork = nil
    }
}

/// 中/EN 切换键（#7）：单行「中/EN」，当前语种放大变黑、另一语种常规灰（均 Regular）。功能键不弹气泡。
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

    /// 按当前语种重建「中/EN」归属文本：默认同行同号，当前语种那字加大加粗加黑。
    func configure(isChinese: Bool) {
        let base: CGFloat = 12, active: CGFloat = 17
        let s = NSMutableAttributedString()
        s.append(NSAttributedString(string: "中", attributes: [
            .font: UIFont.systemFont(ofSize: isChinese ? active : base, weight: .regular),
            .foregroundColor: isChinese ? KBColor.activeLang : KBColor.inactiveLang]))
        s.append(NSAttributedString(string: "/", attributes: [
            .font: UIFont.systemFont(ofSize: base), .foregroundColor: KBColor.inactiveLang]))
        s.append(NSAttributedString(string: "EN", attributes: [
            .font: UIFont.systemFont(ofSize: isChinese ? base : active, weight: .regular),
            .foregroundColor: isChinese ? KBColor.inactiveLang : KBColor.activeLang]))
        setAttributedTitle(s, for: .normal)
    }
}

/// 带闭包的按钮（UIButton 不支持 target/action 直接闭包）。#10 按下弹按键预览气泡（仅字母键）。
/// 交互：**按下即上字**（.touchDown 立即触发 onTap，不等抬手；多指各自立即上屏，不排队）；
/// 气泡/声音震动等装饰在输入之后执行、绝不挡在上字前；可点热区可左右外扩半缝拼满无缝。
final class ClosureButton: UIButton {
    var onTap: (() -> Void)?
    /// 仅字母键=true 弹气泡；功能键(123/空格/中EN/发送/⌫/⇧/符号)为 false，不弹。
    var showsBubble = false
    /// true=按下即触发 onTap（上字）；false=交给外部手势处理（如删除键）
    var pressInserts = true
    /// 是否自动播按键音/震动（删除键用独立音，置 false 避免重复）
    var autoFeedback = true

    override init(frame: CGRect) {
        super.init(frame: frame)
        isExclusiveTouch = false // 多指同按不同键时互不排斥
        addTarget(self, action: #selector(pressDown), for: .touchDown)
        addTarget(self, action: #selector(releaseUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 按下即上字：先执行输入（最要紧、立即），再做气泡/声音装饰——装饰绝不挡在上字前面。
    @objc private func pressDown() {
        KBDiagnostics.shared.bumpPressDown() // ⚠️ 临时诊断（测试包）
        if pressInserts { onTap?() }
        if showsBubble { showPreview() }
        if autoFeedback { KeyFeedback.shared.play() }
    }

    /// 抬手/滑出/取消：只收气泡（上字已在按下时完成，不受抬手时机影响，故快打/两指/滑出不漏字）。
    @objc private func releaseUp() { hidePreview() }

    @objc private func showPreview() {
        guard showsBubble, let title = title(for: .normal), !title.isEmpty else { return }
        let vis = self.viewWithTag(9001)?.frame ?? bounds // A′：用可见键块而不是整格
        KeyBubble.shared.show(text: title, baseFontSize: titleLabel?.font.pointSize ?? 20, source: self, visibleRect: vis)
    }

    @objc private func hidePreview() { KeyBubble.shared.hide(ifOwner: self) }
}

/// 横向可点热区可外扩的容器（候选词条用）：左右各扩半缝拼满无缝；
/// 候选条靠 ScrollView 的 pan 取消 tap（delaysContentTouches=false/canCancelContentTouches=true），不吞横向滑动。
final class HitExpandView: UIView {
    var hitExpandX: CGFloat = 0
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if bounds.contains(point) { return true }
        guard hitExpandX > 0 else { return false }
        return bounds.insetBy(dx: -hitExpandX, dy: 0).contains(point)
    }
}

/// 上档/大写键（#4）：箭头形状全程不变——off=空心 `shift`，激活=实心 `shift.fill`；
/// **仅锁定大写**时在箭头下方自绘一根实心短粗横杠（绝不换成 capslock 图标，避免“换了图标”）。
final class ShiftKeyButton: UIButton {
    enum ShiftState { case off, shift, caps }
    var onTap: (() -> Void)?
    var shiftState: ShiftState = .off { didSet { applyIcon() } }
    private let capsBar = UIView()
    private var capsBottom: NSLayoutConstraint?

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
        let cb = capsBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        capsBottom = cb
        NSLayoutConstraint.activate([
            capsBar.centerXAnchor.constraint(equalTo: centerXAnchor),
            cb,
            capsBar.widthAnchor.constraint(equalToConstant: 12),
            capsBar.heightAnchor.constraint(equalToConstant: 3),
        ])
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        applyIcon()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// A′：把锁定横杠锚回“可见键块”底部（键块底 -8），避免按钮外扩成格后横杠掉进缝里。
    func applyCellInsets(visualBottom: CGFloat) {
        capsBottom?.constant = -(visualBottom + 8)
    }

    @objc private func handleTap() { KeyFeedback.shared.play(); onTap?() }

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
