# 1.66 翻译改动 前后对比（离线模拟 KeyboardModel.translate）

## 1) eval_gold(zh→en) 命中率改前/改后
- 改前(1.65)：116/118 = 98.3%
- 改后(1.66)：116/118 = 98.3%
- 结论：不降（持平或提升）

## 2) 表外新句/护栏 用例（旧 → 新）
| 输入 | 1.65 旧结果 | 1.66 新结果 | 说明 |
|---|---|---|---|
| 我在干什么 | I am what are you doing? | What am I doing | 补整句 |
| 我在做什么 | I am to make what? | What am I doing | 补整句 |
| 我在干嘛 | I am what are you doing? | What am I doing | 补整句 |
| 我不回家 | I do not to return home | I'm not going home | 补整句 |
| 我在写代码 | I am to write code | （无） | 护栏拦住不硬拼 |
| 我在唱歌 | I am to sing a song | （无） | 护栏拦住不硬拼 |
| 我在打游戏 | I am to play a game | （无） | 护栏拦住不硬拼 |
| 他在看什么 | he at to look what? | （无） | 护栏拦住不硬拼 |
| 你昨天在哪 | you yesterday at where | （无） | 护栏拦住不硬拼 |

## 3) 改动清单
- `PhraseGlossary`：+我在干什么/我在做什么/我在干嘛/我在干嘛呢/我不回家/我在家/我在吃饭/我在忙
- `KeyboardModel.translate`：短语表 → **代词+在+动作 模板** → 精确查 → `segmentZh`
- `segmentZh`：多碎片含代词/系词(I am…/you are…)时**不硬拼，返回 nil（宁缺毋滥）**
- `KeyboardModel.backspace` / `render`：BUG-7/8b 状态机（同 1.65）
