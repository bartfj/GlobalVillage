import 'dart:convert';
import 'dart:io';

// Target, teaching translation, reading support, explicit word blocks.
const material = {
  'chinese': '''
拼音与声调|Pinyin and tones
mā~mother (pinyin, first tone)~妈~mā
má~hemp (pinyin, second tone)~麻~má
mǎ~horse (pinyin, third tone)~马~mǎ
mà~scold (pinyin, fourth tone)~骂~mà
bā~eight (pinyin, first tone)~八~bā
bá~pull out (pinyin, second tone)~拔~bá
bǎ~hold (pinyin, third tone)~把~bǎ
bà~dad (pinyin, fourth tone)~爸~bà

问候与介绍|Greetings and introductions
你好~Hello~nǐ hǎo~你|好
谢谢~Thank you~xièxie~谢谢
再见~Goodbye~zàijiàn~再见
我叫安娜~My name is Anna~wǒ jiào Ānnà~我|叫|安娜
我是学生~I am a student~wǒ shì xuésheng~我|是|学生
你叫什么名字~What is your name~nǐ jiào shénme míngzi~你|叫|什么|名字
很高兴认识你~Nice to meet you~hěn gāoxìng rènshi nǐ~很|高兴|认识|你
不客气~You are welcome~bú kèqi~不|客气

数字与物品|Numbers and objects
一~one~yī~一
二~two~èr~二
三~three~sān~三
这是书~This is a book~zhè shì shū~这|是|书
一个人~one person~yí ge rén~一|个|人
两本书~two books~liǎng běn shū~两|本|书
我有三个杯子~I have three cups~wǒ yǒu sān ge bēizi~我|有|三|个|杯子
那是我的老师~That is my teacher~nà shì wǒ de lǎoshī~那|是|我|的|老师

生活请求|Everyday requests
请给我水~Please give me water~qǐng gěi wǒ shuǐ~请|给|我|水
我要一杯茶~I would like a cup of tea~wǒ yào yì bēi chá~我|要|一|杯|茶
这个多少钱~How much is this~zhège duōshao qián~这个|多少|钱
我要这个~I would like this one~wǒ yào zhège~我|要|这个
请说慢一点~Please speak a little more slowly~qǐng shuō màn yìdiǎn~请|说|慢|一点
请再说一遍~Please say it again~qǐng zài shuō yí biàn~请|再|说|一|遍
我不明白~I do not understand~wǒ bù míngbai~我|不|明白
可以帮我吗~Can you help me~kěyǐ bāng wǒ ma~可以|帮|我|吗
''',
  // 梵文递进原则：后一单元的天城体词只使用前面单元教过的字母与元音符号；
  // 含未教字母的词（如 namaste 的复合辅音 स्त）必须标注“整体认读”。
  'sanskrit': '''
元音与长短音|元音识读
a~短元音 a~अ~a
ā~长元音 ā~आ~ā
i~短元音 i~इ~i
ī~长元音 ī~ई~ī
u~短元音 u~उ~u
ū~长元音 ū~ऊ~ū
e~元音 e（长音）~ए~e
o~元音 o（长音）~ओ~o

辅音与音节|辅音加元音拼成音节
ka~辅音 ka（自带元音 a）~क~ka
kā~k 加长 ā 是 kā~का~kā
ki~k 加短 i 是 ki~कि~ki
kī~k 加长 ī 是 kī~की~kī
ma~鼻音 ma~म~ma
na~鼻音 na~न~na
ta~齿音 ta~त~ta
ṭa~卷舌音 ṭa~ट~ṭa

单词与问候|只用已教字母组成的词
namaste~向你致敬（问候，整体认读）~नमस्ते~namaste
mama~我的~मम~mama
nāma~名字~नाम~nāma
mama nāma~我的名字~मम नाम~mama|nāma
āma~芒果~आम~āma
kāka~乌鸦~काक~kāka
naṭa~演员~नट~naṭa
maṭa~小屋~मट~maṭa

人称与动作|我、你、他加动词
ahaṃ~我~अहम्~ahaṃ
tvam~你~त्वम्~tvam
ahaṃ paṭhāmi~我读书~अहं पठामि~ahaṃ|paṭhāmi
tvam paṭhasi~你读书~त्वं पठसि~tvam|paṭhasi
naṭaḥ paṭhati~演员读书~नटः पठति~naṭaḥ|paṭhati
ahaṃ gacchāmi~我去~अहं गच्छामि~ahaṃ|gacchāmi
tvam gacchasi~你去~त्वं गच्छसि~tvam|gacchasi
naṭaḥ gacchati~演员去~नटः गच्छति~naṭaḥ|gacchati
''',
};

/// 一条系统课程：由若干单元（从该语言语料按全局序号取）组成。
/// 零基础课程只含字母/拼音单元，入门课程承接使用场景。
class _CourseSpec {
  const _CourseSpec({
    required this.assetPath,
    required this.id,
    required this.title,
    required this.language,
    required this.explanationLanguage,
    required this.unitIndexes,
  });

  final String assetPath;
  final String id;
  final String title;
  final String language;
  final String explanationLanguage;
  final List<int> unitIndexes;
}

const _courseSpecs = [
  _CourseSpec(
    assetPath: 'assets/courses/course_chinese_zero.json',
    id: 'chineseZero',
    title: '中文零基础',
    language: 'chinese',
    explanationLanguage: 'english',
    unitIndexes: [0],
  ),
  _CourseSpec(
    assetPath: 'assets/courses/course_chinese.json',
    id: 'chinese',
    title: '普通话入门',
    language: 'chinese',
    explanationLanguage: 'english',
    unitIndexes: [1, 2, 3],
  ),
  _CourseSpec(
    assetPath: 'assets/courses/course_sanskrit_zero.json',
    id: 'sanskritZero',
    title: '梵文零基础',
    language: 'sanskrit',
    explanationLanguage: 'chinese',
    unitIndexes: [0, 1],
  ),
  _CourseSpec(
    assetPath: 'assets/courses/course_sanskrit.json',
    id: 'sanskrit',
    title: '梵文入门',
    language: 'sanskrit',
    explanationLanguage: 'chinese',
    unitIndexes: [2, 3],
  ),
];

Map<String, String> generateLanguageCourses({bool write = true}) {
  final output = <String, String>{};
  final ledger = StringBuffer(
    '# 中文与梵文课程台账\n\n'
    '中文、梵文各分两条系统课程：零基础课只含拼音/字母单元，入门课承接词句与使用场景。'
    '每单元8条核心语料交错复现。中文英语解释，梵文中文解释。'
    '梵文题目要求IAST输入，天城体仅作识读支架。'
    '中文零基础单元含听音辨调题（系统中文语音或内置音频）；两者均无跟读与口语评分。'
    '梵文单元间保持字母依赖：后单元天城体词只使用已教字母与元音符号，'
    '例外词（namaste）标注整体认读。'
    '语料为初稿，专业教学审校、逐句发音及真实设备字体验收待完成。\n\n',
  );
  const selections = [
    [0, 1, 2, 3],
    [4, 5, 6, 7],
    [0, 2, 4, 6],
    [1, 3, 5, 7],
  ];
  for (final entry in material.entries) {
    final language = entry.key;
    final chinese = language == 'chinese';
    final prefix = chinese ? 'zh_u' : 'sa_u';
    final blocks = entry.value.trim().split(RegExp(r'\n\s*\n'));
    for (var u = 0; u < blocks.length; u++) {
      final lines = blocks[u].split('\n');
      if (lines.length != 9) throw FormatException(lines.first);
      final rows = lines.skip(1).map((l) => l.split('~')).toList();
      if (rows.length != 8 || rows.any((r) => r.length != 4)) {
        throw FormatException(lines.first);
      }
    }
    for (final spec in _courseSpecs.where((s) => s.language == language)) {
      final units = <Map<String, dynamic>>[];
      for (final u in spec.unitIndexes) {
        final lines = blocks[u].split('\n');
        final title = lines[0].split('|');
        final rows = lines.skip(1).map((l) => l.split('~')).toList();
        final lessons = <Map<String, dynamic>>[];
        for (var l = 0; l < 4; l++) {
          final id = '$prefix${u + 1}l${l + 1}';
          final selected = [for (final i in selections[l]) rows[i]];
          final exercises = <Map<String, dynamic>>[];
          for (var e = 0; e < 9; e++) {
            final row = selected[e % 4];
            // 中文零基础第 2 题改为听音辨调：播放汉字读音，选带声调拼音。
            final listening = chinese && u == 0 && e == 1;
            final type = listening
                ? 'listeningChoice'
                : e < 4
                ? 'translateChoice'
                : e < 7
                ? 'wordBank'
                : 'translateInput';
            final prompt = listening
                ? 'Listen and choose the tone you hear'
                : type == 'translateChoice'
                ? (chinese ? 'Choose: ${row[1]}' : '选择IAST：${row[1]}')
                : (chinese
                      ? 'Write ${u == 0 ? "tone-marked pinyin" : "simplified Chinese"}: ${row[1]}'
                      : '用IAST表达：${row[1]}');
            final options = selected.map((r) => r[0]).toList();
            final rotation = e % 4;
            exercises.add({
              'id': '${id}e${e + 1}',
              'type': type,
              'language': language,
              'prompt': prompt,
              'sentence': row[0],
              'answer': row[0],
              'options': type == 'translateChoice' || listening
                  ? [...options.skip(rotation), ...options.take(rotation)]
                  : [],
              'tokens': type == 'wordBank' ? row[3].split('|') : [],
              'tokenSeparator': chinese ? '' : ' ',
              if ((type == 'translateChoice' || listening) &&
                  (!chinese || u == 0))
                'support': row[2],
            });
          }
          final lessonTitle = chinese
              ? ['初识表达', '场景应用', '交错复现', '综合表达'][l]
              : ['识读入门', '基础应用', '交错复现', '综合练习'][l];
          lessons.add({'id': id, 'title': lessonTitle, 'exercises': exercises});
          ledger.writeln(
            '## ${spec.id} / $id ${title[0]} · $lessonTitle\n\n'
            '- 阶段：${l < 2 ? "新授与应用" : "复现"}。\n'
            '- 输入要求：${chinese ? (u == 0 ? "带声调拼音" : "简体汉字") : "IAST，保留长短音、送气、卷舌及鼻音区别"}。\n'
            '${chinese && u == 0 ? "- 听辨：第2题播放汉字读音，选出带声调拼音（依赖系统中文语音包，缺失时可下载音频）。\n" : ""}'
            '- 核心语料：${selected.map((r) => "${r[0]} / ${r[2]} / ${r[1]}").join("；")}\n'
            '- 审校状态：待专业复核。\n',
          );
        }
        units.add({
          'id': '$prefix${u + 1}',
          'title': title[0],
          'description': title[1],
          'lessons': lessons,
        });
      }
      output[spec.assetPath] =
          '${const JsonEncoder.withIndent('  ').convert({'id': spec.id, 'title': spec.title, 'language': spec.language, 'explanationLanguage': spec.explanationLanguage, 'units': units})}\n';
    }
  }
  output['docs/中文与梵文试点课程台账.md'] = '${ledger.toString().trimRight()}\n';
  if (write) {
    for (final e in output.entries) {
      File(e.key).writeAsStringSync(e.value);
    }
  }
  return output;
}

void main() => generateLanguageCourses();
