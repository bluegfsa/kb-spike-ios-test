// S4b 起不再需要合成 dict.txt（探针版已纯 librime，无合成演示）。
// 保留此脚本仅为工作流 "node tools/gen_dict.js" 步骤不报错：输出到临时目录，不进 appex。
const fs = require('fs');
const os = require('os');
const path = require('path');
const out = path.join(os.tmpdir(), 'dict.txt');
fs.writeFileSync(out, 'skipped\n', 'utf8');
console.log('gen_dict: skipped (no synthetic dict bundled) ->', out);
