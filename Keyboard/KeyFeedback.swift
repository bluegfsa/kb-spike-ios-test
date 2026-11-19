import UIKit
import AVFoundation

/// 按键反馈（④）：声音 4 档 + 震动 4 档。
/// 声音＝代码合成的极短 click（WAV Data → AVAudioPlayer），零外部素材、无版权、体积极小。
final class KeyFeedback {
    static let shared = KeyFeedback()

    private var clickData: Data?

    private init() {
        clickData = Self.makeClickWAV()
        // 随静音键静音；与其它音频混音，不打断用户音乐。
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true, options: [])
    }

    /// 按当前设置播一次按键反馈（震动 + 声音）。
    func play() {
        let s = SettingsStore.shared()
        switch s.keyHapticLevel { // 0关1弱2中3强
        case 1: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case 2: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case 3: UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        default: break
        }
        guard s.keySoundLevel > 0, let data = clickData else { return } // 0关
        let volumes: [Float] = [0, 0.33, 0.66, 1.0] // 关/小/中/大
        let v = volumes[max(0, min(3, s.keySoundLevel))]
        if let player = try? AVAudioPlayer(data: data) {
            player.volume = v
            player.play()
        }
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
