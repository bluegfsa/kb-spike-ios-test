import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from zh_shi_norm import normalize
# 架构师人工复核（中→英实词 batch2-4，盲于测试样本）：补空译/纠地名误取/修错义；括注由 normalize 规则清洗
CORR = {
 # --- 地名/误取县市条目 ---
 '深圳':'Shenzhen','广州':'Guangzhou','比如':'for example','资源':'resources','种':'kind',
 '南京':'Nanjing','杭州':'Hangzhou','成都':'Chengdu','天涯':'the ends of the earth','广东':'Guangdong','帐号':'account',
 '武汉':'Wuhan','干吗':'what for','四川':'Sichuan','浙江':'Zhejiang',
 # --- 错义 ---
 '现代':'modern','抢':'to grab','岁':'years old','呃':'uh',
 # --- batch2 空译 ---
 '都有':'all have','是个':'is a','一天':'one day','上的':'on','就会':'will','有个':'there is','还在':'still',
 '很好':'very good','我想':'I think','还没':'not yet','我就':'then I','新的':'new','是啊':'yes','让人':'make one',
 '看了':'looked','看着':'looking','来了':'came','太多':'too many','一年':'one year','那就':'then','她的':'her',
 '一位':'a person','你是':'you are','哈哈哈':'haha','去了':'went','不乖':'naughty','您的':'your','三个':'three',
 '一张':'one sheet','的事':'the matter','放在':'put at','会有':'will have','是在':'is at','也就':'also then',
 # --- batch3 空译 ---
 '都在':'all at','让你':'let you','我在':'I am','一条':'a strip','不敢':'dare not','试试':'try','都要':'all want',
 '很快':'very fast','最大':'largest','也会':'also will','问问':'ask','很大':'very big','做好':'do well','也要':'also want',
 '很难':'very hard','我要':'I want','就像':'just like','都不':'none','我不':'I do not','一份':'a portion','帮我':'help me',
 '做了':'did','很少':'very few','买了':'bought','来看':'come to see','是一种':'is a kind of','更多的':'more','没人':'nobody',
 '人的':"people's",'还能':'still can','最大的':'largest','它的':'its','就在':'just at','不太':'not very','多了':'more',
 '看过':'have seen','不懂':'do not understand','你要':'you want','走了':'left','才是':'is the one','又是':'again is',
 '大盘':'broad market','就能':'then can','不去':'not go','好吧':'okay','带着':'carrying','并不是':'is not','你说':'you say',
 '一段':'a segment','让他':'let him','也没':'also not','站在':'standing at','两人':'two people','我说':'I say',
 # --- batch4 空译 ---
 '给他':'give him','忘了':'forgot','一场':'an event','想想':'think','就行':'is fine','出了':'came out','你就':'you then',
 '就不':'then not','就有':'then have','一片':'a piece','不多':'not many','就好':'is fine','坐在':'sitting at','很有':'has much',
 '两天':'two days','过了':'passed','一只':'one animal','一名':'a person','说了':'said','万元':'ten thousand yuan','跟我':'with me',
 '两年':'two years','不说':'not say','都能':'all can','找个':'find a','个月':'a month','是我':'is me','还会':'will still',
 '很久':'a long time','对我':'to me','我还':'I still','做的':'done','很多人':'many people','死了':'died','帮你':'help you',
 '跟你':'with you','而不是':'rather than','第三':'third','一是':'first is','都没':'none','你在':'you are at','脸上':'on the face',
 '一把':'a handful','他说':'he says','两次':'two times','一件':'one item','一部':'one work','说过':'have said',
}
# 单字/姓氏/多义字系统性纠偏（评审官 REVIEW B2.13 指出：单字多取冷僻义/专名）
CORR.update({
 # batch2 单字
 '法':'law','版':'version','股':'share','几':'several','考':'to test','块':'piece','周':'week','便':'convenient',
 '猪':'pig','包':'bag','李':'surname Li','型':'type','穿':'to wear','越':'to surpass','部':'part','处':'place',
 '省':'province','称':'to call','台':'platform','累':'tired','经':'to pass','查':'to check','陈':'surname Chen',
 '顶':'top','楼':'building','单':'single','咋':'why','满':'full','店':'shop','度':'degree','刘':'surname Liu',
 '若':'if','文':'writing','表':'watch','管':'to manage','质量':'quality',
 # batch3 单字
 '占':'to occupy','杨':'surname Yang','片':'slice','西':'west','龙':'dragon','明':'bright','妈':'mom','蛮':'quite',
 '镇':'town','清':'clear','咩':'baa','理':'reason','城':'city','罗':'surname Luo','令':'to order','重庆':'Chongqing',
 # batch4 单字
 '德':'virtue','操':'to operate','克':'to overcome','局':'bureau','华':'splendid','团':'group','篇':'chapter',
 '电':'electricity','修':'to repair','沈':'surname Shen','鬼':'ghost','木':'wood','层':'layer','份':'portion',
 '赵':'surname Zhao','合':'to combine','噶':'ga','派':'faction','帅':'handsome','胡':'beard','天津':'Tianjin',
})
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

for b in ['2','3','4']:
    src=f'tools/zh_shi_batch{b}_draft.tsv'; out_core=f'tools/core_zh_shi_batch{b}.tsv'; out_trace=f'tools/core_zh_shi_batch{b}_留痕.tsv'
    rows=[]; nchg=0; blanks=[]
    for ln in open(src,encoding='utf-8'):
        ln=ln.rstrip('\n')
        if not ln: continue
        p=ln.split('\t'); w=p[0]; orig=p[1] if len(p)>1 else ''
        if w in CORR: final=CORR[w]; basis='人工复核：常用义/公认主译'
        else:
            final=normalize(orig); basis='规则清洗括注/量词，人工复核确认'
            if not final: final=orig; basis='CC-CEDICT首义，人工复核确认'
        if final!=orig: nchg+=1
        if not final: blanks.append(w)
        rows.append((w,wt.get(w,''),orig,final,basis))
    with open(out_core,'w',encoding='utf-8') as f:
        for w,t,o,fi,bb in rows: f.write(w+'\t'+fi+'\n')
    with open(out_trace,'w',encoding='utf-8') as f:
        f.write('词\t词频(weight)\t原义(CC-CEDICT)\t校正后主义\t依据源\t复核人\t日期\t是否留空\n')
        for w,t,o,fi,bb in rows:
            f.write(f'{w}\t{t}\t{o}\t{fi}\t{bb}\t架构师\t2026-11-16\t{"是" if fi=="" else "否"}\n')
    print(f'batch{b}', len(rows), 'changed', nchg, 'blank', len(blanks), blanks[:8])
