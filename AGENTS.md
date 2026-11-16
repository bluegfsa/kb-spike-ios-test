# AGENTS.md — 青简·双译键盘（kb-spike）开发规范

> 本仓库是「青简·双译键盘」iOS 键盘扩展原型（Swift + UIKit + librime）。任何 AI 或人动手前先读完。
> 目标：不产出屎山——靠结构、拆分、注释与评审卡住，而不是靠记忆。

## 1. 技术栈与目录

- Swift 5.9 / UIKit，iOS 15+。宿主 App target `KBSpike`，键盘扩展 target `KBSpikeKeyboard`。
- `Keyboard/`：键盘扩展（`KeyboardViewController`、`KeyboardView`、`KeyboardViewStyle`、`KeyboardModel`、`RimeProbe.*`、词库 yaml 等）。
- `App/`：宿主 App（首次初始化引导）。`tools/`：生成打字词库脚本。`docs/`：架构与行为规格（唯一真相源）。
- 构建工程由 `project.yml`（XcodeGen）生成，`sources: [Keyboard]` 自动纳入新文件。

## 2. 分层与依赖（单向，禁止反向）

- 视图/控制器 → **只依赖 `KeyboardModeling` 协议**，不直接碰 `RimeEngine`/`Cedict`/词库；引擎实现归架构师，替换实现时 UI 零改动。
- 配色/按钮等辅助类型放 `KeyboardViewStyle.swift`；行布局等可分文件用 extension，共享成员用 `internal`。

## 3. 硬性规则（违反即打回，不讨论）

1. Swift 严格类型；**不用强解包 `!`**（IBOutlet 等确知非空须注释说明）；不吞错误、不静默失败。
2. **单文件 ≤400 行、单类型 ≤300 行**；超了就拆（新建文件或分 extension 文件），不许忍。确需豁免须**架构师＋评审官双签**。
3. 关键类型与公开方法写**中文注释**（用途/参数/返回）。
4. 一个文件/类型只做一件事：视图、控制器、模型不混。
5. **不写死键盘高度**：按内容＋`view.safeAreaInsets.bottom` 自适应（#2/#3）。
6. **地球键（#4）按用户 2026-11-16 死命令删除**：键盘内不再渲染 🌐 / 不调 `advanceToNextInputMode()`（`a446cc5` 起已删，勿再加回）。删后必须在真机确认「能切回系统键盘/其他键盘」——若实测切不出去，立即回报用户并把地球键加回（用户原话：切不出去告诉我）。不得仅凭推断认定可/不可切回。**注意：真机切得回 ≠ Apple 审核会过**（这台能切可能只是系统另给了入口），上架提审前以审核结果为准，不得把"真机可切回"当作"审核已安全"。
7. 密钥、证书、第三方私有素材一律不入库、不抠别人 UI 素材（照样式自绘）。
8. 严格照 `docs/` 的架构契约与按键行为规格实现；与设计有偏差要在 PR/回复里说明原因。

## 4. 构建与验证（本机无 Xcode）

- 走 GitHub Actions：`.github/workflows/kb-spike-ios.yml`（push `main` 触发）用 macOS `xcodebuild` 出 **unsigned ipa**，真机侧载验证。
- **不改 `.github/workflows`**（当前 token 无 workflow 权限，会 403；要改找董事长授权）。
- 提交前：**编译须绿（CI run success）**；UI 改动须真机侧载确认视觉与手感。
- 不谎报验证：mock 阶段只能验 UI/交互＋唤出；真拼音出字/真译词/内存指标等引擎能力以实机为准，没验就不说"通过"。

## 5. 提交与评审

- commit 格式：`feat|fix|refactor|test|docs|chore(kb-spike): 说明`；小步提交，一提交一件事。
- 任何交付物出包/交用户前，必须经 **@评审官** 按 PRD/规格逐条核查，结论三选一：通过 / 需修改 / 打回；打回由原岗位返工。

## 6. 变更记录

| 日期 | 变更 | 双签 |
|---|---|---|
| 2026-11-15 | 建库规范（评审官要求补 AGENTS.md） | 待架构师＋评审官双签 |
| 2026-11-16 | §3.6 改：地球键按用户死命令删除（撤销"必须保留"旧口径），删后须真机验能否切回、不行则加回并回报用户；补"真机切得回≠审核必过、以提审结果为准" | 架构师＋评审官双签 |
