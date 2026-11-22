import Foundation

/// 极简本地化：宿主 App 页面按系统语言自动切中/英（键盘本体不动）。
/// 不引 .lproj/Localizable.strings，避免工程配置改动；仅用于 App 页面的界面文案。
enum L10n {
    /// 是否用英文。规则：**只有系统首选语言是中文才用中文；其余（英/日/法…）一律回退英文**。
    static var isEnglish: Bool {
        let p = (Locale.preferredLanguages.first ?? "en").lowercased()
        return !p.hasPrefix("zh")
    }

    /// 取中/英文案。
    static func t(_ zh: String, _ en: String) -> String {
        isEnglish ? en : zh
    }
}
