import Foundation

/// 输入方向：`zh2en` = 打拼音出中文、旁显英文；`en2zh` = 打英文、旁显中文。
enum Direction: String, Codable { case zh2en, en2zh }

/// 键盘状态。命名为 KBStatus 避免与系统 Status 撞名。
enum KBStatus: Equatable { case ready, needInit, error(String) }

/// UI 绑定的唯一接口（前端只依赖它，不碰引擎/词库）。
protocol KeyboardModeling: AnyObject {
    var mode: Direction { get }
    var buffer: String { get }
    var candidates: [String] { get }
    var candidateTranslations: [String?] { get }
    var primaryTranslation: String? { get }
    var punctuationFullWidth: Bool { get }
    var status: KBStatus { get }
    var onChange: (() -> Void)? { get set }

    func input(letter: Character)
    func backspace()
    func space() -> String
    func newline() -> String
    func toggleMode()
    func togglePunctuation()
    func selectCandidate(_ index: Int) -> String?
}

// MARK: - Mock（前端联调先用，无引擎）
final class MockKeyboardModel: KeyboardModeling {
    private(set) var mode: Direction = .zh2en
    private(set) var buffer = ""
    private(set) var candidates: [String] = []
    private(set) var candidateTranslations: [String?] = []
    private(set) var primaryTranslation: String?
    private(set) var punctuationFullWidth: Bool = true
    private(set) var status: KBStatus = .ready
    var onChange: (() -> Void)?

    private let pinyin: [String: [String]] = [
        "ni": ["你", "尼", "泥"], "nihao": ["你好", "你"], "wo": ["我"], "women": ["我们"],
        "zhongguo": ["中国"], "xiexie": ["谢谢"], "shijie": ["世界"], "dianhua": ["电话"],
        "qi": ["七", "起", "气", "期"], "hao": ["好"], "shu": ["书"], "chi": ["吃"],
        "zaijian": ["再见"], "duibuqi": ["对不起"], "meiguanxi": ["没关系"]
    ]
    private let zh2en: [String: String] = [
        "你": "you", "你好": "hello", "我": "I", "我们": "we", "中国": "China",
        "谢谢": "thanks", "世界": "world", "电话": "phone", "七": "seven", "起": "rise",
        "气": "air", "期": "period", "好": "good", "书": "book", "吃": "eat",
        "再见": "goodbye", "对不起": "sorry", "没关系": "never mind"
    ]
    private let en2zh: [String: String] = [
        "hello": "你好", "you": "你", "china": "中国", "thanks": "谢谢", "i": "我",
        "we": "我们", "world": "世界", "phone": "电话", "seven": "七", "good": "好"
    ]

    func input(letter: Character) {
        buffer.append(mode == .zh2en ? Character(letter.lowercased()) : letter)
        recompute(); notifyChange()
    }
    func backspace() { if !buffer.isEmpty { buffer.removeLast() }; recompute(); notifyChange() }
    private func recompute() {
        if mode == .zh2en {
            candidates = pinyin[buffer] ?? []
            candidateTranslations = candidates.map { zh2en[$0] }
            primaryTranslation = candidateTranslations.first ?? nil
        } else {
            candidates = []; candidateTranslations = []
            primaryTranslation = en2zh[buffer.lowercased()]
        }
    }
    func space() -> String { let t = (mode == .zh2en) ? (candidates.first ?? buffer) : " "; clearComposition(); notifyChange(); return t }
    func newline() -> String { clearComposition(); notifyChange(); return "\n" }
    func toggleMode() { mode = (mode == .zh2en) ? .en2zh : .zh2en; punctuationFullWidth = (mode == .zh2en); clearComposition(); notifyChange() }
    func togglePunctuation() { punctuationFullWidth.toggle(); notifyChange() }
    func selectCandidate(_ index: Int) -> String? {
        guard index >= 0 && index < candidates.count else { return nil }
        let t = candidates[index]; clearComposition(); notifyChange(); return t
    }
    private func clearComposition() { buffer = ""; candidates = []; candidateTranslations = []; primaryTranslation = nil }
    private func notifyChange() { DispatchQueue.main.async { [weak self] in self?.onChange?() } }
}

// MARK: - 真模型（librime 引擎 + CC-CEDICT 译词）
final class KeyboardModel: KeyboardModeling {
    private(set) var mode: Direction = .zh2en
    private(set) var buffer = ""
    private(set) var candidates: [String] = []
    private(set) var candidateTranslations: [String?] = []
    private(set) var primaryTranslation: String?
    private(set) var punctuationFullWidth: Bool = true
    private(set) var status: KBStatus = .needInit
    var onChange: (() -> Void)?

    private let cedict: Cedict?
    private var engineReady = false
    /// 英文态：已提交单词的中文译文（逐词累积，随打字实时刷新，不因空格清空）。
    private var enSentence: [String] = []

    /// 译词表从 bundle 直接 mmap（zh2en.txt / en2zh.txt 随包资源）。
    init(sharedDir: URL, userDir: URL) {
        let zh = Bundle.main.url(forResource: "zh2en", withExtension: "txt")
        let en = Bundle.main.url(forResource: "en2zh", withExtension: "txt")
        if let zh, let en { cedict = Cedict(zh2enURL: zh, en2zhURL: en) } else { cedict = nil }
        // 后台线程初始化（不阻塞键盘 UI）；首次会做一次性部署，之后只加载。
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let ok = RimeKbInit(sharedDir.path, userDir.path)
            DispatchQueue.main.async {
                self?.engineReady = ok
                self?.status = ok ? .ready : .error("引擎初始化失败")
                self?.notifyChange()
            }
        }
        // 超时兜底：12s 仍未就绪则提示（不打断后台部署，仅提示用户稍候/重开）。
        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
            guard let self else { return }
            if !self.engineReady, case .needInit = self.status {
                self.status = .error("初始化较慢，请稍候或重新打开键盘")
                self.notifyChange()
            }
        }
    }

    /// 译一个词/短语。
    /// zh2en：先短语表，再整词精确查，最后贪心最长匹配分词兜底（多字词组也能出译文）。
    /// en2zh：整词精确查（#2：打字过程不做前缀兜底——前缀会取字典首条长释义，导致不同输入命中同一条、译文“卡死”；空格成词时同样走精确查）。
    private func translate(_ term: String, zh2en: Bool) -> String? {
        guard let cd = cedict, !term.isEmpty else { return nil }
        if zh2en {
            if let p = PhraseGlossary.en(term) { return p }
            if let t = templateZh(term) { return t }
            if let e = cd.exact(term, zh2en: true) { return e }
            return segmentZh(term, cd)
        } else {
            return cd.exact(term.lowercased(), zh2en: false)
        }
    }

    /// 高频「代词+在+动作」疑问模板：如 我在干什么→What am I doing，避免被硬拼成 I am what are you doing。
    private func templateZh(_ term: String) -> String? {
        let pronMap: [String: String] = ["我": "I", "你": "you", "您": "you", "他": "he", "她": "she", "它": "it",
                                          "我们": "we", "你们": "you", "他们": "they", "她们": "they"]
        let beMap: [String: String] = ["我": "am", "你": "are", "您": "are", "他": "is", "她": "is", "它": "is",
                                        "我们": "are", "你们": "are", "他们": "are", "她们": "are"]
        let actions = ["干什么", "做什么", "干嘛呢", "干嘛", "干啥", "做啥"]
        for (p, pe) in pronMap {
            for a in actions where term == p + "在" + a {
                return "What \(beMap[p] ?? "is") \(pe) doing"
            }
        }
        return nil
    }

    /// 贪心最长匹配分词：把 term 从左往右切成若干已知词，各自取英译并用空格拼接。
    /// 任一字无译则跳过（宁缺毋滥），全无译返回 nil。
    private func segmentZh(_ term: String, _ cd: Cedict) -> String? {
        let chars = Array(term)
        var i = 0
        var parts: [String] = []
        while i < chars.count {
            var j = chars.count
            var matched = false
            while j > i {
                if let g = cd.exact(String(chars[i..<j]), zh2en: true), !g.isEmpty {
                    parts.append(g); i = j; matched = true; break
                }
                j -= 1
            }
            if !matched { i += 1 } // 该字无译，跳过继续
        }
        // 护栏（BUG-8a）：拼出多段且含代词/系词碎片（I am …）视为硬拼错义 → 宁缺毋滥，返回 nil 不硬拼
        if parts.count > 1 {
            let frag = Set(parts.map { $0.lowercased() })
            let bad: Set<String> = ["i", "i am", "you", "you are", "he", "she", "it", "we", "they", "am", "is", "are"]
            if !frag.isDisjoint(with: bad) { return nil }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    /// 英文态当前可见译文＝已提交单词译文＋当前正在打的这个词的译文（实时刷新）。
    private func enTranslation(currentWord: String) -> String? {
        var words = enSentence
        if !currentWord.isEmpty, let t = translate(currentWord, zh2en: false), !t.isEmpty {
            words.append(t)
        }
        return words.isEmpty ? nil : words.joined(separator: " ")
    }

    func input(letter: Character) {
        if mode == .zh2en {
            buffer.append(Character(letter.lowercased()))
            if engineReady {
                let code = Int32(letter.lowercased().unicodeScalars.first?.value ?? 0)
                candidates = RimeKbInput(code)
                recomputeTranslations()
            }
        } else {
            buffer.append(letter)
            candidates = []; candidateTranslations = []
            primaryTranslation = enTranslation(currentWord: buffer)
        }
        notifyChange()
    }

    func backspace() {
        let hadComposition = !buffer.isEmpty   // 有拼音 composition 才需通知 rime 退格
        if hadComposition { buffer.removeLast() }
        if mode == .zh2en {
            // S3-03：composition 已空时不再向 rime 发退格，避免多删/误触
            if engineReady && hadComposition { candidates = RimeKbInput(0xFF08) }
            if buffer.isEmpty {
                // BUG-7：删到空 → 重置引擎 composition 并清空候选，杜绝"候选删不干净/卡住"
                if engineReady { RimeKbReset() }
                candidates = []; candidateTranslations = []; primaryTranslation = nil
            } else {
                recomputeTranslations()
            }
        } else {
            candidates = []; candidateTranslations = []
            primaryTranslation = enTranslation(currentWord: buffer)
        }
        notifyChange()
    }

    private func recomputeTranslations() {
        candidateTranslations = candidates.map { translate($0, zh2en: true) }
        primaryTranslation = candidateTranslations.first ?? nil
    }

    func space() -> String {
        if mode == .en2zh {
            // #6：英文态空格＝打一个空格、继续往下打；当前词译文并入句译，不清空已得译文。
            if let t = translate(buffer, zh2en: false), !t.isEmpty { enSentence.append(t) }
            buffer = ""; candidates = []; candidateTranslations = []
            primaryTranslation = enSentence.isEmpty ? nil : enSentence.joined(separator: " ")
            notifyChange(); return " "
        }
        var text = buffer
        if let sel = RimeKbSelect(0) { text = sel }
        commitAndClear(); return text
    }

    func newline() -> String { commitAndClear(); return "\n" }

    func toggleMode() {
        mode = (mode == .zh2en) ? .en2zh : .zh2en
        punctuationFullWidth = (mode == .zh2en)
        RimeKbReset()
        clearComposition(); notifyChange()
    }

    func togglePunctuation() { punctuationFullWidth.toggle(); notifyChange() }

    func selectCandidate(_ index: Int) -> String? {
        guard mode == .zh2en else { return nil }
        let t = RimeKbSelect(Int32(index))
        commitAndClear(); return t
    }

    /// 提交后统一收口：先 RimeKbReset 清引擎内部 composition，再清 Swift 侧缓存，再通知刷新；避免旧串残留叠加。
    private func commitAndClear() { RimeKbReset(); clearComposition(); notifyChange() }
    private func clearComposition() { buffer = ""; candidates = []; candidateTranslations = []; primaryTranslation = nil; enSentence = [] }
    private func notifyChange() { DispatchQueue.main.async { [weak self] in self?.onChange?() } }
}
