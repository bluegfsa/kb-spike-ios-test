# 1.66 翻译评测（护栏已收窄，不误杀正常句）

## 1) eval_gold(zh→en) 改前/改后
- 改前：116/118 = 98.3%
- 改后：116/118 = 98.3%
- 结论：不降

## 2) 正常多词句（应译出，验证不误杀）
| 输入 | 1.65 旧 | 1.66 新 |
|---|---|---|
| 我爱你 | I love you | I love you |
| 我是学生 | I am student | I am a student |
| 他在家 | he to be at home | he is at home |
| 我们在吃饭 | we at to have a meal | we are eating |
| 我在家 | I am home | I'm at home |
| 我在吃饭 | I am to have a meal | I'm eating |
| 你好吗 | How are you | How are you |
| 谢谢你 | Thank you | Thank you |

## 3) 错义/护栏（表外新句）
| 输入 | 1.65 旧 | 1.66 新 |
|---|---|---|
| 我在干什么 | I am what are you doing? | What am I doing |
| 我在做什么 | I am to make what? | What am I doing |
| 我不回家 | I do not to return home | I'm not going home |
| 我在写代码 | I am to write code | I am to write code |
| 我在唱歌 | I am to sing a song | I am to sing a song |
| 他在看什么 | he at to look what? | （无） |
| 你昨天在哪 | you yesterday at where | （无） |
