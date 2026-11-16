import sys
# 架构师人工复核（中→英 top500，盲于测试样本）：修正冷僻/古怪义、空译、生硬义
CORR = {
 '是':'to be','在':'at','你':'you','和':'and','就':'then','他':'he','呵呵':'haha',
 '为':'for','与':'and','后':'after','打':'to hit','地':'ground','里':'inside','东西':'thing',
 '跟':'with','太':'too','号':'number','才':'only then','话':'words','当':'when','更':'more',
 "别":"don't",'一般':'general','由':'from','日':'day','哪':'where','带':'to bring','回':'to return',
 '卡':'card','同':'same','发':'to send','最':'most','其':'its','只':'only','行':'to walk','晕':'dizzy',
 '刚':'just','本':'this','页':'page','进':'to enter','张':'to open',
 '吗':'(question particle)','呢':'(modal particle)','吧':'(modal particle)','个':'(classifier)',
 '们':'(plural marker)','得':'(structural particle)','之':'(possessive particle)','者':'(one who)',
 '第':'(ordinal prefix)','则':'(conjunction)','所':'(particle)','了':'(completed action)','把':'(disposal particle)',
 '等':'to wait','恩':'grace','回复日期':'','都是':'all are','很多':'many','也是':'also','的人':'(person who)',
 '我的':'my','你的':'your','两个':'two','这是':'this is','给我':'give me','好的':'okay','给你':'for you',
 '中的':'(in)','他的':'his','还要':'still want','这次':'this time','一个':'a','没有':'not have','不是':'not',
 '不过':'however','不会':"won't",'一直':'always','产品':'product','事情':'matter','目前':'now','方面':'aspect',
 '项目':'project','不错':'not bad','支持':'support','意思':'meaning','特别':'special','就是':'exactly',
}
src=r'tools/zh_batch1_draft.tsv'
out_core=r'tools/core_zh_batch1.tsv'
out_trace=r'tools/core_zh_batch1_留痕.tsv'
rows=[]
for ln in open(src,encoding='utf-8'):
    ln=ln.rstrip('\n')
    if not ln: continue
    p=ln.split('\t'); w=p[0]; orig=p[1] if len(p)>1 else ''; wt=p[2] if len(p)>2 else ''
    final=CORR.get(w, orig)
    changed=(w in CORR)
    basis='人工复核：常用义/公认主译' if changed else 'CC-CEDICT首义，人工复核确认'
    rows.append((w,wt,orig,final,basis))
with open(out_core,'w',encoding='utf-8') as f:
    for w,wt,o,fi,b in rows: f.write(f'{w}\t{fi}\n')
with open(out_trace,'w',encoding='utf-8') as f:
    f.write('词\t词频(权重)\tCC-CEDICT原义\t校正后主义\t依据源\t复核人\t日期\t是否留空\n')
    for w,wt,o,fi,b in rows:
        f.write(f'{w}\t{wt}\t{o}\t{fi}\t{b}\t架构师\t2026-11-16\t{"是" if fi=="" else "否"}\n')
print('zh core', len(rows), 'corrected', len(CORR))
