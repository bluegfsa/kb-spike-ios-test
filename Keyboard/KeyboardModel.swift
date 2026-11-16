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

    private func lookupOne(_ term: String, zh2en: Bool) -> String? {
        guard let cd = cedict else { return nil }
        return cd.lookup(term, zh2en: zh2en, limit: 1).first
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
            primaryTranslation = lookupOne(buffer.lowercased(), zh2en: false)
        }
        notifyChange()
    }

    func backspace() {
        let hadComposition = !buffer.isEmpty   // 有拼音 composition 才需通知 rime 退格
        if hadComposition { buffer.removeLast() }
        if mode == .zh2en {
            // S3-03：composition 已空时不再向 rime 发退格，避免多删/误触
            if engineReady && hadComposition { candidates = RimeKbInput(0xFF08) }
            recomputeTranslations()
        } else {
            candidates = []; candidateTranslations = []
            primaryTranslation = lookupOne(buffer.lowercased(), zh2en: false)
        }
        notifyChange()
    }

    private func recomputeTranslations() {
        candidateTranslations = candidates.map { lookupOne($0, zh2en: true) }
        primaryTranslation = candidateTranslations.first ?? nil
    }

    func space() -> String {
        var text = " "
        if mode == .zh2en {
            if let sel = RimeKbSelect(0) { text = sel } else { text = buffer }
        }
        clearComposition(); notifyChange(); return text
    }

    func newline() -> String { clearComposition(); notifyChange(); return "\n" }

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
        clearComposition(); notifyChange(); return t
    }

    private func clearComposition() { buffer = ""; candidates = []; candidateTranslations = []; primaryTranslation = nil }
    private func notifyChange() { DispatchQueue.main.async { [weak self] in self?.onChange?() } }
}
