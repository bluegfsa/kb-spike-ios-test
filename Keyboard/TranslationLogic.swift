import Foundation

/// 中→英译词策略：纯 Foundation、不依赖 Rime/Cedict/UIKit，便于 macOS `swiftc` 自测（CI 门禁）。
/// 只做“判定”，不查词——查词结果由调用方（Cedict / KeyboardModel）传入。
enum ZhEnPolicy {
    /// 所有格闭集：整串恰为「代词＋的」→ 物主词。
    /// 裸「我/你/他…」不在内（仍走整词 exact → I/you），杜绝把「我」误变 my。
    static let possessiveMap: [String: String] = [
        "我的": "my", "你的": "your", "您的": "your", "他的": "his", "她的": "her", "它的": "its",
        "我们的": "our", "你们的": "your", "他们的": "their", "她们的": "their"
    ]

    /// 单字虚词：任一段为单字且属此集 → 禁止分词拼接（否则易出 we of / you of 之类错义）。
    static let functionWords: Set<String> = [
        "的", "地", "得", "了", "吗", "呢", "吧", "啊", "呀", "嘛",
        "在", "是", "和", "与", "及", "或", "就", "都", "也", "又",
        "很", "太", "更", "最", "不", "没", "会", "要", "能", "把",
        "被", "着", "过", "而", "却", "才", "还", "给", "让", "对",
        "有", "从", "向", "为", "但"
    ]

    /// 取所有格物主词；仅「X＋的」整串命中，其它（含裸「我/你」）返回 nil。
    static func possessiveWord(_ term: String) -> String? { possessiveMap[term] }

    /// 是否允许把分词结果硬拼成译文：段数 ≤2、任一段不是单字虚词、且每段都有译文（无跳过）。
    /// 任一不满足即返回 false（宁缺毋滥，不给错译）。
    static func allowsSegmentation(segments: [String], allTranslated: Bool) -> Bool {
        guard allTranslated else { return false }
        guard segments.count <= 2 else { return false }
        if segments.contains(where: { $0.count == 1 && functionWords.contains($0) }) { return false }
        return true
    }
}
