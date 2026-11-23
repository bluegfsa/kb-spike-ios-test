# LICENSES — 语桥输入法 / WordBridge 第三方许可（随包）

本目录收录 App（含键盘扩展 `KBSpikeKeyboard`，静态链接 librime 及其依赖）所分发的第三方库**官方许可全文**与署名索引。

- 全文来源：上游 `ghostflyby/librime-xcframework@1.17.0-pack.10.0.0` 的 `third-party-notices/`（权威，未手抄）。
- 用途：满足 BSD/MIT/Apache/BSL/zlib 许可的「随分发附版权与许可声明」义务；App「关于/开源许可」页展示本索引。

## 组件索引（全部静态编入 appex 可执行，必须署名）

| # | 组件 | 版本 | 许可 | 版权 / 上游 | 全文文件 |
|---|---|---|---|---|---|
| 1 | librime（Rime 引擎） | 1.17.0 | BSD-3-Clause | © 2014 RIME Developers · github.com/rime/librime | `THIRD_PARTY_NOTICES-librime.md` |
| 2 | librime-lua（插件） | commit ad1e4a6 | BSD-3-Clause | © 2021 librime-lua Developers · hchunhui/librime-lua | `third-party-notices/plugins/lua.txt` |
| 3 | librime-octagram（插件） | commit 57d18b9 | BSD-3-Clause（2026-07 由 GPLv3 重许可，现为 BSD-3） | © 2014 RIME Developers · lotem/librime-octagram | `third-party-notices/plugins/octagram.txt` |
| 4 | librime-predict（插件） | commit 920bd41 | BSD-3-Clause | © 2023 RIME Developers · rime/librime-predict | `third-party-notices/plugins/predict.txt` |
| 5 | logsink / varpage（本地插件） | 同打包仓 | BSD-3-Clause | ghostflyby/librime-xcframework | `THIRD_PARTY_NOTICES-librime.md` |
| 6 | darts-clone | 0.32 | BSD-3-Clause（另可选 LGPL-2.1 双许可） | © 2008-2013 Susumu Yata · s-yata/darts-clone | `third-party-notices/vcpkg/darts-clone.txt` |
| 7 | utf8-cpp | — | Boost Software License 1.0 | © 2006 Nemanja Trifunovic · nemtrif/utfcpp | `third-party-notices/librime/utf8-cpp.txt` |
| 8 | Lua（运行时） | 5.4.8 | MIT | lua.org（vcpkg override 5.4.8） | `third-party-notices/vcpkg/lua.txt` |
| 9 | leveldb | 1.23 | BSD-3-Clause | © Google · google/leveldb | `third-party-notices/vcpkg/leveldb.txt` |
| 10 | marisa-trie | 0.3.1 | BSD-2-Clause（另可选 LGPL-2.1 双许可） | © Susumu Yata · s-yata/marisa-trie | `third-party-notices/vcpkg/marisa-trie.txt` |
| 11 | OpenCC（含转换数据） | 1.1.9 | Apache-2.0 | © BYVoid · BYVoid/OpenCC | `third-party-notices/vcpkg/opencc.txt` |
| 12 | yaml-cpp | 0.9.0 | MIT | © jbeder · jbeder/yaml-cpp | `third-party-notices/vcpkg/yaml-cpp.txt` |
| 13 | glog | 0.7.1 | BSD-3-Clause | © Google · google/glog | `third-party-notices/vcpkg/glog.txt` |
| 14 | gflags | 2.3.0 | BSD-3-Clause | © Google · gflags/gflags | `third-party-notices/vcpkg/gflags.txt` |
| 15 | boost（algorithm/crc/interprocess/regex/scope-exit/signals2/uuid/vmd 等） | 1.91.0 | Boost Software License 1.0 | boost.org | `third-party-notices/vcpkg/boost-*.txt` |
| 16 | zlib（系统 libz，`-lz`） | iOS SDK 随附 | zlib License | Jean-loup Gailly / Mark Adler | 系统库不随包分发；如审核要求见 zlib.net/zlib_license.html |

> 全部为 BSD/MIT/Apache/BSL/zlib，**无 GPL/AGPL**（octagram 已为 BSD-3 pin）。`third-party-notices/` 另含 `boost-*` 全组件与 `rapidjson/tclap`（opencc 构建期依赖）等超集，整目录随包不影响。

## 修改记录

| 日期 | 变更 |
|---|---|
| 2026-11-23 | 建立：从上游 `librime-xcframework@1.17.0-pack.10.0.0` 取 65 份官方许可全文；本索引对 16 类组件署名（zlib 为系统库） |
