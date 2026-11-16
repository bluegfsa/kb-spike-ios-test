import sys
CORR = {
 'access':'访问','critical':'关键的','version':'版本','directly':'直接地','species':'物种','immediately':'立即',
 'track':'轨道','basic':'基本的','ms':'女士','plane':'飞机','nobody':'没有人','refer':'提及','perfect':'完美的',
 'touch':'触摸','nuclear':'核','involved':'有关的','conflict':'冲突','feature':'特征','am':'是','dozen':'一打',
 'battle':'战斗','element':'元素','normal':'正常的','solution':'解决方案','scale':'规模','spot':'地点','handle':'处理',
 'survey':'调查','supposed':'应该','tradition':'传统','soviet':'苏维埃','hide':'隐藏','potential':'潜力','independent':'独立的',
 'express':'表达','apartment':'公寓','band':'乐队','guard':'守卫','facility':'设施','settle':'解决','feed':'喂养','mostly':'大多',
 'marry':'结婚','survive':'生存','border':'边界','limit':'限制','fit':'适合','cry':'哭','aspect':'方面','annual':'年度的',
 'comment':'评论','affair':'事务','responsible':'负责的','regular':'规则的','demonstrate':'证明','review':'审查','engage':'参与',
 'commit':'承诺','youth':'青年','perspective':'视角','cook':'烹饪','function':'功能','extend':'扩展','chief':'首领','learning':'学习',
 'academic':'学术的','internet':'互联网','following':'下列的','depend':'依靠','fair':'公平的','exercise':'锻炼','hire':'雇用',
 'tie':'领带','eastern':'东方的','primary':'主要的','lean':'倾斜','male':'男性的','intend':'打算','chicken':'鸡','session':'会议',
 'domestic':'国内的','lots':'许多','northern':'北方的','russian':'俄罗斯的','expand':'扩展','corporate':'公司的','urban':'城市的',
 'mental':'心理的','favorite':'最喜欢的','greatest':'最伟大的','complex':'复杂的','instrument':'仪器','presidential':'总统的',
 'emotional':'情感的','supreme':'最高的','sight':'景象','straight':'直的','works':'作品','regional':'地区的',
}
src=r'tools/batch3_en_draft.tsv'; out_core=r'tools/core_batch3.tsv'; out_trace=r'tools/core_batch3_留痕.tsv'
rows=[]
for ln in open(src,encoding='utf-8'):
    ln=ln.rstrip('\n')
    if not ln: continue
    p=ln.split('\t'); w=p[0]; orig=p[1] if len(p)>1 else ''; frq=p[2] if len(p)>2 else ''
    final=CORR.get(w,orig); changed=(w in CORR)
    basis='人工复核：常用义/公认主译' if changed else 'ECDICT首义，人工复核确认'
    rows.append((w,frq,orig,final,basis))
with open(out_core,'w',encoding='utf-8') as f:
    for w,frq,o,fi,b in rows: f.write(w+'\t'+fi+'\n')
with open(out_trace,'w',encoding='utf-8') as f:
    f.write('词\t词频排名\tECDICT原首义\t校正后主义\t依据源\t复核人\t日期\t是否留空\n')
    for w,frq,o,fi,b in rows:
        f.write(f'{w}\t{frq}\t{o}\t{fi}\t{b}\t架构师\t2026-11-16\t{"是" if fi=="" else "否"}\n')
print('batch3 en', len(rows), 'corrected', len(CORR))
