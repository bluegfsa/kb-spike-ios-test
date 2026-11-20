import UIKit
import AudioToolbox

/// 按键反馈（1.35）：
/// · 声音：启动时用 `AudioServicesCreateSystemSoundID` 各注册一次普通键音 `1_normal.wav`、删除键音 `2_delete.wav`；
///   按键只 `AudioServicesPlaySystemSound(id)`。**严禁 1104 / playInputClick / AVAudioSession / AVAudioPlayer / 每键新建**。
/// · 震动：`UISelectionFeedbackGenerator`（轻点短震，不需「完全访问」）。仍需系统「触感反馈」开启、非低电量模式。
/// 普通键调 `play()`，删除键（含长按连发）调 `playDelete()`（独立、与普通键不同但相似）。
final class KeyFeedback {
    static let shared = KeyFeedback()

    private var normalID: SystemSoundID = 0
    private var deleteID: SystemSoundID = 0
    private lazy var selectionGen = UISelectionFeedbackGenerator()

    private init() {
        normalID = Self.registerSound("1_normal")
        deleteID = Self.registerSound("2_delete")
    }

    deinit {
        if normalID != 0 { AudioServicesDisposeSystemSoundID(normalID) }
        if deleteID != 0 { AudioServicesDisposeSystemSoundID(deleteID) }
    }

    /// 从扩展 bundle 读取 wav 并注册为系统声音 ID；失败返回 0（静默不播）。
    private static func registerSound(_ name: String) -> SystemSoundID {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return 0 }
        var id: SystemSoundID = 0
        if AudioServicesCreateSystemSoundID(url as CFURL, &id) == kAudioServicesNoError { return id }
        return 0
    }

    /// 普通键反馈：短震 + 普通键音。
    func play() { playHaptic(); playSound() }

    /// 删除键反馈（含长按连发）：短震 + 删除键独立音。
    func playDelete() { playHaptic(); playSoundID(deleteID) }

    /// 只发普通键音（面板试听声音用）。
    func playSound() { playSoundID(normalID) }

    /// 只震动（面板试听震动用，绝不出声）：开＝一次轻点短震（UISelection，不需完全访问）。
    func playHaptic() {
        guard SettingsStore.shared().keyHapticLevel > 0 else { return }
        selectionGen.prepare()
        selectionGen.selectionChanged()
    }

    private func playSoundID(_ id: SystemSoundID) {
        guard SettingsStore.shared().keySoundLevel > 0, id != 0 else { return }
        AudioServicesPlaySystemSound(id)
    }
}
