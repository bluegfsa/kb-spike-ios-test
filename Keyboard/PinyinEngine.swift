import Foundation

/// 拼音词典的「文件映射」前缀查找引擎。
/// 关键（ARCH §9.5）：Data(.mappedIfSafe) = file-backed 的 **clean 内存**（内核可回收、基本不计 footprint）。
/// 索引本身是唯一的 dirty 常驻：用单个 `[UInt32]` 存每行起始偏移（4 字节/行，6 万行≈240KB），
/// 行尾由「下一行起点-1」O(1) 推出、不再额外存 lineEnds，避免原来两个 `[Int]`（≈8 字节/行）的翻倍开销。
final class PinyinEngine {
    private let data: Data
    private let starts: [UInt32]

    init?(url: URL) {
        guard let d = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        data = d
        var st = [UInt32]()
        st.reserveCapacity(65536)
        d.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            let p = raw.bindMemory(to: UInt8.self)
            let c = p.count
            if c > 0 { st.append(0) }               // 第一行起点
            var i = 0
            while i < c {
                if p[i] == 10 && i + 1 < c { st.append(UInt32(i + 1)) } // 下一行起点
                i += 1
            }
        }
        starts = st
    }

    var count: Int { starts.count }

    /// 第 i 行的 [start, end) 字节区间；end 不含行尾换行符。
    private func bounds(_ i: Int) -> (s: Int, e: Int) {
        let s = Int(starts[i])
        var e = (i + 1 < starts.count) ? Int(starts[i + 1]) - 1 : data.count
        while e > s && (data[e - 1] == 10 || data[e - 1] == 13) { e -= 1 } // 去掉末尾 CR/LF
        return (s, e > s ? e : s)
    }

    private func lineParts(_ i: Int) -> (key: String, gloss: String) {
        let (s, e) = bounds(i)
        var tab = e
        var j = s
        while j < e { if data[j] == 9 { tab = j; break }; j += 1 } // 9 = '\t'
        let key = String(decoding: data[s..<tab], as: UTF8.self)
        let gs = tab < e ? tab + 1 : e
        let gloss = String(decoding: data[gs..<e], as: UTF8.self)
        return (key, gloss)
    }

    private func lineKey(_ i: Int) -> String { lineParts(i).key }

    /// 二分定位第一个 >= prefix 的行，再顺序收集以 prefix 开头的连续区间（同拼音多候选也在此连续）。
    func candidates(_ prefix: String, limit: Int = 8) -> [String] {
        var lo = 0
        var hi = starts.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if lineKey(mid) < prefix { lo = mid + 1 } else { hi = mid }
        }
        var out: [String] = []
        var i = lo
        while i < starts.count && out.count < limit {
            let (k, g) = lineParts(i)
            if !k.hasPrefix(prefix) { break }
            let s = "\(k)=\(g)"
            if !out.contains(s) { out.append(s) }
            i += 1
        }
        return out
    }
}

/// 对照探针：把整本词库「错误地」解析进内存（dirty heap），实测 §9.5 的上限——
/// 验证「mmap 干净页 vs 全量解析进堆」的 footprint 差。仅调试按钮触发，正式代码不用。
enum HeapDictProbe {
    static var sink: Any?

    @discardableResult
    static func build(url: URL) -> Int {
        guard let s = try? String(contentsOf: url, encoding: .utf8) else { return 0 }
        var rows = [String]()
        rows.reserveCapacity(70000)
        for line in s.split(separator: "\n") { rows.append(String(line)) }
        var index = [String: [String]]()
        index.reserveCapacity(rows.count)
        for r in rows {
            let parts = r.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count == 2 { index[String(parts[0]), default: []].append(String(parts[1])) }
        }
        sink = index // 持有，确保不被优化释放，footprint 才反映真实代价
        return index.count
    }
}
