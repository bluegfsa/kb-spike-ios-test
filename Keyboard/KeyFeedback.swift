import UIKit
import AudioToolbox
import CoreHaptics

/// 按键反馈（1.38）：
/// · 声音：启动时用 `AudioServicesCreateSystemSoundID` 各注册一次普通键音 `1_normal.wav`、删除键音 `2_delete.wav`；
///   按键只 `AudioServicesPlaySystemSound(id)`。**严禁 1104 / playInputClick / AVAudioSession / AVAudioPlayer / 每键新建**。
/// · 震动：优先 **CoreHaptics 瞬态**（intensity 0.3 / sharpness 0.5，可调更轻）；engine 建不起来/播放失败则兜底
///   `AudioServicesPlaySystemSound(1519)`（**本机已验证能震**；UIImpact/UISelection 本机不响，故不作兜底）。1519 为私有 ID，
///   仅测试期兜底用，正式版移除（换合规短震或如实降级）。engine 后台起，绝不阻塞主线程。
/// 普通键调 `play()`，删除键（含长按连发）调 `playDelete()`（独立、与普通键不同但相似）。
final class KeyFeedback {
    static let shared = KeyFeedback()

    private var normalID: SystemSoundID = 0
    private var deleteID: SystemSoundID = 0
    private var hapticEngine: CHHapticEngine?

    private init() {
        normalID = Self.registerSound("1_normal")
        deleteID = Self.registerSound("2_delete")
        setupHaptics()
    }

    deinit {
        if normalID != 0 { AudioServicesDisposeSystemSoundID(normalID) }
        if deleteID != 0 { AudioServicesDisposeSystemSoundID(deleteID) }
        hapticEngine?.stop(completionHandler: nil)
    }

    /// 从扩展 bundle 读取 wav 并注册为系统声音 ID；失败返回 0（静默不播）。
    private static func registerSound(_ name: String) -> SystemSoundID {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return 0 }
        var id: SystemSoundID = 0
        if AudioServicesCreateSystemSoundID(url as CFURL, &id) == kAudioServicesNoError { return id }
        return 0
    }

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

    /// 普通键反馈：短震 + 普通键音。
    func play() { playHaptic(); playSound() }

    /// 删除键反馈（含长按连发）：短震 + 删除键独立音。
    func playDelete() { playHaptic(); playSoundID(deleteID) }

    /// 只发普通键音（面板试听声音用）。
    func playSound() { playSoundID(normalID) }

    /// 只震动（面板试听震动用，绝不出声）：开＝CoreHaptics 瞬态(0.1/0.4，更轻)；失败兜底 1519（本机能震）。
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

    private func playSoundID(_ id: SystemSoundID) {
        guard SettingsStore.shared().keySoundLevel > 0, id != 0 else { return }
        AudioServicesPlaySystemSound(id)
    }
}
