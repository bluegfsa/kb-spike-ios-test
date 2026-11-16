import csv, re
WORD=re.compile(r"^[a-z][a-z'\-]*$"); CJK=re.compile(r'[\u4e00-\u9fff]')
def ti(v):
    try:return int(str(v).strip())
    except:return 0
# 英 batch3: ECDICT frq 排名 1001-1500
recs=[]
with open(r'C:\Users\Administrator\.dsh\bot\workspace\_tmp_ecdict.csv',newline='',encoding='utf-8') as f:
    for r in csv.DictReader(f):
        w=(r.get('word') or '').strip().lower()
        if not w or not WORD.match(w):continue
        common=(ti(r.get('collins'))>0 or str(r.get('oxford')).strip()=='1' or (r.get('tag') or '').strip()!='' or ti(r.get('bnc'))>0 or ti(r.get('frq'))>0)
        if not common:continue
        recs.append((ti(r.get('frq')) or 999999,w))
recs.sort(); seen=set(); en=[]
for frq,w in recs:
    if w in seen:continue
    seen.add(w); en.append((w,frq))
en3=en[1000:1500]
enc={}
for ln in open(r'Keyboard/en2zh.txt',encoding='utf-8'):
    k,v=ln.rstrip('\n').split('\t',1);enc[k]=v
with open(r'tools/batch3_en_draft.tsv','w',encoding='utf-8') as f:
    for w,frq in en3: f.write(w+'\t'+enc.get(w,'')+'\t'+str(frq)+'\n')
# 中→英实词 batch1: wordlist_zh_shi 前 500
zh=[]
for ln in open(r'tools/wordlist_zh_shi_top2000.txt',encoding='utf-8'):
    s=ln.rstrip('\n')
    if s: zh.append(s)
zh1=zh[:500]
zhc={}
for ln in open(r'Keyboard/zh2en.txt',encoding='utf-8'):
    k,v=ln.rstrip('\n').split('\t',1);zhc[k]=v
with open(r'tools/zh_shi_batch1_draft.tsv','w',encoding='utf-8') as f:
    for s in zh1: f.write(s+'\t'+zhc.get(s,'')+'\n')
print('en batch3',len(en3),'zh_shi batch1',len(zh1))
