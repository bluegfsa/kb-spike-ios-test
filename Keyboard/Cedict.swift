import Foundation

/// CC-CEDICT 双向译词查词：两个「前缀排序」文件（zh2en / en2zh），mmap 只读 + 单 [UInt32] 行首索引。
/// 说明：这是「**译词查词**」索引（给键盘旁显译词用），不是拼音引擎；不解析常驻（§9.5，dirty 极小）。
final class Cedict {
    private let zh2enFile: PrefixFile
    private let en2zhFile: PrefixFile

    init?(zh2enURL: URL, en2zhURL: URL) {
        guard let a = PrefixFile(url: zh2enURL), let b = PrefixFile(url: en2zhURL) else { return nil }
        zh2enFile = a; en2zhFile = b
    }

    /// zh2en=true：查中文词的英文译文；false：查英文词的中文。
    func lookup(_ term: String, zh2en: Bool, limit: Int = 1) -> [String] {
        let f = zh2en ? zh2enFile : en2zhFile
        let t = zh2en ? term : term.lowercased()
        return f.prefix(t, limit: limit)
    }

    /// 精确查（键完全等于 term，非前缀）。多字词翻译优先用它命中整词，避免前缀误取。
    func exact(_ term: String, zh2en: Bool) -> String? {
        let f = zh2en ? zh2enFile : en2zhFile
        let t = zh2en ? term : term.lowercased()
        return f.exact(t)
    }
}

/// 单个「键\t释义」前缀排序文件的 mmap 前缀查（复用 S4 §9.5 做法：单 [UInt32] 索引）。
private final class PrefixFile {
    private let data: Data
    private let starts: [UInt32]

    init?(url: URL) {
        guard let d = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        data = d
        var s = [UInt32]()
        s.reserveCapacity(1 << 17)
        d.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            let p = raw.bindMemory(to: UInt8.self)
            let c = p.count
            if c > 0 { s.append(0) }
            var i = 0
            while i < c { if p[i] == 10 && i + 1 < c { s.append(UInt32(i + 1)) }; i += 1 }
        }
        starts = s
    }

    private func bounds(_ i: Int) -> (s: Int, e: Int) {
        let s = Int(starts[i])
        var e = (i + 1 < starts.count) ? Int(starts[i + 1]) - 1 : data.count
        while e > s && (data[e - 1] == 10 || data[e - 1] == 13) { e -= 1 }
        return (s, e > s ? e : s)
    }

    private func parts(_ i: Int) -> (key: String, gloss: String) {
        let (s, e) = bounds(i)
        var tab = e
        var j = s
        while j < e { if data[j] == 9 { tab = j; break }; j += 1 }
        let key = String(decoding: data[s..<tab], as: UTF8.self)
        let gs = tab < e ? tab + 1 : e
        let gloss = String(decoding: data[gs..<e], as: UTF8.self)
        return (key, gloss)
    }

    private func key(_ i: Int) -> String { parts(i).key }

    /// 键完全等于 key 的那一行的释义；无则 nil（二分定位到第一个 ≥key 的行再判定）。
    func exact(_ key: String) -> String? {
        var lo = 0
        var hi = starts.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if self.key(mid) < key { lo = mid + 1 } else { hi = mid }
        }
        if lo < starts.count {
            let (k, g) = parts(lo)
            if k == key { return g }
        }
        return nil
    }

    func prefix(_ prefix: String, limit: Int) -> [String] {
        var lo = 0
        var hi = starts.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if key(mid) < prefix { lo = mid + 1 } else { hi = mid }
        }
        var out = [String]()
        var i = lo
        while i < starts.count && out.count < limit {
            let (k, g) = parts(i)
            if !k.hasPrefix(prefix) { break }
            if !out.contains(g) { out.append(g) }
            i += 1
        }
        return out
    }
}
