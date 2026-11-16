import csv, re
WORD=re.compile(r"^[a-z][a-z'\-]*$")
def ti(v):
    try:return int(str(v).strip())
    except:return 0
# 英 batch4: ECDICT frq 排名 1501-2000
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
en4=en[1500:2000]
enc={}
for ln in open(r'Keyboard/en2zh.txt',encoding='utf-8'):
    k,v=ln.rstrip('\n').split('\t',1);enc[k]=v
with open(r'tools/batch4_en_draft.tsv','w',encoding='utf-8') as f:
    for w,frq in en4: f.write(w+'\t'+enc.get(w,'')+'\t'+str(frq)+'\n')
print('en batch4',len(en4))
