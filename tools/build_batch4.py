import sys
# 架构师人工复核（英→中 batch4 = 1501-2000，盲于测试样本）：修空译/僻义/次要词性/冗长义
CORR = {
 'prime':'首要的','analyst':'分析师','being':'存在','largely':'主要地','locate':'定位','propose':'提议',
 'visitor':'访客','comfortable':'舒适的','crew':'工作人员','accident':'事故','hearing':'听力','prefer':'更喜欢',
 'truly':'真正地','emergency':'紧急情况','unique':'独特的','internal':'内部的','ethnic':'种族的','link':'链接',
 'select':'选择','appreciate':'欣赏','actual':'实际的','hardly':'几乎不','setting':'设置','launch':'发起',
 'file':'文件','sick':'生病的','defend':'保卫','ensure':'确保','extremely':'极其','mix':'混合','component':'组件',
 'contrast':'对比','zone':'区域','wake':'醒来','contribution':'贡献','estate':'财产','guide':'向导',
 'circumstance':'情况','steal':'偷','pursue':'追求','neither':'两者都不','due':'到期的','blame':'责备',
 'significantly':'显著地','relief':'缓解','used':'用过的','equal':'相等的','forth':'向前','fix':'修理','appeal':'呼吁',
 'variable':'可变的','rare':'稀有的','tank':'坦克','coverage':'覆盖范围','aside':'在旁边','bond':'纽带',
 'separate':'分开的','somewhat':'有点','pour':'倒','stir':'搅拌','judgment':'判断','tear':'眼泪','initial':'最初的',
 'contemporary':'当代的','multiple':'多个的','essential':'必要的','upper':'上面的','rush':'冲','necessarily':'必然',
 'specifically':'具体地','tired':'累的','resolution':'解决','apart':'分开','sector':'部门','beneath':'在下面',
 'limited':'有限的','faculty':'能力','mass':'大量','definitely':'肯定','massive':'巨大的','narrow':'狭窄的',
 'unfortunately':'不幸地','achievement':'成就','reject':'拒绝','cast':'投掷','sharp':'锐利的','guilty':'有罪的',
 'weak':'弱的','hi':'嗨','alternative':'替代的','wrap':'包裹','depression':'抑郁','musical':'音乐的','suspect':'怀疑',
 'prosecutor':'检察官','recover':'恢复','initiative':'主动性','brief':'简短的','housing':'住房','post':'邮寄',
 'existing':'现有的','fairly':'相当','chip':'芯片','suppose':'假设','settlement':'解决','planning':'计划',
 'slide':'滑动','leading':'领先的','saving':'储蓄','bend':'弯曲','album':'专辑','joint':'关节','grand':'宏伟的',
 'resolve':'解决','racial':'种族的','aids':'艾滋病','jewish':'犹太的','increased':'增加的','funding':'资金',
 'remaining':'剩余的','crazy':'疯狂的','user':'用户','manner':'方式','golden':'金色的','gender':'性别',
 'eliminate':'消除','hall':'大厅','meanwhile':'同时','division':'划分','rely':'依靠','volume':'体积','fashion':'时尚',
 'intervention':'干预','copy':'复制','tip':'提示','rural':'农村的','cream':'奶油','typically':'通常','closely':'密切地',
 'assess':'评估','plenty':'大量','addition':'增加','regard':'认为','cheese':'奶酪','excellent':'优秀的',
 'airline':'航空公司','perceive':'察觉','transform':'改变','coalition':'联盟',
}
src=r'tools/batch4_en_draft.tsv'; out_core=r'tools/core_batch4.tsv'; out_trace=r'tools/core_batch4_留痕.tsv'
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
print('batch4 en', len(rows), 'corrected', len(CORR))
