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
    var candidateTranslations: [String?] { get }   // 与 candidates 等长、平行；每个候选的另一语种首选译词（#6/#9）
    var primaryTranslation: String? { get }
    var punctuationFullWidth: Bool { get }          // 标点全角(true,中文)/半角(false,英文)（#12）
    var status: KBStatus { get }
    var onChange: (() -> Void)? { get set }   // 每次状态更新后【主线程】回调

    func input(letter: Character)
    func backspace()
    func space() -> String                    // 返回应上屏文本
    func newline() -> String
    func toggleMode()
    func togglePunctuation()                   // 数字态「，。」键：切全/半角标点（#12）
    func selectCandidate(_ index: Int) -> String?
}

/// B1/B2 前端联调用：纯内存假数据，无需引擎/词库。
/// B2 起用真实 `KeyboardModel(engine:cedict:settings:)`（同协议，UI 零改动）。
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
        "谢谢": "thanks", "世界": "world", "电话": "phone",
        "七": "seven", "起": "rise", "气": "air", "期": "period", "好": "good",
        "书": "book", "吃": "eat", "再见": "goodbye", "对不起": "sorry", "没关系": "never mind"
    ]
    private let en2zh: [String: String] = [
        "hello": "你好", "you": "你", "china": "中国", "thanks": "谢谢", "i": "我",
        "we": "我们", "world": "世界", "phone": "电话",
        "seven": "七", "good": "好", "book": "书", "eat": "吃", "goodbye": "再见", "sorry": "对不起"
    ]

    func input(letter: Character) {
        if mode == .zh2en {
            buffer.append(Character(letter.lowercased()))
        } else {
            buffer.append(letter)
        }
        recompute()
        notifyChange()
    }

    func backspace() {
        if !buffer.isEmpty { buffer.removeLast() }
        recompute()
        notifyChange()
    }

    private func recompute() {
        if mode == .zh2en {
            candidates = pinyin[buffer] ?? []
            candidateTranslations = candidates.map { zh2en[$0] }
            primaryTranslation = candidateTranslations.first ?? nil
        } else {
            candidates = []
            candidateTranslations = []
            primaryTranslation = en2zh[buffer.lowercased()]
        }
    }

    func space() -> String {
        let text: String = (mode == .zh2en) ? (candidates.first ?? buffer) : " "
        clearComposition(); notifyChange(); return text
    }

    func newline() -> String { clearComposition(); notifyChange(); return "\n" }

    func toggleMode() {
        mode = (mode == .zh2en) ? .en2zh : .zh2en
        punctuationFullWidth = (mode == .zh2en)   // 中文默认全角、英文半角
        clearComposition(); notifyChange()
    }

    func togglePunctuation() { punctuationFullWidth.toggle(); notifyChange() }

    func selectCandidate(_ index: Int) -> String? {
        guard index >= 0 && index < candidates.count else { return nil }
        let t = candidates[index]; clearComposition(); notifyChange(); return t
    }

    private func clearComposition() { buffer = ""; candidates = []; candidateTranslations = []; primaryTranslation = nil }

    private func notifyChange() {
        DispatchQueue.main.async { [weak self] in self?.onChange?() }
    }
}
