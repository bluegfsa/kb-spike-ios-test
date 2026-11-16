import Foundation

/// 键盘设置（存 App Group 的 config.json）。Direction 定义在 KeyboardModel.swift。
struct Settings: Codable {
    var direction: Direction = .zh2en
    var showGloss: Bool = true
    var version: Int = 1
}

/// 读写 config.json（App Group）。缺失/损坏→默认。
enum SettingsStore {
    static func load(from dir: URL) -> Settings {
        guard let d = try? Data(contentsOf: dir.appendingPathComponent("config.json")),
              let s = try? JSONDecoder().decode(Settings.self, from: d) else { return Settings() }
        return s
    }

    static func save(_ s: Settings, to dir: URL) {
        guard let d = try? JSONEncoder().encode(s) else { return }
        try? d.write(to: dir.appendingPathComponent("config.json"))
    }
}
