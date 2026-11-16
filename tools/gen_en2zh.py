#!/usr/bin/env python3
# 由 ECDICT（skywind3000/ECDICT, MIT）生成英→中短译表 en2zh.txt（"english_lower\t中文短译"，按 key 升序）。
# 英→中改用「英文为中心」的 ECDICT：CC-CEDICT 反查会出 you→尊驾、good→不赖、phone→致电 这类错译。
#
# 抽取规则 v2：
#   1) 跳过「[领域]」行与「X的过去式/复数…」变形行；
#   2) 取首个词性行的第一个义项（最贴近"主释义"）；
#   3) 去词性前缀、去括注、去结尾「的」；
#   4) 对高频常用词用 OVERRIDES 纠正（ECDICT 个别词首义是次要词性，如 good 首行是名词「善行」）。
# 用法：python gen_en2zh.py <ecdict.csv> <en2zh.txt> [sample]
import sys, csv, re, os

src = sys.argv[1]
out = sys.argv[2] if len(sys.argv) > 2 else 'en2zh.txt'
sample = len(sys.argv) > 3 and sys.argv[3] == 'sample'

INFLECT = re.compile(r'(的过去式|的过去分词|的复数|的现在分词|的第三人称单数|的比较级|的最高级)')
POS = re.compile(r'^[A-Za-z]+\.\s*')
BRACKET = re.compile(r'^\[[^\]]*\]\s*')
PAREN = re.compile(r'[（(][^）)]*[）)]')
CJK = re.compile(r'[\u4e00-\u9fff]')
WORD = re.compile(r"^[a-z][a-z'\-]*$")

# 高频常用词纠正表：ECDICT 首义取到次要词性/义项时在此给定主译（只覆盖真正需要的，宁少勿错）。
OVERRIDES = {
    'a': '一个', 'an': '一个',
    'in': '在', 'on': '在', 'with': '和', 'but': '但是', 'as': '作为',
    'can': '能', 'about': '关于', 'will': '将', 'just': '只是', 'want': '想要',
    'well': '好', 'even': '甚至', 'good': '好', 'may': '可能', 'might': '可能',
    'over': '超过', 'still': '仍然', 'leave': '离开', 'old': '老', 'mean': '意思',
    'keep': '保持', 'start': '开始', 'lot': '许多', 'issue': '问题', 'set': '设置',
    'kid': '小孩', 'lead': '领导', 'look': '看', 'like': '喜欢', 'only': '只',
    'very': '很', 'many': '许多', 'call': '打电话', 'make': '做', 'into': '进入',
    'way': '方法', 'each': '每个',
    'right': '对', 'give': '给', 'close': '关', 'cold': '冷', 'play': '玩',
    'open': '打开', 'drink': '喝', 'sorry': '抱歉', 'hello': '你好', 'thanks': '谢谢',
    'lose': '失去', 'come': '来', 'sleep': '睡觉',
    'serve': '服务', 'oh': '哦', 'effect': '影响', 'care': '关心', 'hard': '难',
    'else': '其他', 'along': '沿着', 'carry': '携带', 'thank': '谢谢', 'pick': '挑选',
    'special': '特别的', 'space': '空间', 'produce': '生产', 'industry': '工业',
    'cover': '覆盖', 'major': '主要的', 'break': '打破',
    'sad': '难过', 'orange': '橙',
    # 独立复测查出的包内写死错义（B2.4）：修首义/截断
    'reach': '到达', 'evidence': '证据', 'line': '线', 'remove': '移除',
    'since': '自从', 'global': '全球', 'journal': '期刊', 'tissue': '组织',
    'secure': '安全', 'arise': '出现', 'purpose': '目的',
    'my': '我的', 'your': '你的', 'his': '他的', 'her': '她的', 'its': '它的',
    'our': '我们的', 'their': '他们的',
}

def extract(translation):
    if not translation:
        return None
    translation = translation.replace('\\n', '\n')  # ECDICT 换行是字面「\n」两字符
    for ln in translation.split('\n'):
        ln = ln.strip()
        if not ln or ln[0] == '[':
            continue
        if INFLECT.search(ln):
            continue
        ln = POS.sub('', ln)
        ln = BRACKET.sub('', ln)
        first = re.split(r'[,，;；、]', ln)[0].strip()
        first = PAREN.sub('', first).replace('…', '').replace('...', '').strip().rstrip('\r')
        if first.endswith('的') and len(first) > 2:  # 只去多字形容词的尾「的」（避免把 目的→目 之类截断）
            first = first[:-1]
        if first and CJK.search(first):
            return first
    return None

def to_int(v):
    try:
        return int(str(v).strip())
    except Exception:
        return 0

en2zh = {}
with open(src, newline='', encoding='utf-8') as f:
    for row in csv.DictReader(f):
        w = (row.get('word') or '').strip().lower()
        if not w or not WORD.match(w):
            continue
        common = (to_int(row.get('collins')) > 0 or str(row.get('oxford')).strip() == '1'
                  or (row.get('tag') or '').strip() != ''
                  or to_int(row.get('bnc')) > 0 or to_int(row.get('frq')) > 0)
        if not common:
            continue
        g = extract(row.get('translation') or '')
        if g and w not in en2zh:
            en2zh[w] = g

for w, g in OVERRIDES.items():
    en2zh[w] = g

# 常用词人工校正核心词表（分批）：tools/core_batch1.tsv（word\t主义），覆盖 ECDICT 首义
_core = os.path.join(os.path.dirname(__file__), 'core_batch1.tsv')
if os.path.exists(_core):
    n = 0
    for ln in open(_core, encoding='utf-8'):
        ln = ln.rstrip('\n')
        if '\t' not in ln: continue
        k, v = ln.split('\t', 1)
        if v: en2zh[k] = v
        else: en2zh.pop(k, None)
        n += 1
    print('applied core_batch1:', n)

keys = sorted(en2zh)
body = ''.join(f'{k}\t{en2zh[k]}\n' for k in keys)
with open(out, 'w', encoding='utf-8') as f:
    f.write(body)
print('en2zh entries:', len(keys), 'bytes:', len(body.encode('utf-8')))

if sample:
    probe = ['you','good','phone','right','run','beautiful','water','book','eat','hello','thanks','sorry','goodbye','please','yes','no','love','friend','school','teacher','student','morning','night','can','name','time','money','happy','airport','computer','today','tomorrow','family','work','home','city','world','china','people','thing','know','think','make','take','come','want','look','use','find','give','tell','say','help','big','small','new','old','fast','slow','hot','cold','win','lose','buy','sell','open','close','start','stop','read','write','speak','listen','watch','play','drink','sleep','walk','drive','learn','teach']
    for w in probe:
        print(w + '\t' + en2zh.get(w, '(MISS)'))
