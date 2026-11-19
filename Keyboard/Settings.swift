import Foundation

/// 键盘设置（存扩展自身 App 支持目录的 config.json）。Direction 定义在 KeyboardModel.swift。
struct Settings: Codable {
    var direction: Direction = .zh2en
    var showGloss: Bool = true
    var version: Int = 1
    /// 按键声音：0关 1开（B：系统键音，默认开）
    var keySoundLevel: Int = 1
    /// 按键震动：0关 1弱 2中 3强（默认中）
    var keyHapticLevel: Int = 2
}

/// 读写 config.json（扩展自身 App 支持目录，不用 App Group）。缺失/损坏→默认。
enum SettingsStore {
    /// 默认目录与键盘模型一致：App 支持目录/rime/user。
    static var dir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("rime/user")
    }()

    private static var cached: Settings?

    static func load(from d: URL) -> Settings {
        guard let data = try? Data(contentsOf: d.appendingPathComponent("config.json")),
              let s = try? JSONDecoder().decode(Settings.self, from: data) else { return Settings() }
        return s
    }

    static func save(_ s: Settings, to d: URL) {
        guard let data = try? JSONEncoder().encode(s) else { return }
        try? data.write(to: d.appendingPathComponent("config.json"))
    }

    /// 进程内共享读取（面板/反馈/模型共用一份）。
    static func shared() -> Settings {
        if let c = cached { return c }
        let s = load(from: dir)
        cached = s
        return s
    }

    /// 修改并持久化（改完即存，重启键盘仍在）。
    static func update(_ mutate: (inout Settings) -> Void) {
        var s = shared()
        mutate(&s)
        cached = s
        save(s, to: dir)
    }
}
