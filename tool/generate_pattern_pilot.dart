import 'dart:convert';
import 'dart:io';

/// Authored vocabulary is restricted to each source lesson and earlier lessons.
/// The tuples contain a slot, its Chinese meaning, and a concrete transfer task.
const _patterns = <String, Map<String, Object>>{
  'u1l2': {
    'id': 'name',
    'frame': 'My name is …',
    'prefix': 'My name is ',
    'suffix': '.',
    'meaning': '我叫……，用来介绍自己的姓名。',
    'slotRule': '空位填姓名。My name is 后面不再加 I 或 am，可口语缩写为 My name’s。练习按情境指定的姓名回答。',
    'slots': [
      ['Li Ming', '李明', '第一次见面，对方问你的名字。请介绍自己叫李明。'],
      ['Lucy', '露西', '加入新班级，请用本课句型介绍自己叫露西。'],
      ['Tom', '汤姆', '认识新朋友，请用本课句型介绍自己叫汤姆。'],
      ['Amy', '艾米', '在电话里介绍自己，请用本课句型说自己叫艾米。'],
    ],
    'review': [
      ['Amy', '报名时对方问你的姓名，请用本课句型回答你叫艾米。'],
      ['Li Ming', '同学还不知道你的名字，请用本课句型介绍你叫李明。'],
      ['Tom', '参加小组活动，请用本课句型介绍你叫汤姆。'],
      ['Lucy', '第一次参加聚会，请用本课句型介绍你叫露西。'],
    ],
  },
  'u4l1': {
    'id': 'like',
    'frame': 'I like …',
    'prefix': 'I like ',
    'suffix': '.',
    'meaning': '我喜欢……，用来表达喜好。',
    'slotRule': '泛指喜欢某种水果时，通常用复数，如 apples。先练名词，不把 like 后的空位当作任意动词。',
    'slots': [
      ['apples', '苹果', '朋友问你喜欢什么水果，请用本课句型表达你喜欢苹果。'],
      ['bananas', '香蕉', '挑选水果时，请用本课句型告诉同伴你喜欢香蕉。'],
      ['pears', '梨', '有人问你的口味，请用本课句型说你喜欢梨。'],
      ['watermelons', '西瓜', '讨论水果喜好，请用本课句型说你喜欢西瓜。'],
    ],
    'review': [
      ['watermelons', '同伴准备买水果，请用本课句型告诉他你喜欢西瓜。'],
      ['apples', '新朋友想了解你的喜好，请用本课句型说你喜欢苹果。'],
      ['pears', '家人询问你的水果喜好，请用本课句型说你喜欢梨。'],
      ['bananas', '在班里介绍自己的喜好，请用本课句型说你喜欢香蕉。'],
    ],
  },
  'u4l3': {
    'id': 'want',
    'frame': 'I want …',
    'prefix': 'I want ',
    'suffix': '.',
    'meaning': '我想要……，用来表达想要的东西。',
    'slotRule':
        '空位先练名词短语。water、milk、juice 不可数，可以加 some；一个苹果要说 an apple。I want 比 I would like 更直接。',
    'slots': [
      ['some water', '一些水', '口渴时向家人表达需要，请用本课句型说你想要一些水。'],
      ['some milk', '一些牛奶', '早餐时妈妈问你要什么，请用本课句型说你想要一些牛奶。'],
      ['some juice', '一些果汁', '朋友让你选饮料，请用本课句型说你想要一些果汁。'],
      ['an apple', '一个苹果', '挑选水果时，请用本课句型说你想要一个苹果。'],
    ],
    'review': [
      ['an apple', '家人准备水果，请用本课句型说你想要一个苹果。'],
      ['some milk', '朋友问你早餐要喝什么，请用本课句型说你想要一些牛奶。'],
      ['some water', '运动后选择饮料，请用本课句型说你想要一些水。'],
      ['some juice', '准备野餐饮料，请用本课句型说你想要一些果汁。'],
    ],
  },
  'u4l4': {
    'id': 'would_like',
    'frame': 'I would like …',
    'prefix': 'I would like ',
    'suffix': '.',
    'meaning': '我想要……，适合礼貌点餐或表达需求。',
    'slotRule':
        '空位填名词短语：a hamburger、a salad、some water。I would like 可缩写为 I’d like。本次练习用这一礼貌句型。',
    'slots': [
      ['a hamburger', '一个汉堡', '在餐厅点餐，请用本课礼貌句型点一个汉堡。'],
      ['a salad', '一份沙拉', '服务员问你想吃什么，请用本课礼貌句型点一份沙拉。'],
      ['a sandwich', '一个三明治', '在餐厅点午餐，请用本课礼貌句型点一个三明治。'],
      ['some water', '一些水', '在餐厅请服务员送水，请用本课礼貌句型要一些水。'],
    ],
    'review': [
      ['some milk', '在餐厅吃早餐，请用本课礼貌句型点一些牛奶。'],
      ['some juice', '服务员问你想喝什么，请用本课礼貌句型点一些果汁。'],
      ['an apple', '在餐厅选择水果，请用本课礼貌句型要一个苹果。'],
      ['some bread', '在餐厅吃早餐，请用本课礼貌句型要一些面包。'],
    ],
  },
  'u9l1': {
    'id': 'price',
    'frame': 'How much is …?',
    'prefix': 'How much is ',
    'suffix': '?',
    'meaning': '……多少钱？用来询问单个物品的价格。',
    'slotRule':
        '空位填单数物品，如 this shirt。复数物品要用 are，本次只练 is；this 表示“这件/这个”，不能随意改成 that。',
    'slots': [
      ['this shirt', '这件衬衫', '在服装店，请用本课句型询问这件衬衫多少钱。'],
      ['this bag', '这个包', '挑选一个包，请用本课句型询问这个包多少钱。'],
      ['this book', '这本书', '在书店，请用本课句型询问这本书多少钱。'],
      ['this apple', '这个苹果', '买一个苹果，请用本课句型询问这个苹果多少钱。'],
    ],
    'review': [
      ['this apple', '在水果店指着一个苹果，请用本课句型询问这个苹果的价格。'],
      ['this shirt', '准备结账前，请用本课句型再次确认这件衬衫多少钱。'],
      ['this book', '在书摊看到一本书，请用本课句型询问这本书多少钱。'],
      ['this bag', '在商店挑选礼物，请用本课句型询问这个包多少钱。'],
    ],
  },
  'u9l2': {
    'id': 'need',
    'frame': 'I need …',
    'prefix': 'I need ',
    'suffix': '.',
    'meaning': '我需要……，用来表达所需物品。',
    'slotRule':
        '空位填物品或数量短语。a shopping bag 是一个购物袋；some eggs 是一些鸡蛋。先练名词，不加入 need to 的动词用法。',
    'slots': [
      ['some milk', '一些牛奶', '准备早餐购物清单，请用本课句型说你需要一些牛奶。'],
      ['some eggs', '一些鸡蛋', '去超市前，请用本课句型说你需要一些鸡蛋。'],
      ['a shopping bag', '一个购物袋', '在超市结账，请用本课句型说你需要一个购物袋。'],
      ['some bread', '一些面包', '准备早餐，请用本课句型说你需要一些面包。'],
    ],
    'review': [
      ['some apples', '准备野餐清单，请用本课句型说你需要一些苹果。'],
      ['some water', '准备出门运动，请用本课句型说你需要一些水。'],
      ['some milk and eggs', '补充冰箱里的食物，请用本课句型说你需要一些牛奶和鸡蛋。'],
      ['a shopping bag', '买完东西后，请用本课句型向收银员说你需要一个购物袋。'],
    ],
  },
};

Map<String, dynamic> _exercise(
  String id,
  String type,
  String prompt,
  String sentence,
  String prefix,
  String slot,
  String suffix,
) {
  final alternatives = <String>[];
  if (type == 'translateInput') {
    if (prefix == 'My name is ') {
      alternatives.add("My name's $slot$suffix");
    }
    if (prefix == 'I would like ') {
      alternatives.add("I'd like $slot$suffix");
      alternatives.add('I would like $slot, please.');
      alternatives.add("I'd like $slot, please.");
    }
  }
  return {
    'id': id,
    'type': type,
    'prompt': prompt,
    'sentence': sentence,
    'options': <String>[],
    'answer': sentence,
    if (type == 'wordBank') 'tokens': [prefix.trim(), '$slot$suffix'],
    if (alternatives.isNotEmpty) 'acceptedAnswers': alternatives,
  };
}

String _meaning(String id, String slot) => switch (id) {
  'name' => '我叫$slot。',
  'like' => '我喜欢$slot。',
  'want' => '我想要$slot。',
  'would_like' => '我想要$slot。（礼貌点餐）',
  'price' => '$slot多少钱？',
  'need' => '我需要$slot。',
  _ => throw ArgumentError(id),
};

/// Returns a deep copy; all existing scored content and unknown metadata survive.
Map<String, dynamic> withPatternPilot(
  Map<String, dynamic> original, {
  bool refresh = false,
}) {
  final course = jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
  if (course['id'] != 'beginner') {
    throw ArgumentError('Expected beginner course');
  }
  final found = <String>{};
  for (final unit in course['units']) {
    for (final lesson in unit['lessons']) {
      final spec = _patterns[lesson['id']];
      if (spec == null) continue;
      found.add(lesson['id'] as String);
      // A rerun must not overwrite subsequent editorial revisions.
      if (lesson['patternTraining'] != null && !refresh) continue;
      final id = spec['id'] as String;
      final prefix = spec['prefix'] as String;
      final suffix = spec['suffix'] as String;
      final slots = spec['slots'] as List<List<String>>;
      Map<String, dynamic> item(
        String phase,
        int index,
        int slotIndex,
        String type,
        String prompt,
      ) {
        final slot = slots[slotIndex][0];
        return _exercise(
          'mp_${id}_$phase${index + 1}',
          type,
          prompt,
          '$prefix$slot$suffix',
          prefix,
          slot,
          suffix,
        );
      }

      lesson['patternTraining'] = {
        'id': 'en_$id',
        'version': 1,
        for (final key in ['frame', 'meaning', 'slotRule', 'prefix', 'suffix'])
          key: spec[key],
        'examples': [
          for (var i = 0; i < 3; i++)
            item('example', i, i, 'speaking', _meaning(id, slots[i][1])),
        ],
        'substitution': [
          for (var i = 0; i < 2; i++)
            item('substitution', i, i, 'wordBank', _meaning(id, slots[i][1])),
        ],
        'recall': [
          for (var i = 0; i < 2; i++)
            item(
              'recall',
              i,
              i + 2,
              'translateInput',
              _meaning(id, slots[i + 2][1]),
            ),
        ],
        'transfer': [
          for (var i = 0; i < 2; i++)
            item('transfer', i, i + 2, 'translateInput', slots[i + 2][2]),
        ],
        'review': [
          for (var i = 0; i < 4; i++)
            _exercise(
              'mp_${id}_review${i + 1}',
              'translateInput',
              (spec['review'] as List<List<String>>)[i][1],
              '$prefix${(spec['review'] as List<List<String>>)[i][0]}$suffix',
              prefix,
              (spec['review'] as List<List<String>>)[i][0],
              suffix,
            ),
        ],
      };
    }
  }
  if (found.length != _patterns.length) {
    throw StateError(
      'Missing pilot lessons: ${_patterns.keys.toSet().difference(found)}',
    );
  }
  return course;
}

void main(List<String> args) {
  final paths = args.where((arg) => !arg.startsWith('--')).toList();
  final path = paths.isEmpty
      ? 'assets/courses/course_beginner.json'
      : paths.first;
  final file = File(path);
  final course = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final result = withPatternPilot(course, refresh: args.contains('--refresh'));
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(result)}\n',
  );
  stdout.writeln('Mother-pattern pilot: 6 lessons, scored content preserved.');
}
