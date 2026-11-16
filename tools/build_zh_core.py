import re
CJK=re.compile(r'[\u4e00-\u9fff]')
# rime 中文词频
w={}
inb=False
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
items=sorted(w.items(), key=lambda kv:-kv[1])[:500]
cur={}
for ln in open(r'Keyboard/zh2en.txt',encoding='utf-8'):
    k,v=ln.rstrip('\n').split('\t',1);cur[k]=v
with open(r'tools/zh_batch1_draft.tsv','w',encoding='utf-8') as f:
    for s,wt in items:
        f.write(s+'\t'+cur.get(s,'')+'\t'+str(wt)+'\n')
print('zh_batch1_draft', len(items))
