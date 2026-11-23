import Foundation

/// 对外链接的**单一来源**配置。
/// 站点未上线时保持空字符串：关于页据此**隐藏**对应入口，绝不显示空链接或死链。
/// 上线后只改这里一处（并到 App Store Connect 填同样的 URL），出补丁包即可。
enum AppLinks {
    /// 线上隐私政策 URL（对应 ASC 的 Privacy Policy URL）。为空则「应用」分组不显示线上版入口。
    static let privacyPolicyURL = ""
    /// 支持 / 帮助页 URL（可选）。为空则不显示。
    static let supportURL = ""
}