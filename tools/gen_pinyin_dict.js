// 生成「前缀排序」的拼音词典（供扩展 mmap 读取 + 前缀二分查找）。
// 仅 spike 用：真实规模（条目数/字节数量级与精简拼音词库一致），含少量真实样例便于演示「打拼音出候选」。
// 真实精简词库（常用字+2~5万词）到位后，同名替换 Keyboard/pinyin.txt 即可；footprint 主要由条目数/字节数决定。
const fs = require('fs');
const path = require('path');

// 常用无调拼音音节（覆盖普通话常用音节，用于合成多音节词）
const syllables = ('a ai an ang ao ba bai ban bang bao bei ben beng bi bian biao bie bin bing bo bu '
  + 'ca cai can cang cao ce cen ceng cha chai chan chang chao che chen cheng chi chong chou chu chuan chuang chui chun chuo '
  + 'ci cong cou cu cuan cui cun cuo da dai dan dang dao de dei deng di dian diao die ding dong dou du duan dui dun duo '
  + 'e en er fa fan fang fei fen feng fo fou fu ga gai gan gang gao ge gei gen geng gong gou gu gua guai guan guang gui gun guo '
  + 'ha hai han hang hao he hei hen heng hong hou hu hua huai huan huang hui hun huo ji jia jian jiang jiao jie jin jing jiong jiu ju juan jue jun '
  + 'ka kai kan kang kao ke ken keng kong kou ku kua kuai kuan kuang kui kun kuo la lai lan lang lao le lei leng li lian liang liao lie lin ling liu long lou lu luan lue lun luo lv '
  + 'ma mai man mang mao me mei men meng mi mian miao mie min ming miu mo mou mu na nai nan nang nao ne nei nen neng ni nian niang niao nie nin ning niu nong nu nuan nuo nv '
  + 'pa pai pan pang pao pei pen peng pi pian piao pie pin ping po pou pu qi qia qian qiang qiao qie qin qing qiong qiu qu quan que qun '
  + 'ran rang rao re ren reng ri rong rou ru ruan rui run ruo sa sai san sang sao se sen seng sha shai shan shang shao she shen sheng shi shou shu shua shuai shuan shuang shui shun shuo '
  + 'si song sou su suan sui sun suo ta tai tan tang tao te teng ti tian tiao tie ting tong tou tu tuan tui tun tuo '
  + 'wa wai wan wang wei wen weng wo wu xi xia xian xiang xiao xie xin xing xiong xiu xu xuan xue xun '
  + 'ya yan yang yao ye yi yin ying yong you yu yuan yue yun za zai zan zang zao ze zei zeng zha zhai zhan zhang zhao zhe zhen zheng zhi zhong zhou zhu zhuan zhuang zhui zhun zhuo '
  + 'zi zong zou zu zuan zui zun zuo').split(/\s+/).filter(Boolean);

// 常用汉字池（用于合成候选；仅撑规模与字节量，真实词库替换即可）
const hanziPool = ('的一是不了在人有我他这中大来上国个到说们为子和你地出道也时年得就那要下以生会自着去之过家学对可她里后小么心多天而能好都然没日于起还发成事只作当想看文无开手十用主行方又如前所本见经头面公同三已老从动两长知民样现分将外但身些与高意进把法此实回二理美点月明其种声全工己话儿者向情部正名定女问力机给等几很业最间新什打便位因重被走电四第门相次东政海口使教西再平真听世气信北少关并内加化由却代军产入先山五太水万市眼体别处总才场师书比住员九笑性通目华报立马命张活难神数件安表原车白应路期叫死常提感金何更反合放做系计或司利受光王果亲界及今京务制解各任至清物台象记边共风战干接它许八特觉望直服毛林题建南度统色字请交爱让认算论百吃义科怎元社术结六功指思非流每青管夫连远资队跟带花快条院变联言权往展该领传近留红治决周保达办运武半候七必城父强步完革深区即求品士转量空甚众技轻程告江语英基派满式李息写呢识极令黄德收脸钱党倒未持取设始版双历越史商千片容研像找友孩站广改议形委早房音火际则首单据导影失拿网香似斯专石若兵弟谁校读志飞观争究包组造落视济喜离虽坐集编宝谈府拉黑且随格尽剑讲布杀微怕母调局根曾准团段终乐切级克精哪官示冷').split('');

// 真实样例（便于演示）
const realPairs = [
  ['nihao', '你好'], ['nihao', '妮好'], ['xiexie', '谢谢'], ['women', '我们'],
  ['zhongguo', '中国'], ['shijie', '世界'], ['xuexi', '学习'], ['gongzuo', '工作'],
  ['pengyou', '朋友'], ['dianhua', '电话'], ['mingtian', '明天'], ['jintian', '今天'],
  ['zaijian', '再见'], ['duibuqi', '对不起'], ['meiguanxi', '没关系'], ['shengri', '生日'],
  ['gongsi', '公司'], ['yinhang', '银行'], ['fanyi', '翻译'], ['shurufa', '输入法'],
  ['pinyin', '拼音'], ['shouji', '手机'], ['diannao', '电脑'], ['wangluo', '网络'],
  ['nihao', '拟好'], ['zhongwen', '中文'], ['yingwen', '英文'], ['wanzheng', '完整'],
];

const TARGET = 60000;
const rows = [];
for (const [p, h] of realPairs) rows.push(p + '\t' + h);

function pick(a) { return a[Math.floor(Math.random() * a.length)]; }

while (rows.length < TARGET) {
  // 1~4 音节（加权：2 音节居多，接近中文词长分布）
  const r = Math.random();
  const k = r < 0.12 ? 1 : r < 0.62 ? 2 : r < 0.90 ? 3 : 4;
  let pinyin = '';
  for (let i = 0; i < k; i++) pinyin += pick(syllables);
  let hanzi = '';
  const hk = Math.random() < 0.85 ? k : 1;
  for (let i = 0; i < hk; i++) hanzi += pick(hanziPool);
  rows.push(pinyin + '\t' + hanzi);
}

// 按「键」排序，保证前缀查找落在连续区间
rows.sort((a, b) => {
  const ka = a.slice(0, a.indexOf('\t'));
  const kb = b.slice(0, b.indexOf('\t'));
  return ka < kb ? -1 : ka > kb ? 1 : 0;
});

fs.mkdirSync(path.join(__dirname, '..', 'Keyboard'), { recursive: true });
const out = path.join(__dirname, '..', 'Keyboard', 'pinyin.txt');
const buf = Buffer.from(rows.join('\n') + '\n', 'utf8');
fs.writeFileSync(out, buf);
console.log('pinyin.txt written:', rows.length, 'entries,', buf.length, 'bytes ->', out);
