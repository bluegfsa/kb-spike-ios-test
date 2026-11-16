import Foundation

/// 键盘纯逻辑（无 UIKit 依赖，便于在 CI 上做自检/单测）。
/// 视图与控制器复用这里，保证「界面行为」与「被测逻辑」是同一份代码。
enum KeyboardLogic {
    /// 标点 5 键组（架构 §C：中文全角「，。？！、」↔ 英文半角「, . ? ! ,」，顿号→逗号）。
    static let punctFull: [Character] = ["，", "。", "？", "！", "、"]
    static let punctHalf: [Character] = [",", ".", "?", "!", ","]

    /// 标点键面：按 padding 索引取当前全/半角字符；越界返回空串。
    static func punctuationGlyph(fullWidth: Bool, index: Int) -> String {
        guard index >= 0 && index < punctFull.count else { return "" }
        return String(fullWidth ? punctFull[index] : punctHalf[index])
    }

    /// 长按连删的下一档间隔：每步 ×0.85、封底 0.03s（#14，0.12→0.03）。
    static func nextDeleteInterval(from current: Double) -> Double {
        max(0.03, current * 0.85)
    }

    /// 字母键面：中文态恒小写；英文态按 shift 决定大小写（#10 中文无大写、英文可切）。
    static func letter(_ ch: Character, isChinese: Bool, shift: Bool) -> String {
        (isChinese || !shift) ? String(ch) : String(ch).uppercased()
    }
}
