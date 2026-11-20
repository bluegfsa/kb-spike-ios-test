import UIKit
import AudioToolbox

/// 按键反馈：声音＝系统键盘点按声 `AudioServicesPlaySystemSound(1104)`（开/关）＋ 震动＝`UIImpactFeedbackGenerator(.light)` 轻点短震（开/关）。
/// 键盘扩展里**严禁 AVAudioPlayer / AVAudioSession**（1.28 卡死源）。
/// 声音不再依赖 `playInputClick()`/`UIInputViewAudioFeedback`（扩展里常不稳、1.31 实测没声），改播 Apple 系统键音 1104，扩展能响、无需音频会话。
/// 震动不用 `kSystemSoundID_Vibrate`（整机长震「嗡」一下，用户嫌太长），用 UIImpact 轻点短震（与 iOS 原生键盘一致）。
/// 所有键（含删除键）都调用 `play()`；面板调「震动」只震不出声、调「声音」只出声。
final class KeyFeedback {
    static let shared = KeyFeedback()

    private lazy var hapticGen = UIImpactFeedbackGenerator(style: .light)

    private init() {}

    /// 按键反馈（供所有键调用）：震动(开) + 声音(开)。
    func play() {
        playHaptic()
        playSound()
    }

    /// 只发声（面板试听声音用）：开＝系统键盘点按声 1104。
    func playSound() {
        if SettingsStore.shared().keySoundLevel > 0 {
            AudioServicesPlaySystemSound(1104) // Apple 系统键音（Tock），扩展可靠、无音频会话
        }
    }

    /// 只震动（面板试听震动用，绝不出声）：开＝一次轻点短震。
    func playHaptic() {
        guard SettingsStore.shared().keyHapticLevel > 0 else { return }
        hapticGen.prepare()
        hapticGen.impactOccurred() // 轻点短震（不是 kSystemSoundID_Vibrate 长震）
    }
}
