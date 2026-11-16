#!/usr/bin/env python3
# 离线译词准确率评测：用黄金集检验随包 en2zh.txt / zh2en.txt 的命中率（不依赖真机）。
# 用法：python eval_glossary.py <en2zh.txt> <zh2en.txt> <goldDir> [ecdict.csv] [reportOut]
# 指标：
#   en→zh 首选：英文词查 en2zh 的短译是否命中黄金中文义（任一即可）
#   en→zh 前3 ：正确义是否落在 ECDICT 该词前 3 个义项内（需 ecdict.csv；衡量源数据前3覆盖）
#   zh→en 首选：中文词查 zh2en 的短译是否命中黄金英文义
#   zh→en 前3 ：N/A（离线无候选列表；需真机引擎出候选，另测）
import sys, re, csv

en2zh_p, zh2en_p, golddir = sys.argv[1], sys.argv[2], sys.argv[3]
ecdict_p = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4] != '-' else None
out_p = sys.argv[5] if len(sys.argv) > 5 else None

STRIP = re.compile(r'[\s。，、；：！？,. ;:!?（）()【】\[\]"“”‘’]')
def norm(s):
    return STRIP.sub('', (s or '').strip().lower())

def load_map(p):
    m = {}
    for ln in open(p, encoding='utf-8'):
        ln = ln.rstrip('\n')
        if not ln or '\t' not in ln: continue
        k, v = ln.split('\t', 1)
        m[k] = v
    return m

def match(gloss, expected):
    g = norm(gloss)
    if not g: return False
    for e in expected:
        en = norm(e)
        if not en: continue
        if g == en or g.startswith(en) or en in g or g in en:
            return True
    return False

def load_gold(p):
    rows = []
    for ln in open(p, encoding='utf-8'):
        ln = ln.rstrip('\n')
        if not ln or '\t' not in ln: continue
        q, ex = ln.split('\t', 1)
        rows.append((q.strip(), [x for x in ex.split('|') if x.strip()]))
    return rows

# ---- ECDICT 前3义项 ----
INFLECT = re.compile(r'(的过去式|的过去分词|的复数|的现在分词|的第三人称单数|的比较级|的最高级)')
POS = re.compile(r'^[A-Za-z]+\.\s*'); BRK = re.compile(r'^\[[^\]]*\]\s*'); PAREN = re.compile(r'[（(][^）)]*[）)]')
def first_n_senses(t, n=3):
    if not t: return []
    t = t.replace('\\n', '\n'); res = []
    for ln in t.split('\n'):
        ln = ln.strip()
        if not ln or ln[0] == '[' or INFLECT.search(ln): continue
        ln = POS.sub('', ln); ln = BRK.sub('', ln)
        for s in re.split(r'[,，;；、]', ln):
            s = PAREN.sub('', s).replace('…','').replace('...','').strip().rstrip('\r')
            if s.endswith('的') and len(s) > 1: s = s[:-1]
            if s and re.search(r'[\u4e00-\u9fff]', s) and s not in res:
                res.append(s)
        if len(res) >= n: break
    return res[:n]

ecd = {}
if ecdict_p:
    with open(ecdict_p, newline='', encoding='utf-8') as f:
        for row in csv.DictReader(f):
            w = (row.get('word') or '').strip().lower()
            if w and w not in ecd:
                ecd[w] = row.get('translation') or ''

en2zh = load_map(en2zh_p); zh2en = load_map(zh2en_p)
gold_en = load_gold(golddir + '/eval_gold_en2zh.tsv')
gold_zh = load_gold(golddir + '/eval_gold_zh2en.tsv')

lines = []
rows = []   # 原始逐词：(dir, query, data, expected, PASS/FAIL)
def emit(s):
    lines.append(s); print(s)

# en→zh
en_ok = 0; en_fail = []
for q, ex in gold_en:
    g = en2zh.get(q.lower(), '')
    ok = match(g, ex)
    rows.append(('en2zh', q, g, '|'.join(ex), 'PASS' if ok else 'FAIL'))
    if ok: en_ok += 1
    else: en_fail.append((q, g, '|'.join(ex)))
emit(f"[en→zh] 首选：{en_ok}/{len(gold_en)} = {100.0*en_ok/len(gold_en):.1f}%")

if ecd:
    en3_ok = 0; en3_fail = []
    for q, ex in gold_en:
        senses = first_n_senses(ecd.get(q.lower(), ''), 3)
        hit = any(match(s, ex) or match(ex[0] if ex else '', [s]) for s in senses) if senses else False
        # 更直观：正确义是否等于/包含在任一前3义项
        hit = any(any(norm(e) == norm(s) or norm(e) in norm(s) or norm(s) in norm(e) for e in ex) for s in senses)
        if hit: en3_ok += 1
        else: en3_fail.append((q, '|'.join(senses), '|'.join(ex)))
    emit(f"[en→zh] 前3义项：{en3_ok}/{len(gold_en)} = {100.0*en3_ok/len(gold_en):.1f}%")
else:
    emit("[en→zh] 前3义项：N/A（未提供 ecdict.csv）")

# zh→en
zh_ok = 0; zh_fail = []
for q, ex in gold_zh:
    g = zh2en.get(q, '')
    ok = match(g, ex)
    rows.append(('zh2en', q, g, '|'.join(ex), 'PASS' if ok else 'FAIL'))
    if ok: zh_ok += 1
    else: zh_fail.append((q, g, '|'.join(ex)))
emit(f"[zh→en] 首选：{zh_ok}/{len(gold_zh)} = {100.0*zh_ok/len(gold_zh):.1f}%")
emit("[zh→en] 前3：N/A（离线无候选列表；真机引擎出候选另测）")

emit("\n-- 失败样例（en→zh 首选）--")
for q,g,e in en_fail[:30]: emit(f"  {q}\t数据={g}\t期望={e}")
emit("\n-- 失败样例（zh→en 首选）--")
for q,g,e in zh_fail[:30]: emit(f"  {q}\t数据={g}\t期望={e}")
if ecd:
    emit("\n-- 失败样例（en→zh 前3）--")
    for q,s,e in en3_fail[:30]: emit(f"  {q}\t前3={s}\t期望={e}")

if out_p:
    open(out_p, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
    rows_p = out_p.rsplit('.', 1)[0] + '-逐词结果.tsv'
    with open(rows_p, 'w', encoding='utf-8') as f:
        f.write('dir\tquery\tdata\texpected\tresult\n')
        for d, q, g, e, r in rows:
            f.write(f'{d}\t{q}\t{g}\t{e}\t{r}\n')
    print('report ->', out_p, '; rows ->', rows_p)
