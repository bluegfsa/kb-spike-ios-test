# 键音说明（Keyboard/Sounds）

`1_normal.wav`（普通键音）、`2_delete.wav`（删除键音）由本项目用脚本 `tools/gen_keysounds.py`
**程序化合成**，原创、**无第三方素材、免版权**，可随 App 自由分发。

- 格式：单声道 16-bit PCM WAV / 48 kHz / ~35–45 ms
- 生成：在仓库根运行 `python tools/gen_keysounds.py`
- 变更记录：2026-11-23 —— 原 `1_normal.wav`/`2_delete.wav` **来源与授权不明**（仓库内无任何来源/许可说明），
  已替换为上述自合成音，补齐审计缺口（键音授权），此后随包发布的键音均为本项目原创。
