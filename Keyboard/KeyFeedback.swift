import UIKit
import AudioToolbox
import CoreHaptics

/// 按键反馈：**仅震动、不发声**（用户 2026-11-23 要求：键盘声音全去掉、只留震动）。
/// · 震动：优先 **CoreHaptics 瞬态**（intensity 0.1 / sharpness 0.4，轻）；engine 建不起来/播放失败则兜底
///   `AudioServicesPlaySystemSound(1519)`（**本机已验证能震**；正式版移除私有 ID 换合规降级）。engine 后台起，绝不阻塞主线程。
/// 普通键调 `play()`，删除键（含长按连发）调 `playDelete()`——两者都**只震动、不出声**。
final class KeyFeedback {
    static let shared = KeyFeedback()

    private var hapticEngine: CHHapticEngine?

    private init() { setupHaptics() }

    deinit { hapticEngine?.stop(completionHandler: nil) }

    /// 后台建 CoreHaptics 引擎（不阻塞主线程；失败静默，playHaptic 自动兜底 1519）。
    private func setupHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let engine = try CHHapticEngine()
                engine.playsHapticsOnly = true
                engine.stoppedHandler = { [weak self] _ in self?.hapticEngine = nil }
                engine.resetHandler = { [weak self] in try? self?.hapticEngine?.start() }
                try engine.start()
                DispatchQueue.main.async { self?.hapticEngine = engine }
            } catch {
                // 保持 nil → playHaptic 走 1519 兜底
            }
        }
    }

    /// 普通键反馈：只震动（不发声）。
    func play() { playHaptic() }

    /// 删除键反馈（含长按连发）：只震动（不发声）。
    func playDelete() { playHaptic() }

    /// 只震动：开＝CoreHaptics 瞬态(0.1/0.4，更轻)；失败兜底 1519（本机能震）。
    func playHaptic() {
        guard SettingsStore.shared().keyHapticLevel > 0 else { return }
        if let engine = hapticEngine {
            do {
                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.1)
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
                let pattern = try CHHapticPattern(events: [event], parameters: [])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: 0)
                return
            } catch {
                // 落到下面的 1519 兜底
            }
        }
        AudioServicesPlaySystemSound(1519) // 兜底：本机验证能震；正式版移除私有 ID
    }
}
