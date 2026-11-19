import UIKit

/// 按键反馈：声音＝iOS 原生键音（`UIDevice.current.playInputClick()`，开/关）＋ 震动（`UIImpactFeedbackGenerator`，开/关）。
/// 键盘扩展里**严禁 AVAudioPlayer / AVAudioSession**（1.28 卡死源）。
/// 1.30 试过的自定义合成音（S1）音色不对、音量偏大，已弃用——改回系统原生键音。
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

    /// 只发声（面板试听声音用）：开＝系统原生键音。
    func playSound() {
        if SettingsStore.shared().keySoundLevel > 0 {
            UIDevice.current.playInputClick()
        }
    }

    /// 只震动（面板试听震动用，绝不出声）：开＝一次 light impact。
    func playHaptic() {
        guard SettingsStore.shared().keyHapticLevel > 0 else { return }
        hapticGen.prepare()
        hapticGen.impactOccurred()
    }
}
