import csv, re
CJK=re.compile(r'[\u4e00-\u9fff]'); WORD=re.compile(r"^[a-z][a-z'\-]*$")
def ti(v):
    try:return int(str(v).strip())
    except:return 0
# 英：ECDICT frq 前 2000 常用词
recs=[]
with open(r'C:\Users\Administrator\.dsh\bot\workspace\_tmp_ecdict.csv',newline='',encoding='utf-8') as f:
    for r in csv.DictReader(f):
        w=(r.get('word') or '').strip().lower()
        if not w or not WORD.match(w):continue
        common=(ti(r.get('collins'))>0 or str(r.get('oxford')).strip()=='1' or (r.get('tag') or '').strip()!='' or ti(r.get('bnc'))>0 or ti(r.get('frq'))>0)
        if not common:continue
        recs.append((ti(r.get('frq')) or 999999, w))
recs.sort(); seen=set(); en=[]
for frq,w in recs:
    if w in seen:continue
    seen.add(w); en.append(w)
    if len(en)>=2000:break
open(r'tools/wordlist_en_top2000.txt','w',encoding='utf-8').write('\n'.join(en)+'\n')
# 中：rime 中文词频前 2000
w={};inb=False
for ln in open(r'Keyboard/pinyin_simp.dict.yaml',encoding='utf-8'):
    ln=ln.rstrip('\n')
    if not inb:
        if ln.strip()=='...':inb=True
        continue
    p=ln.split('\t')
    if len(p)<3:continue
    s=p[0]
    if not s or '?' in s or not CJK.search(s) or s=='回复日期':continue
    try:x=int(p[-1])
    except:continue
    if s not in w or x>w[s]:w[s]=x
zh=[s for s,_ in sorted(w.items(), key=lambda kv:-kv[1])][:2000]
open(r'tools/wordlist_zh_top2000.txt','w',encoding='utf-8').write('\n'.join(zh)+'\n')
print('en',len(en),'zh',len(zh))
