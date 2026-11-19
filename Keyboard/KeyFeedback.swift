import UIKit
import AudioToolbox

/// 按键反馈：声音 S1 多档（关/小/中/大，预生成 3 档振幅音·系统声音 ID）＋ 震动 4 档（关/弱/中/强）。
/// 键盘扩展里**严禁 AVAudioPlayer / AVAudioSession**（1.28 卡死源：激活音频会话 + 每键 new player）。
/// S1 做法：`init` 在后台一次性合成 3 段极短 WAV 并 `AudioServicesCreateSystemSoundID` 注册成系统声音 ID；
/// 按键只调一次 `AudioServicesPlaySystemSound(id)`——零音频会话、零每键分配，结构上不会卡。
final class KeyFeedback {
    static let shared = KeyFeedback()

    private lazy var lightGen = UIImpactFeedbackGenerator(style: .light)
    private lazy var mediumGen = UIImpactFeedbackGenerator(style: .medium)
    private lazy var heavyGen = UIImpactFeedbackGenerator(style: .heavy)

    /// 3 档声音的系统 ID：索引 0=小 1=中 2=大；值 0 表示尚未就绪或生成失败（静默不播）。
    private var soundIDs: [SystemSoundID] = [0, 0, 0]

    private init() {
        generateSounds()
    }

    deinit {
        for id in soundIDs where id != 0 { AudioServicesDisposeSystemSoundID(id) }
    }

    // MARK: - 声音生成（S1：后台一次性，零每键分配）

    /// 后台一次性合成 3 档振幅（小/中/大）的极短 click 并注册为系统声音 ID。任何异常静默兜底。
    private func generateSounds() {
        let peaks: [Float] = [0.2, 0.45, 0.9] // 小/中/大峰值振幅
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var ids: [SystemSoundID] = [0, 0, 0]
            for (index, peak) in peaks.enumerated() {
                guard let url = Self.writeClickWAV(peak: peak, index: index) else { continue }
                var id: SystemSoundID = 0
                if AudioServicesCreateSystemSoundID(url as CFURL, &id) == kAudioServicesNoError {
                    ids[index] = id
                }
            }
            DispatchQueue.main.async { self?.soundIDs = ids }
        }
    }

    /// 生成一段约 25ms 指数衰减正弦 click 的 WAV（mono/44.1k/16bit），写入 caches，返回 URL。
    private static func writeClickWAV(peak: Float, index: Int) -> URL? {
        let sampleRate = 44100
        let frameCount = Int(Double(sampleRate) * 0.025)
        let freq = 1600.0
        var samples = [Int16](repeating: 0, count: frameCount)
        for n in 0..<frameCount {
            let t = Double(n) / Double(sampleRate)
            let env = exp(-t * 140.0) // 快速衰减，听感干脆
            let v = sin(2.0 * .pi * freq * t) * env * Double(peak)
            samples[n] = Int16(max(-1.0, min(1.0, v)) * Double(Int16.max))
        }
        let dataSize = frameCount * 2
        var data = Data()
        func appendASCII(_ s: String) { data.append(contentsOf: Array(s.utf8)) }
        func append32(_ v: UInt32) { var x = v.littleEndian; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }
        func append16(_ v: UInt16) { var x = v.littleEndian; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }
        appendASCII("RIFF")
        append32(UInt32(36 + dataSize))
        appendASCII("WAVE")
        appendASCII("fmt ")
        append32(16)                      // fmt chunk 大小
        append16(1)                       // PCM
        append16(1)                       // 单声道
        append32(UInt32(sampleRate))
        append32(UInt32(sampleRate * 2))  // 字节率 = 采样率 * 单声道 * 2字节
        append16(2)                       // block align
        append16(16)                      // 位深
        appendASCII("data")
        append32(UInt32(dataSize))
        for s in samples { append16(UInt16(bitPattern: s)) }
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let url = dir.appendingPathComponent("kb_click_\(index).wav")
        do { try data.write(to: url); return url } catch { return nil }
    }

    // MARK: - 播放

    /// 按当前设置播一次按键反馈：震动 4 档 + 声音多档（S1 系统 ID，主线程轻量 C 调用）。
    func play() {
        let s = SettingsStore.shared()
        switch s.keyHapticLevel { // 0关1弱2中3强
        case 1: lightGen.prepare(); lightGen.impactOccurred(intensity: 0.4)
        case 2: mediumGen.prepare(); mediumGen.impactOccurred(intensity: 0.7)
        case 3: heavyGen.prepare(); heavyGen.impactOccurred(intensity: 1.0)
        default: break
        }
        let level = s.keySoundLevel // 0关 1小 2中 3大
        if level >= 1 && level <= soundIDs.count {
            let id = soundIDs[level - 1]
            if id != 0 { AudioServicesPlaySystemSound(id) }
        }
    }
}
