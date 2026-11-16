// 生成 zh2en.txt（中→英短译表），供扩展 mmap 前缀查（Cedict）。
// CC-CEDICT 许可 = CC BY-SA 4.0（见 LICENSE.cc-cedict.txt，须署名＋同许可）。英→中见 gen_en2zh.py。
//
// v3 变更（修评测发现的 70% 问题）：CC-CEDICT 同一简体字常有多条（surname/variant/abbr/多音字），
//   旧逻辑取「文件中第一条」常取到 surname Shui、abbr. for…、读[dou4]=comma 这类错义。
//   改为对每个简体字在候选条目中择优：
//     ① 优先「实义条目」——剔除 surname / variant of / old variant / archaic / abbr. / short name / used in / see also / CL: 等；
//     ② 其次对齐 rime 词库的**常用读音**（如 读 取 du→to read，而非 dou→comma）；
//     ③ 再按「先到先得」。
//
// 用法：node gen_cedict.js <cedict_ts.u8> <输出目录> [rime词库yaml]
const fs = require('fs');
const path = require('path');

const src = process.argv[2];
const outDir = process.argv[3] || '.';
if (!src) { console.error('usage: node gen_cedict.js <cedict.u8> <outDir> [pinyin_simp.dict.yaml]'); process.exit(1); }

let dictPath = process.argv[4] || path.join(outDir, 'pinyin_simp.dict.yaml');
if (!fs.existsSync(dictPath)) {
  const alt = path.join(__dirname, '..', 'Keyboard', 'pinyin_simp.dict.yaml');
  if (fs.existsSync(alt)) dictPath = alt;
}

// —— 读 rime 词库：simp -> {weight, pinyin(常用的)} —— //
const rime = new Map();
if (fs.existsSync(dictPath)) {
  let inBody = false;
  for (const ln of fs.readFileSync(dictPath, 'utf8').split(/\r?\n/)) {
    if (!inBody) { if (ln.trim() === '...') inBody = true; continue; }
    if (!ln) continue;
    const p = ln.split('\t');
    if (p.length < 3) continue;
    const w0 = p[0];
    if (!w0 || w0.indexOf('?') >= 0) continue;
    const w = parseInt(p[p.length - 1], 10);
    if (!Number.isFinite(w)) continue;
    const py = normPy(p[1] || '');
    const cur = rime.get(w0);
    if (!cur || w > cur.weight) rime.set(w0, { weight: w, pinyin: py });
  }
  console.log('rimedict:', dictPath, '->', rime.size, 'words');
} else {
  console.warn('WARN: 未找到 rime 词库，仅按实义优先排序:', dictPath);
}

function normPy(s) {
  return s.toLowerCase().replace(/[^a-z]/g, '');
}

// 载入英→中表做「反向校验」：某英文义的首词若在 en2zh 里回指本简体字，则强信号优先。
const en2zhMap = new Map();
let enPath = path.join(outDir, 'en2zh.txt');
if (!fs.existsSync(enPath)) enPath = path.join(__dirname, '..', 'Keyboard', 'en2zh.txt');
if (fs.existsSync(enPath)) {
  for (const ln of fs.readFileSync(enPath, 'utf8').split(/\r?\n/)) {
    const t = ln.indexOf('\t');
    if (t > 0) en2zhMap.set(ln.slice(0, t), ln.slice(t + 1));
  }
  console.log('en2zh for back-check:', en2zhMap.size, 'entries');
}
function backMatch(gloss, simp) {
  const g = (gloss || '').replace(/^to\s+/, '').toLowerCase();
  const mm = g.match(/^[a-z][a-z'\-]*/);
  if (!mm) return 0;
  return en2zhMap.get(mm[0]) === simp ? 1 : 0;
}

// 判断是否为「元信息」释义（surname/variant/abbr/旧读/量词等），应降级
const META = /(^|\/)(surname\b|variant of|old variant|archaic|abbr\.|short name for|used in|see also|CL:|classifier)/i;
function isMeta(shortGloss, allGlosses) {
  const s = (shortGloss || '').toLowerCase();
  if (/^surname\b/.test(s)) return true;
  if (/^(variant of|old variant|abbr\.|short name for|used in|see also)\b/.test(s)) return true;
  if (/^CL:/.test(s)) return true;
  // 只有这些元信息、没有实义
  if (allGlosses.every(g => /(surname|variant of|old variant|archaic|abbr\.|short name for|used in|see also|^CL:)/i.test(g))) return true;
  return false;
}

const re = /^(\S+)\s+(\S+)\s+\[([^\]]*)\]\s+\/(.+)\/$/;
const best = new Map(); // simp -> {gloss, nonMeta, pyMatch, order}
let order = 0, parsed = 0;

function consider(simp, gloss, py, allGlosses) {
  order++;
  const nonMeta = isMeta(gloss, allGlosses) ? 0 : 1;
  const r = rime.get(simp);
  const pyMatch = (r && r.pinyin && py && r.pinyin === py) ? 1 : 0;
  const back = backMatch(gloss, simp);
  const cur = best.get(simp);
  const cand = { gloss, nonMeta, back, pyMatch, order };
  if (!cur) { best.set(simp, cand); return; }
  // 排序：实义优先 > 反查回指优先 > 读音匹配优先 > 先到
  const keys = ['nonMeta', 'back', 'pyMatch'];
  for (const k of keys) {
    if (cand[k] !== cur[k]) { if (cand[k] > cur[k]) best.set(simp, cand); return; }
  }
  // 相等则保留先到（不覆盖）
}

for (const ln of fs.readFileSync(src, 'utf8').split(/\r?\n/)) {
  if (!ln || ln[0] === '#') continue;
  const m = ln.match(re);
  if (!m) continue;
  parsed++;
  const simp = m[2];
  if (!simp || simp.indexOf('?') >= 0) continue;
  const glosses = m[4].split('/').map(s => s.trim()).filter(Boolean);
  if (!glosses.length) continue;
  const short = glosses[0].split(';')[0].trim();
  if (!short) continue;
  consider(simp, short, normPy(m[3] || ''), glosses);
}

const zh2en = new Map();
for (const [k, v] of best) zh2en.set(k, v.gloss);
// 常用多义/歧义字的确定性纠正（CC-CEDICT 分词条目难以自动判主义时，人工给定常用义）
const ZH_OVERRIDES = {
  '睡觉': 'sleep', '关': 'close', '热': 'hot', '钱': 'money', '快': 'fast',
  '月': 'month', '门': 'door', '给': 'give', '跑': 'run', '帮助': 'help',
  '读': 'to read', '说': 'to speak', '听': 'to listen', '看': 'to look',
  '先生': 'Mr.', '井': 'well', '革命': 'revolution',
  '在别处': 'elsewhere', '广告业': 'advertising',
};
for (const k in ZH_OVERRIDES) zh2en.set(k, ZH_OVERRIDES[k]);
const keys = [...zh2en.keys()].sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));
const out = keys.map(k => k + '\t' + zh2en.get(k)).join('\n') + '\n';
fs.writeFileSync(path.join(outDir, 'zh2en.txt'), out, 'utf8');
console.log('zh2en.txt', keys.length, 'entries,', Buffer.byteLength(out), 'bytes; parsed', parsed);
