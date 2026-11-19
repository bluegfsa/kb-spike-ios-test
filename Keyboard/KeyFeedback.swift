import UIKit
import AVFoundation

/// 按键反馈（④）：声音 4 档 + 震动 4 档。
/// 声音＝代码合成的极短 click（WAV Data → AVAudioPlayer，单个复用）。
/// 关键：音频全部丢到后台串行队列，**绝不阻塞主线程**；复用同一个 player（不每键 new / 不每键解码）；
/// 任何一步失败就永久关闭声音（失败兜底），避免卡死扩展。
final class KeyFeedback {
    static let shared = KeyFeedback()

    private let queue = DispatchQueue(label: "kb.keyfeedback", qos: .userInitiated)
    private var player: AVAudioPlayer?
    private var prepared = false
    private var soundDisabled = false

    private lazy var lightGen = UIImpactFeedbackGenerator(style: .light)
    private lazy var mediumGen = UIImpactFeedbackGenerator(style: .medium)
    private lazy var heavyGen = UIImpactFeedbackGenerator(style: .heavy)

    private init() {
        // 预生成 click 数据（纯内存计算，开销极小），音频初始化留到后台首次播放时做。
        _ = Self.makeClickWAV()
    }

    /// 按当前设置播一次按键反馈。主线程只做轻量震动 + 把声音投递到后台队列。
    func play() {
        let s = SettingsStore.shared()
        switch s.keyHapticLevel { // 0关1弱2中3强
        case 1: lightGen.impactOccurred(intensity: 0.4)
        case 2: mediumGen.impactOccurred(intensity: 0.7)
        case 3: heavyGen.impactOccurred(intensity: 1.0)
        default: break
        }
        let level = s.keySoundLevel
        guard level > 0, !soundDisabled else { return } // 0关 / 已兜底禁用
        queue.async { [weak self] in self?.playSound(level: level) }
    }

    /// 后台队列：首次惰性建 session/player，之后复用，音量按档位。
    private func playSound(level: Int) {
        if !prepared {
            prepared = true
            // 不在扩展里 setActive/切 category（最易卡死）；直接建单个 player，出声与否都能兜底为静音，不阻塞。
            guard let data = Self.makeClickWAV(), let p = try? AVAudioPlayer(data: data) else {
                soundDisabled = true
                return
            }
            p.prepareToPlay()
            player = p
        }
        guard let player = player else { soundDisabled = true; return }
        let volumes: [Float] = [0, 0.33, 0.66, 1.0] // 关/小/中/大
        player.volume = volumes[max(0, min(3, level))]
        player.currentTime = 0
        player.play()
    }

    /// 合成 15ms 指数衰减正弦 click（16-bit PCM WAV），约 1KB。
    private static func makeClickWAV() -> Data? {
        let sampleRate = 44100
        let duration = 0.015
        let freq = 1000.0
        let n = Int(Double(sampleRate) * duration)
        var samples = [Int16](repeating: 0, count: n)
        for i in 0..<n {
            let t = Double(i) / Double(sampleRate)
            let env = exp(-t * 220.0)
            let v = sin(2.0 * Double.pi * freq * t) * env * 0.6
            samples[i] = Int16(max(-1.0, min(1.0, v)) * 32000)
        }
        var data = Data()
        func str(_ s: String) { data.append(contentsOf: Array(s.utf8)) }
        func u32(_ x: UInt32) { var le = x.littleEndian; withUnsafeBytes(of: &le) { data.append(contentsOf: $0) } }
        func u16(_ x: UInt16) { var le = x.littleEndian; withUnsafeBytes(of: &le) { data.append(contentsOf: $0) } }
        let dataSize = UInt32(n * 2)
        str("RIFF"); u32(36 + dataSize); str("WAVE")
        str("fmt "); u32(16); u16(1); u16(1)
        u32(UInt32(sampleRate)); u32(UInt32(sampleRate * 2)); u16(2); u16(16)
        str("data"); u32(dataSize)
        for s in samples { var le = s.littleEndian; withUnsafeBytes(of: &le) { data.append(contentsOf: $0) } }
        return data
    }
}
