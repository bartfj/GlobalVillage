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
  'sanskrit': '''
元音与长短音|元音识读
a~短元音 a~अ~a
ā~长元音 ā~आ~ā
i~短元音 i~इ~i
ī~长元音 ī~ई~ī
u~短元音 u~उ~u
ū~长元音 ū~ऊ~ū
ṛ~元音 ṛ~ऋ~ṛ
e~元音 e（长音）~ए~e

辅音与文字|天城体与转写
ka~不送气软腭音 ka~क~ka
kha~送气软腭音 kha~ख~kha
ga~浊软腭音 ga~ग~ga
ca~不送气硬腭音 ca~च~ca
ṭa~卷舌音 ṭa~ट~ṭa
ta~齿音 ta~त~ta
pa~唇音 pa~प~pa
ma~鼻音 ma~म~ma

问候与自我介绍|基础交流
namaste~向你致敬（问候）~नमस्ते~namaste
mama nāma rāmaḥ~我的名字是罗摩~मम नाम रामः~mama|nāma|rāmaḥ
ahaṃ chātraḥ~我是男学生~अहं छात्रः~ahaṃ|chātraḥ
ahaṃ chātrā~我是女学生~अहं छात्रा~ahaṃ|chātrā
tava nāma kim~你的名字是什么~तव नाम किम्~tava|nāma|kim
ahaṃ paṭhāmi~我读书~अहं पठामि~ahaṃ|paṭhāmi
ahaṃ gacchāmi~我走（去）~अहं गच्छामि~ahaṃ|gacchāmi
ahaṃ likhāmi~我写~अहं लिखामि~ahaṃ|likhāmi

性别与基础语法|名词与动词
bālaḥ~男孩（阳性主格单数）~बालः~bālaḥ
bālā~女孩（阴性主格单数）~बाला~bālā
phalam~果实（中性主格或宾格单数）~फलम्~phalam
bālam~男孩（阳性宾格单数）~बालम्~bālam
bālaḥ paṭhati~男孩读书~बालः पठति~bālaḥ|paṭhati
bālā paṭhati~女孩读书~बाला पठति~bālā|paṭhati
ahaṃ phalaṃ khādāmi~我吃果实~अहं फलं खादामि~ahaṃ|phalaṃ|khādāmi
tvam paṭhasi~你读书（单数）~त्वम् पठसि~tvam|paṭhasi
''',
};

Map<String, String> generateLanguageCourses({bool write = true}) {
  final output = <String, String>{};
  final ledger = StringBuffer(
    '# 中文与梵文试点课程台账\n\n'
    '两种语言各16课，每单元8条核心语料交错复现。中文英语解释，梵文中文解释。'
    '梵文题目要求IAST输入，天城体仅作识读支架。无听力、跟读或口语评分。'
    '语料为初稿，专业教学审校、逐句发音及真实设备字体验收待完成。\n\n',
  );
  const selections = [
    [0, 1, 2, 3],
    [4, 5, 6, 7],
    [0, 2, 4, 6],
    [1, 3, 5, 7],
  ];
  for (final entry in material.entries) {
    final chinese = entry.key == 'chinese';
    final prefix = chinese ? 'zh_u' : 'sa_u';
    final units = <Map<String, dynamic>>[];
    final blocks = entry.value.trim().split(RegExp(r'\n\s*\n'));
    for (var u = 0; u < blocks.length; u++) {
      final lines = blocks[u].split('\n');
      final title = lines[0].split('|');
      final rows = lines.skip(1).map((l) => l.split('~')).toList();
      if (rows.length != 8 || rows.any((r) => r.length != 4)) {
        throw FormatException(title[0]);
      }
      final lessons = <Map<String, dynamic>>[];
      for (var l = 0; l < 4; l++) {
        final id = '$prefix${u + 1}l${l + 1}';
        final selected = [for (final i in selections[l]) rows[i]];
        final exercises = <Map<String, dynamic>>[];
        for (var e = 0; e < 9; e++) {
          final row = selected[e % 4];
          final type = e < 4
              ? 'translateChoice'
              : e < 7
              ? 'wordBank'
              : 'translateInput';
          final prompt = type == 'translateChoice'
              ? (chinese ? 'Choose: ${row[1]}' : '选择IAST：${row[1]}')
              : (chinese
                    ? 'Write ${u == 0 ? "tone-marked pinyin" : "simplified Chinese"}: ${row[1]}'
                    : '用IAST表达：${row[1]}');
          final options = selected.map((r) => r[0]).toList();
          final rotation = e % 4;
          exercises.add({
            'id': '${id}e${e + 1}',
            'type': type,
            'language': entry.key,
            'prompt': prompt,
            'sentence': row[0],
            'answer': row[0],
            'options': type == 'translateChoice'
                ? [...options.skip(rotation), ...options.take(rotation)]
                : [],
            'tokens': type == 'wordBank' ? row[3].split('|') : [],
            'tokenSeparator': chinese ? '' : ' ',
            if (type == 'translateChoice' && (!chinese || u == 0))
              'support': row[2],
          });
        }
        final lessonTitle = chinese
            ? ['初识表达', '场景应用', '交错复现', '综合表达'][l]
            : ['识读入门', '基础应用', '交错复现', '综合练习'][l];
        lessons.add({'id': id, 'title': lessonTitle, 'exercises': exercises});
        ledger.writeln(
          '## $id ${title[0]} · $lessonTitle\n\n'
          '- 阶段：${l < 2 ? "新授与应用" : "复现"}。\n'
          '- 输入要求：${chinese ? (u == 0 ? "带声调拼音" : "简体汉字") : "IAST，保留长短音、送气、卷舌及鼻音区别"}。\n'
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
    output['assets/courses/course_${entry.key}.json'] =
        '${const JsonEncoder.withIndent('  ').convert({'id': entry.key, 'title': chinese ? '普通话入门' : '梵文入门', 'language': entry.key, 'explanationLanguage': chinese ? 'english' : 'chinese', 'units': units})}\n';
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
