import Foundation

/// 前缀排序文本词典的「内存映射」实现。
/// 关键：文件用 Data(contentsOf:options:.mappedIfSafe) 映射 = file-backed 的 **clean 内存**
/// （内核可回收、基本不计入 footprint）；只有命中的行才分配少量 heap。
/// 绝不把整本词库解析成 Swift 数组/字典（那是 dirty heap，且常拖到按首键才加载）。
final class MmapDict {
    private let data: Data
    private let lineStarts: [Int]
    private let lineEnds: [Int]

    init?(url: URL) {
        guard let d = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        data = d
        var starts = [Int]()
        var ends = [Int]()
        var s = 0
        d.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            let p = raw.bindMemory(to: UInt8.self)
            let c = p.count
            var i = 0
            while i < c {
                if p[i] == 10 { // '\n'
                    starts.append(s)
                    ends.append(i)
                    s = i + 1
                }
                i += 1
            }
            if s < c {
                starts.append(s)
                ends.append(c)
            }
        }
        lineStarts = starts
        lineEnds = ends
    }

    var count: Int { lineStarts.count }

    private func keyRange(_ i: Int) -> (s: Int, e: Int) {
        let s = lineStarts[i]
        let e = lineEnds[i]
        var j = s
        while j < e {
            if data[j] == 9 { return (s, j) } // '\t'
            j += 1
        }
        return (s, e)
    }

    private func lineKey(_ i: Int) -> String {
        let r = keyRange(i)
        return String(decoding: data[r.s..<r.e], as: UTF8.self)
    }

    private func lineGloss(_ i: Int) -> String {
        let s = lineStarts[i]
        let e = lineEnds[i]
        var tab = e
        var j = s
        while j < e {
            if data[j] == 9 { tab = j; break }
            j += 1
        }
        let gs = tab < e ? tab + 1 : e
        return String(decoding: data[gs..<e], as: UTF8.self)
    }

    /// 二分定位第一个 >= prefix 的行，然后顺序收集以 prefix 开头的条目（连续区间）。
    func prefix(_ prefix: String, limit: Int = 5) -> [String] {
        var lo = 0
        var hi = lineStarts.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if lineKey(mid) < prefix { lo = mid + 1 } else { hi = mid }
        }
        var out: [String] = []
        var i = lo
        while i < lineStarts.count && out.count < limit {
            let k = lineKey(i)
            if !k.hasPrefix(prefix) { break }
            out.append("\(k) = \(lineGloss(i))")
            i += 1
        }
        return out
    }
}
