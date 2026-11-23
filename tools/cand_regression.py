# -*- coding: utf-8 -*-
"""候选质量回归 runner（dict 级，CI 可跑，不依赖真机/librime）
用法:
  python cand_regression.py <pinyin_simp.dict.yaml> [cases.tsv]
默认 cases = 同目录 cand_cases.tsv。退出码：0=全 PASS，1=有 FAIL（供 CI 红灯）。

判定（对每条 case）:
  - contain  : 期望词必须在「该精确音节码」下存在（抓「缺词条/缺拼音别名」，如 嗯 只有 ng 没有 en、嗯嗯缺失）
  - topN=N   : 期望词在该精确码桶内按权重排名 <= N（单音节码=该桶全部单字；抓 在/再、我/喔 这类排序）
  - min=W    : 期望词在该码权重 >= W（抓权重过低被生僻词压过，如 哈哈原1864）
局限：多音节词的真正首选可能来自「拆字组合」(如 enen = e+nen→鄂嫩)，dict 级看不到组合；
      故多音节主要用 min 高权重兜底；最终「实际首候选」仍以 librime/真机为准（脚本只作快速系统门禁）。
"""
import sys, os

def toneless_code(code):
    # code 已是无调音节串（空格分隔），统一小写、去多余空格
    return ' '.join(code.strip().lower().split())

def load_book(path):
    """返回 (by_code: {code_key: [(word,w)]}, word_entries: {word: [(code_key,w)]})"""
    by_code = {}
    word_entries = {}
    started = False
    with open(path, encoding='utf-8') as f:
        for ln in f:
            ln = ln.rstrip('\n')
            if not started:
                if ln.strip() == '...':
                    started = True
                continue
            if not ln or ln.startswith('#'):
                continue
            p = ln.split('\t')
            if len(p) < 2:
                continue
            word = p[0].strip()
            code = toneless_code(p[1])
            if not word or not code:
                continue
            try:
                w = int(p[2]) if len(p) > 2 and p[2].strip() else 0
            except Exception:
                w = 0
            by_code.setdefault(code, []).append((word, w))
            word_entries.setdefault(word, []).append((code, w))
    return by_code, word_entries

def weight_at(word_entries, word, code):
    best = None
    for c, w in word_entries.get(word, []):
        if c == code and (best is None or w > best):
            best = w
    return best

def rank_in(by_code, code, word):
    lst = sorted(by_code.get(code, []), key=lambda x: -x[1])
    for i, (wd, w) in enumerate(lst, 1):
        if wd == word:
            return i, w, lst[:5]
    return None, None, lst[:5]

def main():
    dict_path = sys.argv[1]
    cases_path = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), 'cand_cases.tsv')
    by_code, word_entries = load_book(dict_path)
    rows = []
    with open(cases_path, encoding='utf-8') as f:
        for ln in f:
            ln = ln.rstrip('\n')
            if not ln or ln.startswith('code\t') or ln.startswith('#'):
                continue
            p = ln.split('\t')
            if len(p) < 3:
                continue
            code = toneless_code(p[0]); expected = p[1].strip(); rule = p[2].strip()
            cat = p[3].strip() if len(p) > 3 else ''
            tier = p[4].strip() if len(p) > 4 else 'hard'
            rows.append((code, expected, rule, cat, tier))

    total = len(rows); hard_fails = []; soft_warns = []
    for code, expected, rule, cat, tier in rows:
        tokens = [t.strip() for t in rule.split(',') if t.strip()] or ['contain']
        probs = []
        w = weight_at(word_entries, expected, code)
        if w is None:
            alt = word_entries.get(expected, [])
            probs.append('缺词条: 「%s」不在码[%s]下 (其它码=%s)' % (expected, code, [c for c, _ in alt][:3] or '无'))
        for t in tokens:
            if t == 'contain':
                continue
            if t.startswith('min='):
                lim = int(t.split('=')[1])
                if w is not None and w < lim:
                    probs.append('权重过低: %d < %d' % (w, lim))
            elif t.startswith('top'):
                n = int(t.split('=')[1]) if '=' in t else int(t[3:])
                r, rw, top5 = rank_in(by_code, code, expected)
                if r is None:
                    pass
                elif r > n:
                    probs.append('排名靠后: 第%d名(需<=%d) 桶首5=%s' % (r, n, top5))
        if probs:
            (hard_fails if tier == 'hard' else soft_warns).append((code, expected, cat, tier, probs))

    n_hard = sum(1 for r in rows if r[4] == 'hard')
    out = []
    out.append('=== 候选质量回归(dict级)  dict=%s ===' % os.path.basename(dict_path))
    out.append('用例总数=%d  [硬]通过=%d [硬]失败=%d  [软]提醒=%d' %
               (total, n_hard - len(hard_fails), len(hard_fails), len(soft_warns)))
    out.append('--- 硬门禁失败(阻断出包) ---' if hard_fails else '--- 硬门禁：全通过 ---')
    for code, expected, cat, tier, probs in hard_fails:
        out.append('  [FAIL] %-20s -> %-10s (%s)' % (code, expected, cat))
        for pr in probs:
            out.append('         - ' + pr)
    if soft_warns:
        out.append('--- 软提醒(建议补词/排序, 不阻断; 仅列前15) ---')
        for code, expected, cat, tier, probs in soft_warns[:15]:
            out.append('  [WARN] %-20s -> %-10s (%s) %s' % (code, expected, cat, probs))
        if len(soft_warns) > 15:
            out.append('  ... 其余 %d 条软提醒（不阻断）' % (len(soft_warns) - 15))
    out.append('结果: ' + ('PASS(硬门禁全通过)' if not hard_fails else 'FAIL(硬门禁%d条)' % len(hard_fails)))
    text = '\n'.join(out)
    print(text)
    try:
        rp = os.path.join(os.path.dirname(os.path.abspath(cases_path)), 'cand_report_last.txt')
        with open(rp, 'w', encoding='utf-8') as fo:
            fo.write(text + '\n')
    except Exception as e:
        print('(写报告失败: %s)' % e, file=sys.stderr)
    sys.exit(0 if not hard_fails else 1)

if __name__ == '__main__':
    main()
