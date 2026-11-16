#!/usr/bin/env python3
# 生成「常用词人工校正核心词表」初稿：en2zh 核心覆盖（word\t中文主义）。
# 规则（防怪义）：对每个词的 ECDICT 候选义，只接受「CC-CEDICT 能反查回该英文词」的义（round-trip 校验），
#   在通过校验的候选里取 rime 词频最高、优先多字词；若一个都校验不过 → 留空（暂无译词，宁缺毋滥，不出怪义）。
# 词表按 ECDICT frq（越低越常用）取前 N。
# 用法：python gen_core_glossary.py <ecdict.csv> <cedict.u8> <pinyin_simp.dict.yaml> <N> <out.tsv>
import csv, re, sys
ecdict_p, cedict_u8, dictp, N, out = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), sys.argv[5]
INFLECT=re.compile(r'(的过去式|的过去分词|的复数|的现在分词|的第三人称单数|的比较级|的最高级)')
POS=re.compile(r'^[A-Za-z]+\.\s*'); BRK=re.compile(r'^\[[^\]]*\]\s*'); PAREN=re.compile(r'[（(][^）)]*[）)]')
CJK=re.compile(r'[\u4e00-\u9fff]'); ENG=re.compile(r"[a-z][a-z'\-]*"); WORD=re.compile(r"^[a-z][a-z'\-]*$")
weight={}; inb=False
for ln in open(dictp,encoding='utf-8'):
    ln=ln.rstrip('\n')
    if not inb:
        if ln.strip()=='...':inb=True
        continue
    p=ln.split('\t')
    if len(p)<3:continue
    w0=p[0]
    if not w0 or '?' in w0:continue
    try:w=int(p[-1])
    except:continue
    if w0 not in weight or w>weight[w0]:weight[w0]=w
cc={}; re_ced=re.compile(r'^(\S+)\s+(\S+)\s+\[([^\]]*)\]\s+\/(.+)\/$')
for ln in open(cedict_u8,encoding='utf-8'):
    m=re_ced.match(ln.strip()) if ln and ln[0]!='#' else None
    if not m:continue
    simp=m.group(2)
    if not simp:continue
    toks=set(ENG.findall(m.group(4).lower()))
    if simp in cc: cc[simp]|=toks
    else: cc[simp]=toks
def senses(t):
    if not t:return []
    t=t.replace('\\n','\n');res=[]
    for ln in t.split('\n'):
        ln=ln.strip()
        if not ln or ln[0]=='[' or INFLECT.search(ln):continue
        ln=POS.sub('',ln);ln=BRK.sub('',ln)
        for s in re.split(r'[,，;；、]',ln):
            s=PAREN.sub('',s).replace('…','').replace('...','').strip().rstrip('\r')
            if s.endswith('的') and len(s)>2:s=s[:-1]
            if s and CJK.search(s) and s not in res:res.append(s)
    return res
def choose(ss,w):
    wl=w.lower()
    cand=[s for s in ss if wl in cc.get(s,set())]
    if not cand: return ''
    # 优先多字具体词，其次 rime 权重高
    longer=[s for s in cand if len(s)>=2] or cand
    best=longer[0];bw=weight.get(longer[0],0)
    for s in longer[1:]:
        ww=weight.get(s,0)
        if ww>bw:bw=ww;best=s
    return best
# 收词（common + frq 排序）
recs=[]
with open(ecdict_p,newline='',encoding='utf-8') as f:
    for r in csv.DictReader(f):
        w=(r.get('word') or '').strip().lower()
        if not w or not WORD.match(w): continue
        def ti(v):
            try:return int(str(v).strip())
            except:return 0
        common=(ti(r.get('collins'))>0 or str(r.get('oxford')).strip()=='1' or (r.get('tag') or '').strip()!='' or ti(r.get('bnc'))>0 or ti(r.get('frq'))>0)
        if not common: continue
        frq=ti(r.get('frq')) or 999999
        recs.append((frq,w,r.get('translation') or ''))
recs.sort()
seen=set(); picked=[]
for frq,w,tr in recs:
    if w in seen: continue
    seen.add(w); picked.append((w,tr))
    if len(picked)>=N: break
blank=0; rows=[]
for w,tr in picked:
    g=choose(senses(tr),w)
    if not g: blank+=1
    rows.append((w,g))
with open(out,'w',encoding='utf-8') as f:
    for w,g in rows: f.write(f'{w}\t{g}\n')
print(f'core N={len(rows)} blank={blank} ({100.0*blank/len(rows):.1f}%) -> {out}')
