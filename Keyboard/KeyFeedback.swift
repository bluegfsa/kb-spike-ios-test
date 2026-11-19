import UIKit
import AudioToolbox

/// 按键反馈：声音＝iOS 原生键音（`UIDevice.current.playInputClick()`，开/关）＋ 震动（`AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)`，开/关）。
/// 键盘扩展里**严禁 AVAudioPlayer / AVAudioSession**（1.28 卡死源）。
/// 1.30 的自定义合成音（S1）音色不对、音量偏大，已弃用——改回系统原生键音。
/// 震动改用系统 Vibrate ID（比 `UIImpactFeedbackGenerator` 在扩展里更可靠）；仍需系统「触感反馈」开着才会震。
/// 所有键（含删除键）都调用 `play()`；面板调「震动」只震不出声、调「声音」只出声。
final class KeyFeedback {
    static let shared = KeyFeedback()

    private init() {}

    /// 按键反馈（供所有键调用）：震动(开) + 声音(开)。
    func play() {
        playHaptic()
        playSound()
    }

    /// 只发声（面板试听声音用）：开＝系统原生键音。
    func playSound() {
        if SettingsStore.shared().keySoundLevel > 0 {
            UIDevice.current.playInputClick()
        }
    }

    /// 只震动（面板试听震动用，绝不出声）：开＝系统振动。
    func playHaptic() {
        guard SettingsStore.shared().keyHapticLevel > 0 else { return }
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
}

