// 把 CC-CEDICT 原始 .u8 词表打包成两份「前缀排序」的译词表：
//   zh2en.txt  "简体\t英文释义"   （中→英）
//   en2zh.txt  "英文首义(lower)\t简体" （英→中）
// 供扩展 mmap 前缀查（Cedict）。CC-CEDICT 许可 = CC BY-SA 4.0，须署名＋同许可提供数据。
// 用法：node gen_cedict.js <cedict_ts.u8 路径> <输出目录>
const fs = require('fs');
const path = require('path');

const src = process.argv[2];
const outDir = process.argv[3] || '.';
if (!src) { console.error('usage: node gen_cedict.js <cedict.u8> <outDir>'); process.exit(1); }

const text = fs.readFileSync(src, 'utf8');
const lines = text.split(/\r?\n/);
const zh2en = new Map();   // simp -> gloss
const en2zh = new Map();   // english(lower) -> simp

const re = /^(\S+)\s+(\S+)\s+\[([^\]]*)\]\s+\/(.+)\/$/;
for (const ln of lines) {
  if (!ln || ln[0] === '#') continue;
  const m = ln.match(re);
  if (!m) continue;
  const simp = m[2];
  const glosses = m[4].split('/').map(s => s.trim()).filter(Boolean);
  if (glosses.length === 0) continue;
  // 中→英：简体做键，取首个释义的第一个分句（简洁、贴近"译词"）
  const short = glosses[0].split(';')[0].trim();
  if (!zh2en.has(simp) && short) zh2en.set(simp, short);
  // 英→中：把该词所有释义按 ; , 拆成短词/短语，逐个建索引
  for (const gl of glosses) {
    for (let piece of gl.toLowerCase().split(/[;,]/)) {
      piece = piece.replace(/^to\s+/, '').trim();
      if (piece && piece.length <= 40 && /^[a-z][a-z '\-]*$/.test(piece) && !en2zh.has(piece)) en2zh.set(piece, simp);
    }
  }
}

function writeMap(map, name) {
  const keys = [...map.keys()].sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));
  const out = keys.map(k => k + '\t' + map.get(k)).join('\n') + '\n';
  fs.writeFileSync(path.join(outDir, name), out, 'utf8');
  console.log(name, keys.length, 'entries,', Buffer.byteLength(out), 'bytes');
}
writeMap(zh2en, 'zh2en.txt');
writeMap(en2zh, 'en2zh.txt');
