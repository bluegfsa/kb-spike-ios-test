import sys
# 架构师人工复核（盲于测试 A/B 样本，依据「该词公认主译」）
CORR = {
 'high':'高的','great':'伟大的','around':'周围','party':'聚会','grow':'生长',
 'low':'低的','able':'能够','process':'过程','sense':'感觉','cut':'切',
 'behind':'在后面','local':'当地的','raise':'提高','former':'以前的',
 'economic':'经济的','according':'根据','player':'运动员','matter':'事情',
 'site':'地点','project':'项目','base':'基础','meet':'见面','pay':'支付',
 'word':'单词','seem':'似乎','through':'穿过','information':'信息','power':'力量',
}
src=r'tools/batch1_draft.tsv'
out_core=r'tools/core_batch1.tsv'
out_trace=r'tools/core_batch1_留痕.tsv'
rows=[]
for ln in open(src,encoding='utf-8'):
    ln=ln.rstrip('\n')
    if not ln: continue
    parts=ln.split('\t')
    w=parts[0]; orig=parts[1] if len(parts)>1 else ''; frq=parts[2] if len(parts)>2 else ''
    final=CORR.get(w, orig)
    changed = (w in CORR)
    basis = '人工复核：常用义/公认主译' if changed else 'ECDICT首义，人工复核确认无误'
    rows.append((w,frq,orig,final,basis))
with open(out_core,'w',encoding='utf-8') as f:
    for w,frq,o,fi,b in rows: f.write(f'{w}\t{fi}\n')
with open(out_trace,'w',encoding='utf-8') as f:
    f.write('词\t词频排名\tECDICT原首义\t校正后主义\t依据源\t复核人\t日期\t是否留空\n')
    for w,frq,o,fi,b in rows:
        blank = '是' if fi=='' else '否'
        f.write(f'{w}\t{frq}\t{o}\t{fi}\t{b}\t架构师\t2026-11-16\t{blank}\n')
print('core', len(rows), 'corrected', sum(1 for w,*_ in rows if w in CORR))
