import Foundation
import Darwin

/// TranslationLogic 纯逻辑自测（CI 门禁）：
///   swiftc Keyboard/TranslationLogic.swift tools/TranslationLogicTests.swift -o logic_selftest && ./logic_selftest
/// 断言失败 → 退出码非 0 → 阻断 build105。
@main
struct TranslationLogicSelftest {
    static func main() {
        var failures = 0
        func expect(_ cond: Bool, _ msg: String) {
            if cond { print("ok: \(msg)") } else { failures += 1; print("FAIL: \(msg)") }
        }

        // 所有格模板
        expect(ZhEnPolicy.possessiveWord("我们的") == "our", "我们的->our")
        expect(ZhEnPolicy.possessiveWord("你们的") == "your", "你们的->your")
        expect(ZhEnPolicy.possessiveWord("我的") == "my", "我的->my")
        expect(ZhEnPolicy.possessiveWord("他的") == "his", "他的->his")
        expect(ZhEnPolicy.possessiveWord("它的") == "its", "它的->its")

        // 裸词不变：不能被当成所有格
        expect(ZhEnPolicy.possessiveWord("我") == nil, "裸我->nil(不误变 my)")
        expect(ZhEnPolicy.possessiveWord("你") == nil, "裸你->nil(不误变 your)")

        // 单字虚词集合含评审官补的 有/从/向/为/但
        expect(ZhEnPolicy.functionWords.isSuperset(of: ["有", "从", "向", "为", "但"]), "虚词含 有/从/向/为/但")
        expect(ZhEnPolicy.functionWords.contains("的"), "虚词含 的")

        // 分段守卫
        expect(ZhEnPolicy.allowsSegmentation(segments: ["看", "电视"], allTranslated: true), "看+电视(全译)->允许")
        expect(!ZhEnPolicy.allowsSegmentation(segments: ["我们", "的"], allTranslated: true), "我们+的->禁止(封死 we of)")
        expect(!ZhEnPolicy.allowsSegmentation(segments: ["我", "喜欢", "吃"], allTranslated: true), "段数>2->禁止")
        expect(!ZhEnPolicy.allowsSegmentation(segments: ["我们", "老师"], allTranslated: false), "有段无译->禁止")

        if failures > 0 {
            print("SELFTEST FAILED (\(failures) 项)")
            exit(1)
        }
        print("SELFTEST PASSED")
    }
}
