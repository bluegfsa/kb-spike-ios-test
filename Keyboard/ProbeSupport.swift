import UIKit

/// ⚠️ 临时探针：扩展根视图子类，仅统计 hitTest 命中次数（判断触摸有没有进扩展视图树）。
/// 正式包前随 KBDiagnostics 一并删除。
final class ProbeRootView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let v = super.hitTest(point, with: event)
        if KBDiagnostics.enabled, event != nil { KBDiagnostics.shared.bumpRoot() }
        return v
    }
}

/// 键类型（方案 B：KTL 按坐标判最近键后自行派发）。
enum KeyKind { case letter, backspace, shift, mode, space, ret, function }

/// 一次命中：kind/text/可见块(气泡锚点)/对应原按键（派发动作时用）。
struct KeyHit {
    let kind: KeyKind
    let text: String?
    let visualFrame: CGRect
    let button: UIButton?
}

protocol KeyTouchLayerDelegate: AnyObject {
    func keyTouchLayer(_ l: KeyTouchLayer, didPressAt point: CGPoint, hit: KeyHit)
    func keyTouchLayer(_ l: KeyTouchLayer, didRelease hit: KeyHit)
    func keyTouchLayer(_ l: KeyTouchLayer, didRepeat hit: KeyHit)
}

/// 方案 B：铺满整块键区的透明 UIControl，唯一触摸目标。按坐标算最近键并派发；
/// 自身 bounds 覆盖全键区（含缝隙/边距），不再依赖子视图命中链。支持多指与退格长按连删。
final class KeyTouchLayer: UIControl {
    weak var delegate: KeyTouchLayerDelegate?
    /// 统一坐标系宿主（KeyboardView）。触点与 visualFrame 都以它的坐标计算，避免与键 frame 差一个顶栏偏移。
    weak var host: UIView?
    /// 键命中清单（KeyboardView 在布局/重建键盘时刷新）。visualFrame 为 host(KeyboardView) 坐标。
    var hits: [KeyHit] = []

    private var activeHits: [UITouch: KeyHit] = [:]
    private var repeatTimers: [UITouch: Timer] = [:]
    private var repeatIntervals: [UITouch: TimeInterval] = [:]

    /// 最近键：先看落在哪个 visualFrame 内，否则取到矩形距离最小者。
    func hitTestNearest(_ p: CGPoint) -> KeyHit? {
        for h in hits where h.visualFrame.contains(p) { return h }
        var best: KeyHit?
        var bestD = CGFloat.greatestFiniteMagnitude
        for h in hits {
            let f = h.visualFrame
            let dx = max(max(f.minX - p.x, 0), p.x - f.maxX)
            let dy = max(max(f.minY - p.y, 0), p.y - f.maxY)
            let d = dx * dx + dy * dy
            if d < bestD { bestD = d; best = h }
        }
        return best
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        KBDiagnostics.shared.bumpKTL()
        for t in touches {
            let lp = t.location(in: self)
            // 触点统一转到 host(KeyboardView) 坐标，再与同样为 KeyboardView 坐标的 visualFrame 比较。
            let p = host.map { self.convert(lp, to: $0) } ?? lp
            guard let hit = hitTestNearest(p) else { continue }
            activeHits[t] = hit
            KBDiagnostics.shared.setNearest(hit.button?.title(for: .normal) ?? (hit.text ?? "?"))
            delegate?.keyTouchLayer(self, didPressAt: p, hit: hit)
            if hit.kind == .backspace { startRepeat(for: t, hit: hit) }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        end(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        end(touches)
    }

    private func end(_ touches: Set<UITouch>) {
        for t in touches {
            stopRepeat(for: t)
            if let hit = activeHits.removeValue(forKey: t) {
                delegate?.keyTouchLayer(self, didRelease: hit)
            }
        }
    }

    /// 退格长按：先等 0.4s，再 0.12 起按键盘逻辑加速连删。
    private func startRepeat(for t: UITouch, hit: KeyHit) {
        stopRepeat(for: t)
        let timer = Timer(timeInterval: 0.4, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.repeatIntervals[t] = 0.12
            self.scheduleRepeatTick(for: t, hit: hit)
        }
        RunLoop.main.add(timer, forMode: .common)
        repeatTimers[t] = timer
    }

    private func scheduleRepeatTick(for t: UITouch, hit: KeyHit) {
        guard activeHits[t] != nil else { return }
        let interval = repeatIntervals[t] ?? 0.12
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            guard let self else { return }
            guard self.activeHits[t] != nil else { return }
            self.delegate?.keyTouchLayer(self, didRepeat: hit)
            self.repeatIntervals[t] = KeyboardLogic.nextDeleteInterval(from: self.repeatIntervals[t] ?? 0.12)
            self.scheduleRepeatTick(for: t, hit: hit)
        }
        RunLoop.main.add(timer, forMode: .common)
        repeatTimers[t]?.invalidate()
        repeatTimers[t] = timer
    }

    private func stopRepeat(for t: UITouch) {
        repeatTimers[t]?.invalidate()
        repeatTimers[t] = nil
        repeatIntervals[t] = nil
    }
}
