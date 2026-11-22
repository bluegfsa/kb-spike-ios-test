import Foundation

/// 极简本地化：宿主 App 页面按系统语言自动切中/英（键盘本体不动）。
/// 不引 .lproj/Localizable.strings，避免工程配置改动；仅用于 App 页面的界面文案。
enum L10n {
    /// 是否用英文。优先读 Info.plist 的 `ForceLanguage`（单语包：zh=中文包 / en=英文包）；
    /// 未设置时按系统语言：只有中文系统用中文，其余（英/日/法…）一律回退英文。
    static var isEnglish: Bool {
        if let forced = Bundle.main.object(forInfoDictionaryKey: "ForceLanguage") as? String, !forced.isEmpty {
            return forced.lowercased().hasPrefix("en")
        }
        let p = (Locale.preferredLanguages.first ?? "en").lowercased()
        return !p.hasPrefix("zh")
    }

    /// 取中/英文案。
    static func t(_ zh: String, _ en: String) -> String {
        isEnglish ? en : zh
    }
}
