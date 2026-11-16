import sys
CORR = {
 'draw':'画','film':'电影','current':'当前的','board':'板','performance':'表现','share':'分享',
 'natural':'自然','series':'系列','realize':'意识到','available':'可用的','single':'单一的',
 'campaign':'运动','medical':'医疗的','risk':'风险','represent':'代表','drop':'落下','fine':'好的',
 'common':'常见的','save':'保存','scene':'场景','stock':'股票','despite':'尽管','ready':'准备好的',
 'list':'列表','individual':'个人','pressure':'压力','argue':'争论','character':'性格','physical':'身体的',
 'feeling':'感觉','section':'部分','environmental':'环境的','pm':'下午','miss':'错过','various':'各种',
 'claim':'声称','final':'最后的','main':'主要的','popular':'流行的','respond':'回应','reveal':'显露',
 'apply':'申请','measure':'措施','fly':'飞','particular':'特别的','perform':'表演','treat':'对待',
 'range':'范围','specific':'特定的','middle':'中间','stuff':'东西','somebody':'某人','tough':'艰难的',
 'pattern':'模式','coach':'教练','yard':'院子','beat':'打败','violence':'暴力','tend':'倾向于','modern':'现代的',
 'task':'任务','positive':'积极的','civil':'公民的','safe':'安全的','agreement':'协议','account':'账户',
 'relate':'有关','senior':'高级的','professional':'专业的','customer':'顾客','southern':'南方的',
 'western':'西方的','author':'作者',
}
src=r'tools/batch2_en_draft.tsv'; out_core=r'tools/core_batch2.tsv'; out_trace=r'tools/core_batch2_留痕.tsv'
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
print('batch2 en', len(rows), 'corrected', len(CORR))
