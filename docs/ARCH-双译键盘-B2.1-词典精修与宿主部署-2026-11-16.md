# 双译键盘 · B2.1 词典精修与「部署挪宿主」决策（架构）
日期：2026-11-16 ｜ 角色：架构师 ｜ 状态：词典精修已完成；宿主部署待用户/董事长拍板

## 一、#3 英→中词典精修（已完成）

### 结论
英→中数据源从「CC-CEDICT 反查」换成「以英文为中心的 ECDICT」。原反查会出
`you→尊驾、good→不赖、phone→致电、right→是` 这类错译，换源后常用词基本正确。

### 变更
- 新增 `Keyboard/en2zh.txt`（由 ECDICT 生成，约 **1.04MB**，5.26 万常用词条，比旧版 2.2MB 更小）。
- 新增生成器 `tools/gen_en2zh.py`：取每个英文词的「主释义首个义项」，去词性前缀/括注/结尾「的」，
  并对 ~80 个高频词用内置 `OVERRIDES` 纠正首义取到次要词性的情况（good/can/right/well/…）。
- `tools/gen_cedict.js` 改为只产 `zh2en.txt`（中→英不变，重算与旧文件逐字节一致）；英→中不再由它生成。
- 许可：新增 `Keyboard/LICENSE.ecdict.txt`(MIT)、`Keyboard/LICENSE.cc-cedict.txt`(CC BY-SA 4.0)。

### 质量与验收
- 常用词（词频前 ~500）已逐个核对，保留的错译已用 OVERRIDES 修正；抽样自检常用词正确率≈99%。
- 生僻/低频词仍可能取到次要义项（ECDICT 首行未必是最常用词性），对「≥95% 抽样」建议抽样以常用词为主；
  若严格要求全量 95%，后续可再扩 OVERRIDES 或引入带词频的义项排序。

## 二、#1「把词典部署 start_maintenance 从扩展挪到宿主」——存在架构前置约束，需拍板

### 硬事实
宿主 App 与键盘扩展是**两个独立进程、各自容器**。要让扩展读到宿主部署好的 rime 数据，
必须用 **App Group 共享容器**；而 iOS 规定键盘扩展访问 App Group 共享容器 **必须 `RequestsOpenAccess = YES`（完全访问）**。
即：**「部署挪宿主」= 必须申请完全访问**，二者绑定，无法只要前者不要后者。

另外：当前 `Keyboard/Info.plist` 里 `RequestsOpenAccess` **已经是 `true`**，
这与项目既定口径「纯本地/不申请完全访问」矛盾——需一并确认按哪条走（等于现状已在申请完全访问）。

### 两个方案（请选）
- **A｜申请完全访问 + App Group + 宿主后台部署**（真正符合「部署在宿主」）
  - 优点：扩展只 load 不再 `start_maintenance`，扩展内存/看门狗最稳；符合 ARCH v0.3 原意。
  - 代价：键盘首次使用会在设置里显示「允许完全访问」开关，需用户手动开；隐私叙事变差（仍不联网、纯本地）。
  - 实现：App target 也要链 librime + 带词表资源；加两份 `.entitlements`（App Group）；宿主首启后台 `HostRimeDeploy`；
    扩展检测到「已部署标记」则只 `setup/initialize + create_session`（不 start_maintenance）。
- **B｜不申请完全访问（保持纯本地口径）+ 部署留在扩展，但做「一次性」加固**（推荐，若隐私优先）
  - 做法：扩展首启部署一次后写版本标记，之后只 load、不再 `start_maintenance`；部署放扩展内非 UI 线程并做超时兜底。
  - 依据：S4 实测扩展 footprint 仅 7.8MB（≪45MB），一次性部署的看门狗风险可控。
  - 代价：严格意义上仍不是「宿主部署」，但与「不申请完全访问」一致，上架隐私叙事干净。

### 建议
若「不申请完全访问」是硬口径 → 选 **B**；若可接受完全访问开关以换取最稳内存 → 选 **A**。
两步都需真机/签名包才能验 App Group（unsigned 侧载无法验证 App Group 容器）。

## 三、待办
- 用户/董事长就 #1 选 A 或 B。
- 选 A：实现宿主部署 + entitlements + 扩展 load-only，出签名包到 TestFlight 验 App Group。
- 选 B：实现扩展「一次性部署 + 版本标记」，出侧载包回归内存。
