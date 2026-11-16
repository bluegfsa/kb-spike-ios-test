import sys
# 生成中→英实词 batch2/3/4 草稿：wordlist_zh_shi_top2000 分段，取现有 zh2en.txt 首义
words=[ln.rstrip('\n') for ln in open(r'tools/wordlist_zh_shi_top2000.txt',encoding='utf-8') if ln.strip()]
zhc={}
for ln in open(r'Keyboard/zh2en.txt',encoding='utf-8'):
    k,v=ln.rstrip('\n').split('\t',1); zhc[k]=v
segs={'2':words[500:1000],'3':words[1000:1500],'4':words[1500:2000]}
for b,seg in segs.items():
    with open(f'tools/zh_shi_batch{b}_draft.tsv','w',encoding='utf-8') as f:
        for s in seg: f.write(s+'\t'+zhc.get(s,'')+'\n')
    print('batch',b,len(seg))
