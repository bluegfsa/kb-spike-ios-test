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
    var primaryTranslation: String? { get }
    var status: KBStatus { get }
    var onChange: (() -> Void)? { get set }   // 每次状态更新后【主线程】回调

    func input(letter: Character)
    func backspace()
    func space() -> String                    // 返回应上屏文本
    func newline() -> String
    func toggleMode()
    func selectCandidate(_ index: Int) -> String?
}

/// B1 期间前端联调用：纯内存假数据，无需引擎/词库。
/// B2 起用真实 `KeyboardModel(engine:cedict:settings:)`（同协议，UI 零改动）。
final class MockKeyboardModel: KeyboardModeling {
    private(set) var mode: Direction = .zh2en
    private(set) var buffer = ""
    private(set) var candidates: [String] = []
    private(set) var primaryTranslation: String?
    private(set) var status: KBStatus = .ready
    var onChange: (() -> Void)?

    private let pinyin: [String: [String]] = [
        "ni": ["你", "尼", "泥"], "nihao": ["你好", "你"], "wo": ["我"], "women": ["我们"],
        "zhongguo": ["中国"], "xiexie": ["谢谢"], "shijie": ["世界"], "dianhua": ["电话"]
    ]
    private let zh2en: [String: String] = [
        "你": "you", "你好": "hello", "我": "I", "我们": "we", "中国": "China",
        "谢谢": "thanks", "世界": "world", "电话": "phone"
    ]
    private let en2zh: [String: String] = [
        "hello": "你好", "you": "你", "china": "中国", "thanks": "谢谢", "i": "我",
        "we": "我们", "world": "世界", "phone": "电话"
    ]

    func input(letter: Character) {
        if mode == .zh2en {
            buffer.append(Character(letter.lowercased()))
            recompute()
        } else {
            buffer.append(letter)
            recompute()
        }
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
            primaryTranslation = candidates.first.flatMap { zh2en[$0] }
        } else {
            candidates = []
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
        clearComposition(); notifyChange()
    }

    func selectCandidate(_ index: Int) -> String? {
        guard index >= 0 && index < candidates.count else { return nil }
        let t = candidates[index]; clearComposition(); notifyChange(); return t
    }

    private func clearComposition() { buffer = ""; candidates = []; primaryTranslation = nil }

    private func notifyChange() {
        DispatchQueue.main.async { [weak self] in self?.onChange?() }
    }
}
