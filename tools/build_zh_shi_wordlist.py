import re, hashlib
CJK=re.compile(r'[\u4e00-\u9fff]')
# —— 固定停用词表（纯语法虚词；单字实词如 人/手/书/路/水/钱 不在此列，保留）——
STOP1 = set('的了是在就吧吗呢我你他她它们这那个之乎者也而于以为所其着过得又再还很太最更不没别要会能可应及或与和啊呀嘛哦嗯哈啦咯唉嘿呵都把被从将但么并才真且却则')
STOP1 |= set(['阿','哎','呗','恩'])
STOP_MULTI = set('''我们 你们 他们 她们 它们 咱们 这个 那个 这些 那些 什么 怎么 怎样 这样 那样 哪 谁 多少 为什么
但是 不过 因为 所以 如果 然后 而且 或者 虽然 即使 已经 可以 应该 可能 不是 没有 不要 不用 不能 不会 就是 还是 只是
一样 这么 那么 一点 一下 一些 一个 两个 的话 之后 之前 以后 以前 呵呵 哈哈 嘿嘿 什么时候 是不是 有没有 这种 那种 这次 那次 几个 有些 有的
都是 还有 也是 看看 其实 一直'''.split())
def is_stop(w):
    return (w in STOP_MULTI) or (len(w)==1 and w in STOP1)
# —— rime 词频 ——
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
ordered=[s for s,_ in sorted(w.items(), key=lambda kv:-kv[1])]
kept=[]; deleted=[]
for s in ordered:
    if is_stop(s): deleted.append(s)
    else: kept.append(s)
top=kept[:2000]
open(r'tools/wordlist_zh_shi_top2000.txt','w',encoding='utf-8').write('\n'.join(top)+'\n')
# 停用词表（规则用，排序）
stop_tokens=sorted(STOP_MULTI | set(STOP1))
open(r'tools/stopwords_zh.txt','w',encoding='utf-8').write('\n'.join(stop_tokens)+'\n')
# 被删词清单（rime 词频前 3000 内被判为虚词而剔除的）
open(r'tools/wordlist_zh_deleted.txt','w',encoding='utf-8').write('\n'.join(deleted[:500])+'\n')
def sha(p): return hashlib.sha256(open(p,'rb').read()).hexdigest().upper()
print('shi top2000', len(top))
print('wordlist sha', sha(r'tools/wordlist_zh_shi_top2000.txt'))
print('stopwords sha', sha(r'tools/stopwords_zh.txt'))
print('deleted sha', sha(r'tools/wordlist_zh_deleted.txt'), 'deleted_in_top3000head', len(deleted[:500]))
print('前40:', '、'.join(top[:40]))
