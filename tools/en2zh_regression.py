# -*- coding: utf-8 -*-
"""英→中(en2zh)词典回归 runner（数据级，CI 可跑）
用法: python en2zh_regression.py <en2zh.txt> [cases.tsv]
cases: word<TAB>keyword。判据：词存在，且其释义（首义，"/"前一段优先，兼顾整条）含 keyword。
退出码 0=PASS,1=FAIL。局限：数据级≠真机运行时；最终首候选仍真机验(如 apple→苹果)。
"""
import sys, os

def load_en2zh(path):
    d = {}
    for ln in open(path, encoding='utf-8'):
        ln = ln.rstrip('\n')
        if not ln or '\t' not in ln:
            continue
        w, gloss = ln.split('\t', 1)
        w = w.strip()
        if w and w not in d:
            d[w] = gloss.strip()
    return d

def main():
    en2zh = sys.argv[1]
    cases = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), 'en2zh_cases.tsv')
    d = load_en2zh(en2zh)
    rows = []
    for ln in open(cases, encoding='utf-8'):
        ln = ln.rstrip('\n')
        if not ln or ln.startswith('word\t'):
            continue
        p = ln.split('\t')
        if len(p) < 2:
            continue
        rows.append((p[0].strip(), p[1].strip()))
    fails = []
    for w, kw in rows:
        g = d.get(w)
        if g is None:
            fails.append((w, kw, '缺词'))
            continue
        first = g.split('/')[0]
        alts = [a for a in kw.split('|') if a]
        if any(a in first for a in alts) or any(a in g for a in alts):
            continue
        fails.append((w, kw, g))
    total = len(rows)
    print('=== 英→中(en2zh)回归  用例=%d  通过=%d  失败=%d ===' % (total, total - len(fails), len(fails)))
    for w, kw, info in fails:
        print('  [FAIL] %-12s 期望含「%s」 实际=%s' % (w, kw, info))
    print('结果:', 'PASS' if not fails else 'FAIL')
    try:
        rp = os.path.join(os.path.dirname(os.path.abspath(cases)), 'en2zh_report_last.txt')
        with open(rp, 'w', encoding='utf-8') as fo:
            fo.write('用例=%d 通过=%d 失败=%d\n' % (total, total - len(fails), len(fails)))
            for w, kw, info in fails:
                fo.write('FAIL %s 期望含%s 实际=%s\n' % (w, kw, info))
    except Exception:
        pass
    sys.exit(0 if not fails else 1)

if __name__ == '__main__':
    main()
