import re
_LEAD = re.compile(r'^\s*[\(（][^)）]*[\)）]\s*')
_TRAIL = re.compile(r'\s*[\(（][^)）]*[\)）]\s*\Z')
_SEE = re.compile(r'^(see|variant of|old variant|abbr\.|short name)', re.I)

def normalize(orig: str) -> str:
    """规则化清洗 CC-CEDICT 首义：去前/尾括注、去 CL:、过长取首个逗号前。"""
    if not orig:
        return ''
    g = orig.strip()
    g = re.sub(r'\s*\(?CL:[^)）]*[\)）]?', '', g)      # 去 CL: 量词
    while _LEAD.match(g):
        g = _LEAD.sub('', g, count=1)
    g = _TRAIL.sub('', g)
    g = g.strip().strip('.,;，；')
    if len(g) > 20 and ',' in g:
        g = g.split(',')[0].strip()
    if len(g) > 20 and '，' in g:
        g = g.split('，')[0].strip()
    return g

def needs_manual(orig: str) -> bool:
    if not orig or not orig.strip():
        return True
    if _SEE.match(orig.strip()):
        return True
    return False
