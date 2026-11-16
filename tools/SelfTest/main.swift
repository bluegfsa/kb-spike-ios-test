import Foundation
import Darwin

// 键盘纯逻辑自检（CI 上以 swiftc 编译运行；断言失败 → 构建失败）。
// 直接编译 Keyboard/KeyboardLogic.swift，测的就是 App 用的同一份代码。

var failures = 0
func expect(_ cond: Bool, _ msg: String) {
    if cond {
        print("ok: \(msg)")
    } else {
        failures += 1
        print("FAIL: \(msg)")
    }
}

// 1) #12 标点 5 键组：中文全角「，。？！、」↔ 英文半角「, . ? ! ,」，顿号→逗号
expect(KeyboardLogic.punctuationGlyph(fullWidth: true, index: 0) == "，", "全角[0]=，")
expect(KeyboardLogic.punctuationGlyph(fullWidth: true, index: 1) == "。", "全角[1]=。")
expect(KeyboardLogic.punctuationGlyph(fullWidth: true, index: 2) == "？", "全角[2]=？")
expect(KeyboardLogic.punctuationGlyph(fullWidth: true, index: 3) == "！", "全角[3]=！")
expect(KeyboardLogic.punctuationGlyph(fullWidth: true, index: 4) == "、", "全角[4]=、")
expect(KeyboardLogic.punctuationGlyph(fullWidth: false, index: 0) == ",", "半角[0]=,")
expect(KeyboardLogic.punctuationGlyph(fullWidth: false, index: 1) == ".", "半角[1]=.")
expect(KeyboardLogic.punctuationGlyph(fullWidth: false, index: 2) == "?", "半角[2]=?")
expect(KeyboardLogic.punctuationGlyph(fullWidth: false, index: 3) == "!", "半角[3]=!")
expect(KeyboardLogic.punctuationGlyph(fullWidth: false, index: 4) == ",", "半角[4]=,(顿号→逗号)")
expect(KeyboardLogic.punctuationGlyph(fullWidth: true, index: 99) == "", "越界返空")

// 2) #14 连删间隔：0.12 起、每步 ×0.85、封底 0.03
var interval = 0.12
var steps: [Double] = []
for _ in 0..<30 { interval = KeyboardLogic.nextDeleteInterval(from: interval); steps.append(interval) }
expect(abs(steps[0] - 0.102) < 1e-9, "首档=0.102")
expect(steps.allSatisfy { $0 >= 0.03 }, "全程≥0.03（不越下界）")
expect(steps.last! == 0.03, "最终触底 0.03")
expect(KeyboardLogic.nextDeleteInterval(from: 0.031) == 0.03, "接近底值收敛到 0.03")
var increasingGapOk = true
for i in 1..<steps.count where steps[i] > steps[i - 1] { increasingGapOk = false }
expect(increasingGapOk, "间隔单调不增（由慢到快）")

// 3) #10 字母大小写：中文恒小写；英文无 shift 小写；英文有 shift 大写
expect(KeyboardLogic.letter("a", isChinese: true, shift: true) == "a", "中文态恒小写(即使 shift)")
expect(KeyboardLogic.letter("a", isChinese: true, shift: false) == "a", "中文态小写")
expect(KeyboardLogic.letter("a", isChinese: false, shift: false) == "a", "英文无shift小写")
expect(KeyboardLogic.letter("a", isChinese: false, shift: true) == "A", "英文shift大写")
expect(KeyboardLogic.letter("z", isChinese: false, shift: true) == "Z", "英文shift大写 z→Z")

if failures > 0 {
    print("SELFTEST FAILED (\(failures) 项)")
    exit(1)
}
print("SELFTEST PASSED")
