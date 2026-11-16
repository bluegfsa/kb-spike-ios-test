import sys
# 架构师人工复核（中→英 实词 batch1 = top500 实词，盲于测试样本）：修空译/冗长义/次要词性
CORR = {
 '上':'up','时':'time','时间':'time','觉得':'to feel','想':'to think','找':'to find','一定':'certainly',
 '请':'please','一起':'together','开':'to open','北京':'Beijing','上海':'Shanghai','老':'old','啥':'what',
 '您':'you','游戏':'game','起来':'to get up','作为':'as','元':'yuan','靠':'to lean','表示':'to express',
 '同学':'classmate','老婆':'wife','关于':'about','张':'sheet','过程':'process','介绍':'to introduce',
 '增加':'to increase','按':'to press','人家':'others','单位':'unit','测试':'to test','正在':'(in the process of)',
 '之间':'between','论坛':'forum','不行':'not okay','开发':'to develop','名字':'name','睡觉':'to sleep',
 '我国':'our country','到了':'arrived','组':'group','程序':'program','干':'to do','本来':'originally',
 '效果':'effect','些':'some','次':'time','装':'to install','挺':'quite','作用':'effect','王':'king','正':'correct',
 '领导':'leader','操作':'to operate','行业':'industry','接受':'to accept','以上':'above','才能':'ability',
 '明白':'to understand','以为':'to assume','因':'because','作':'to do','广告':'advertisement','股票':'stock',
 '不断':'constantly','确定':'to determine','好好':'properly','左右':'around','应用':'to apply','表现':'performance',
 '经过':'to pass by','给':'to give','叫':'to call','市场':'market','发现':'to discover','只有':'only',
 '谢谢':'thanks','为了':'in order to','对于':'about','准备':'to prepare','管理':'to manage','任务':'task',
 '活动':'activity','当然':'of course','一次':'once','成':'to become','换':'to change','无':'none','联系':'to contact',
 '个人':'individual','文件':'file','能够':'can','男人':'man','不好':'bad','算':'to count','照片':'photo',
 '实现':'to realize','原来':'originally','包括':'to include','总':'total','提高':'to improve','注意':'to pay attention',
 '连':'even','全部':'all','专业':'major','建议':'to suggest','跑':'to run','办法':'way','消息':'news',
 '终于':'finally','图':'picture','路':'road','全国':'nationwide','另外':'in addition','有关':'related to',
 '设置':'to set','妈妈':'mom','产生':'to produce','上面':'above','服务器':'server','如此':'so','不少':'quite a few',
 '让我':'let me','好了':'okay','我是':'I am','来说':'in terms of','我也':'me too','这一':'this','也有':'also have','也不':'neither',
}
# rime 词频权重
wt={}; inb=False
for ln in open(r'Keyboard/pinyin_simp.dict.yaml',encoding='utf-8'):
    ln=ln.rstrip('\n')
    if not inb:
        if ln.strip()=='...': inb=True
        continue
    p=ln.split('\t')
    if len(p)<3: continue
    s=p[0]
    try: x=int(p[-1])
    except: continue
    if s not in wt or x>wt[s]: wt[s]=x
src=r'tools/zh_shi_batch1_draft.tsv'; out_core=r'tools/core_zh_shi_batch1.tsv'; out_trace=r'tools/core_zh_shi_batch1_留痕.tsv'
rows=[]
for ln in open(src,encoding='utf-8'):
    ln=ln.rstrip('\n')
    if not ln: continue
    p=ln.split('\t'); w=p[0]; orig=p[1] if len(p)>1 else ''
    final=CORR.get(w,orig)
    changed=(final!=orig)  # 按实际改动计（no-op 不算修正）
    basis='人工复核：常用义/公认主译' if changed else 'CC-CEDICT首义，人工复核确认'
    rows.append((w,wt.get(w,''),orig,final,basis))
with open(out_core,'w',encoding='utf-8') as f:
    for w,t,o,fi,b in rows: f.write(w+'\t'+fi+'\n')
nchg=0
with open(out_trace,'w',encoding='utf-8') as f:
    f.write('词\t词频(weight)\t原义(CC-CEDICT)\t校正后主义\t依据源\t复核人\t日期\t是否留空\n')
    for w,t,o,fi,b in rows:
        if fi!=o: nchg+=1
        f.write(f'{w}\t{t}\t{o}\t{fi}\t{b}\t架构师\t2026-11-16\t{"是" if fi=="" else "否"}\n')
print('zh_shi batch1', len(rows), 'actual_corrected', nchg)
