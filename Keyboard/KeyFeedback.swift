import UIKit

/// 按键反馈（④）：声音 B（系统键音 开/关，安全不卡）＋ 震动 4 档。
/// 键盘扩展里**禁用 AVAudioPlayer / AVAudioSession**（会卡死扩展/被 watchdog 杀）；
/// 声音改用系统 `UIDevice.current.playInputClick()`（正规 API，随系统键盘点按声与静音键，不做自定义音效）。
final class KeyFeedback {
    static let shared = KeyFeedback()

    private lazy var lightGen = UIImpactFeedbackGenerator(style: .light)
    private lazy var mediumGen = UIImpactFeedbackGenerator(style: .medium)
    private lazy var heavyGen = UIImpactFeedbackGenerator(style: .heavy)

    private init() {}

    /// 按当前设置播一次按键反馈：震动 4 档 + 声音开/关（系统键音）。
    func play() {
        let s = SettingsStore.shared()
        switch s.keyHapticLevel { // 0关1弱2中3强
        case 1: lightGen.impactOccurred(intensity: 0.4)
        case 2: mediumGen.impactOccurred(intensity: 0.7)
        case 3: heavyGen.impactOccurred(intensity: 1.0)
        default: break
        }
        if s.keySoundLevel > 0 { // 声音 B：系统键音，安全不卡；随系统「键盘点按声」与静音键
            UIDevice.current.playInputClick()
        }
    }
}
