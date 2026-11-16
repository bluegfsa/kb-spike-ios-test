import csv, re
CJK=re.compile(r'[\u4e00-\u9fff]'); WORD=re.compile(r"^[a-z][a-z'\-]*$")
def ti(v):
    try:return int(str(v).strip())
    except:return 0
# ---- 英：ECDICT frq 排名 501-1000 ----
recs=[]
with open(r'C:\Users\Administrator\.dsh\bot\workspace\_tmp_ecdict.csv',newline='',encoding='utf-8') as f:
    for r in csv.DictReader(f):
        w=(r.get('word') or '').strip().lower()
        if not w or not WORD.match(w):continue
        common=(ti(r.get('collins'))>0 or str(r.get('oxford')).strip()=='1' or (r.get('tag') or '').strip()!='' or ti(r.get('bnc'))>0 or ti(r.get('frq'))>0)
        if not common:continue
        recs.append((ti(r.get('frq')) or 999999, w))
recs.sort()
seen=set();order=[]
for frq,w in recs:
    if w in seen:continue
    seen.add(w);order.append((w,frq))
en=order[500:1000]
enc={}
for ln in open(r'Keyboard/en2zh.txt',encoding='utf-8'):
    k,v=ln.rstrip('\n').split('\t',1);enc[k]=v
with open(r'tools/batch2_en_draft.tsv','w',encoding='utf-8') as f:
    for w,frq in en: f.write(w+'\t'+enc.get(w,'')+'\t'+str(frq)+'\n')
# ---- 中：rime 权重排名 501-1000，跳过垃圾词 ----
w={};inb=False
for ln in open(r'Keyboard/pinyin_simp.dict.yaml',encoding='utf-8'):
    ln=ln.rstrip('\n')
    if not inb:
        if ln.strip()=='...':inb=True
        continue
    p=ln.split('\t')
    if len(p)<3:continue
    s=p[0]
    if not s or '?' in s or not CJK.search(s):continue
    try:x=int(p[-1])
    except:continue
    if s not in w or x>w[s]:w[s]=x
zorder=sorted(w.items(), key=lambda kv:-kv[1])
zhc={}
for ln in open(r'Keyboard/zh2en.txt',encoding='utf-8'):
    k,v=ln.rstrip('\n').split('\t',1);zhc[k]=v
zh=[x for x in zorder if x[0] not in ('回复日期',)][500:1000]
with open(r'tools/zh_batch2_draft.tsv','w',encoding='utf-8') as f:
    for s,wt in zh: f.write(s+'\t'+zhc.get(s,'')+'\t'+str(wt)+'\n')
print('en batch2',len(en),'zh batch2',len(zh))
