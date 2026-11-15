// 生成一份「前缀排序」的文本词典，供扩展用 mmap(file-backed, clean) 读取 + 前缀二分查找。
// 仅 spike 用：合成 3 万条 + 少量真实样例。真实项目换成 CC-CEDICT 裁常用。
const fs = require('fs');
const path = require('path');
const n = 30000;
const rows = [];
for (let i = 0; i < n; i++) {
  const w = 'w' + String(i).padStart(5, '0');
  rows.push(w + '\t译' + i);
}
rows.push('hello\t你好');
rows.push('hello\thola');
rows.push('helper\t助手');
// 按「键」排序，保证前缀查找落在连续区间
rows.sort((a, b) => {
  const ka = a.split('\t')[0];
  const kb = b.split('\t')[0];
  return ka < kb ? -1 : ka > kb ? 1 : 0;
});
fs.mkdirSync('Keyboard', { recursive: true });
const out = path.join('Keyboard', 'dict.txt');
fs.writeFileSync(out, rows.join('\n') + '\n', 'utf8');
console.log('dict.txt written:', rows.length, 'entries ->', out);
