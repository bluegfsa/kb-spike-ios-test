// 把 CC-CEDICT 原始 .u8 词表打包成两份「前缀排序」的译词表：
//   zh2en.txt  "简体\t英文释义"        （中→英）
//   en2zh.txt  "英文首义(lower)\t简体"  （英→中）
// 供扩展 mmap 前缀查（Cedict）。CC-CEDICT 许可 = CC BY-SA 4.0（见 LICENSE.cc-cedict.txt，须署名＋同许可）。
//
// v2 变更：英→中原本「取文件中第一条」会出 you→尊驾、good→不赖、phone→致电 这类错译。
//   改为「按 rime 拼音词库的用词频率权重排序」：同一英文释义的全部候选中文里，取在
//   pinyin_simp.dict.yaml 中权重最高（最常见）的那个；权重相同再按「首义优先→字短优先→先到优先」。
//
// 用法：node gen_cedict.js <cedict_ts.u8> <输出目录> [rime词库yaml]
const fs = require('fs');
const path = require('path');

const src = process.argv[2];
const outDir = process.argv[3] || '.';
if (!src) { console.error('usage: node gen_cedict.js <cedict.u8> <outDir> [pinyin_simp.dict.yaml]'); process.exit(1); }

let dictPath = process.argv[4]
  || path.join(outDir, 'pinyin_simp.dict.yaml');
if (!fs.existsSync(dictPath)) {
  const alt = path.join(__dirname, '..', 'Keyboard', 'pinyin_simp.dict.yaml');
  if (fs.existsSync(alt)) dictPath = alt;
}

// —— 1. 读 rime 词库权重：simp -> weight —— //
const weight = new Map();
if (fs.existsSync(dictPath)) {
  const lines = fs.readFileSync(dictPath, 'utf8').split(/\r?\n/);
  let inBody = false;
  for (const ln of lines) {
    if (!inBody) { if (ln.trim() === '...') inBody = true; continue; }
    if (!ln) continue;
    const parts = ln.split('\t');
    if (parts.length < 3) continue;
    const simp = parts[0];
    if (!simp || simp.indexOf('?') >= 0) continue; // 跳过编码噪声
    const w = parseInt(parts[parts.length - 1], 10);
    if (!Number.isFinite(w)) continue;
    if (!weight.has(simp) || w > weight.get(simp)) weight.set(simp, w);
  }
  console.log('rimedict:', dictPath, '->', weight.size, 'weighted words');
} else {
  console.warn('WARN: 未找到 rime 词库，英→中退回"首义+字短"排序（可能仍不准）:', dictPath);
}

// —— 2. 遍历 CC-CEDICT —— //
const text = fs.readFileSync(src, 'utf8');
const lines = text.split(/\r?\n/);
const zh2en = new Map();          // simp -> gloss
const en2zh = new Map();          // english(lower) -> { simp, w, primary }

const re = /^(\S+)\s+(\S+)\s+\[([^\]]*)\]\s+\/(.+)\/$/;

// 英→中候选比较：权重高者胜；同权重「首义优先→字短优先」；并列保留先到。
function consider(piece, simp, w, primary) {
  const cur = en2zh.get(piece);
  if (!cur) { en2zh.set(piece, { simp, w, primary }); return; }
  let better = false;
  if (w !== cur.w) better = w > cur.w;
  else if (primary !== cur.primary) better = primary > cur.primary;
  else if (simp.length !== cur.simp.length) better = simp.length < cur.simp.length;
  if (better) en2zh.set(piece, { simp, w, primary });
}

let parsed = 0;
for (const ln of lines) {
  if (!ln || ln[0] === '#') continue;
  const m = ln.match(re);
  if (!m) continue;
  parsed++;
  const simp = m[2];
  if (!simp || simp.indexOf('?') >= 0) continue;
  const glosses = m[4].split('/').map(s => s.trim()).filter(Boolean);
  if (glosses.length === 0) continue;

  // 中→英：简体做键，取首个释义的第一个分句（简洁、贴近"译词"）
  const short = glosses[0].split(';')[0].trim();
  if (!zh2en.has(simp) && short) zh2en.set(simp, short);

  // 英→中：把每条释义拆成「英文单词」与「短语块」两类候选，按频率权重择优。
  //   单词匹配（token）能覆盖 you(informal)/telephone; phone call 这类带括注或多义的释义；
  //   短语块（按 ; , 切）覆盖 phone call / good morning 这类整段短语。
  const w = weight.get(simp) || 0;
  for (let gi = 0; gi < glosses.length; gi++) {
    const gl = glosses[gi].toLowerCase();
    const primary = gi === 0 ? 1 : 0;
    // 1) 单词 token
    const tokens = gl.match(/[a-z][a-z'\-]*/g) || [];
    for (const tk of tokens) {
      if (tk.length < 1 || tk.length > 30) continue;
      consider(tk, simp, w, primary);
    }
    // 2) 短语块（去掉 to/a/an/the 前缀后整体作为一个键）
    for (let piece of gl.split(/[;,]/)) {
      piece = piece.replace(/^to\s+/, '').replace(/^(a|an|the)\s+/, '')
        .replace(/\([^)]*\)/g, ' ').replace(/\s+/g, ' ').trim();
      if (!piece || piece.length > 40) continue;
      if (!/^[a-z][a-z '\-]*$/.test(piece)) continue;
      if (piece.indexOf(' ') >= 0) consider(piece, simp, w, primary);
    }
  }
}

function writeMap(map, name, val) {
  const keys = [...map.keys()].sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));
  const out = keys.map(k => k + '\t' + val(map.get(k))).join('\n') + '\n';
  fs.writeFileSync(path.join(outDir, name), out, 'utf8');
  console.log(name, keys.length, 'entries,', Buffer.byteLength(out), 'bytes');
}
writeMap(zh2en, 'zh2en.txt', v => v);
// 注意：en2zh.txt 不再由本脚本生成——英→中改用英文为中心的 ECDICT（见 tools/gen_en2zh.py），
// CC-CEDICT 反查会出 you→尊驾 这类错译。本脚本只负责 zh2en.txt（中→英）。
console.log('parsed CC-CEDICT lines:', parsed);
