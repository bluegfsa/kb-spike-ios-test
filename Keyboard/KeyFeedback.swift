import UIKit
import AudioToolbox
import CoreHaptics

/// 按键反馈（1.38）：
/// · 声音：启动时用 `AudioServicesCreateSystemSoundID` 各注册一次普通键音 `1_normal.wav`、删除键音 `2_delete.wav`；
///   按键只 `AudioServicesPlaySystemSound(id)`。**严禁 1104 / playInputClick / AVAudioSession / AVAudioPlayer / 每键新建**。
/// · 震动：优先 **CoreHaptics 瞬态**（intensity 0.3 / sharpness 0.5，很短），引擎建不起来或播放失败则兜底 `UIImpact(.light)`。
///   **不再用私有 ID 1519**。仍需系统「触感反馈」开启、非低电量模式。
/// 普通键调 `play()`，删除键（含长按连发）调 `playDelete()`（独立、与普通键不同但相似）。
final class KeyFeedback {
    static let shared = KeyFeedback()

    private var normalID: SystemSoundID = 0
    private var deleteID: SystemSoundID = 0
    private var hapticEngine: CHHapticEngine?
    private lazy var impactGen = UIImpactFeedbackGenerator(style: .light)

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

    /// 建 CoreHaptics 引擎（失败静默兜底到 UIImpact）。
    private func setupHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            engine.playsHapticsOnly = true
            engine.stoppedHandler = { [weak self] _ in self?.hapticEngine = nil }
            engine.resetHandler = { [weak self] in try? self?.hapticEngine?.start() }
            try engine.start()
            hapticEngine = engine
        } catch {
            hapticEngine = nil
        }
    }

    /// 普通键反馈：短震 + 普通键音。
    func play() { playHaptic(); playSound() }

    /// 删除键反馈（含长按连发）：短震 + 删除键独立音。
    func playDelete() { playHaptic(); playSoundID(deleteID) }

    /// 只发普通键音（面板试听声音用）。
    func playSound() { playSoundID(normalID) }

    /// 只震动（面板试听震动用，绝不出声）：开＝CoreHaptics 瞬态(0.3/0.5)；失败兜底 UIImpact(.light)。
    func playHaptic() {
        guard SettingsStore.shared().keyHapticLevel > 0 else { return }
        if let engine = hapticEngine {
            do {
                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3)
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
                let pattern = try CHHapticPattern(events: [event], parameters: [])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: 0)
                return
            } catch {
                // 落到下面的兜底
            }
        }
        impactGen.prepare()
        impactGen.impactOccurred()
    }

    private func playSoundID(_ id: SystemSoundID) {
        guard SettingsStore.shared().keySoundLevel > 0, id != 0 else { return }
        AudioServicesPlaySystemSound(id)
    }
}
