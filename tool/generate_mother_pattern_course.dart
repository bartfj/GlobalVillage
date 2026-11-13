import 'dart:convert';
import 'dart:io';

const motherPatternAssetPath = 'assets/courses/course_mother_pattern.json';
const _encoder = JsonEncoder.withIndent('  ');

class _Slot {
  final String text;
  final String meaning;
  final String scene;
  const _Slot(this.text, this.meaning, this.scene);
}

class _Frame {
  final String id;
  final String frame;
  final String prefix;
  final String suffix;
  final String title;
  final String meaning;
  final String rule;
  final List<String> limitations;
  final List<_Slot> slots;
  final List<(String, String, String)> dialogue;
  final List<(String, String)> chunks;
  const _Frame({
    required this.id,
    required this.frame,
    required this.prefix,
    this.suffix = '.',
    required this.title,
    required this.meaning,
    required this.rule,
    required this.limitations,
    required this.slots,
    required this.dialogue,
    required this.chunks,
  });
}

const _frames = <_Frame>[
  _Frame(
    id: 'am',
    frame: 'I am …',
    prefix: 'I am ',
    title: '介绍身份与状态',
    meaning: '我是……／我现在……，用来介绍自己的身份或状态。',
    rule:
        '姓名直接放在 am 后；单数身份名词前加 a，如 a student；状态形容词直接放在 am 后，如 happy。I am 可缩写为 I’m。',
    limitations: [
      '本课只练 I am，不把主语换成 you 或 he。',
      '只替换已教的姓名、身份和状态，不在 am 后直接加普通动作动词。',
    ],
    slots: [
      _Slot('Tom', '汤姆', '你是汤姆，第一次见面时向同学介绍自己是谁。'),
      _Slot('a student', '一名学生', '你是一名学生，老师询问你的身份，请向老师说明。'),
      _Slot('happy', '开心的', '朋友问你的状态，你现在很开心，请告诉朋友。'),
      _Slot('ready', '准备好的', '老师准备开始活动，你已经准备好了，请告诉老师你的状态。'),
    ],
    dialogue: [
      ('Tom', 'Hello. I am Tom.', '你好。我是汤姆。'),
      ('Amy', 'Hello. I am Amy.', '你好。我是艾米。'),
      ('Tom', 'I am a student.', '我是一名学生。'),
      ('Amy', 'I am happy.', '我很开心。'),
    ],
    chunks: [
      ('I am', '我是……／我现在……'),
      ("I'm", 'I am 的口语缩写'),
      ('a student', '一名学生'),
      ('happy', '开心的'),
      ('ready', '准备好的'),
    ],
  ),
  _Frame(
    id: 'name',
    frame: 'My name is …',
    prefix: 'My name is ',
    title: '介绍姓名',
    meaning: '我叫……，用来回答自己的姓名。',
    rule:
        '空位只放姓名。My name is 可缩写为 My name’s；不要把 is 再换成 am。对方问 What is your name? 时可以使用本句型。',
    limitations: ['本课回答自己的姓名，不说对方的姓名。', '场景指定姓名，不能换成另一个人。'],
    slots: [
      _Slot('Tom', '汤姆', '你是汤姆，报名老师问你的姓名，请告诉老师你叫什么。'),
      _Slot('Amy', '艾米', '你是艾米，新同学问你的姓名，请向同学介绍自己的名字。'),
      _Slot('Li Ming', '李明', '你是李明，参加小组时主持人问你的姓名，请回答。'),
      _Slot('Lucy', '露西', '你是露西，在电话里向新同学介绍自己的姓名。'),
    ],
    dialogue: [
      ('Tom', 'What is your name?', '你叫什么名字？'),
      ('Amy', 'My name is Amy.', '我叫艾米。'),
      ('Tom', 'My name is Tom. Nice to meet you.', '我叫汤姆。很高兴认识你。'),
      ('Amy', 'Nice to meet you, too.', '我也很高兴认识你。'),
    ],
    chunks: [
      ('My name is', '我叫……'),
      ("My name's", 'My name is 的口语缩写'),
      ('What is your name?', '你叫什么名字？'),
      ('Nice to meet you.', '很高兴认识你。'),
      ('Li Ming', '李明（姓名）'),
    ],
  ),
  _Frame(
    id: 'this',
    frame: 'This is …',
    prefix: 'This is ',
    title: '介绍身边的人和物',
    meaning: '这是……，用来介绍身边的人或单个物品。',
    rule:
        'This is 后放一个人或物品。说“我的朋友艾米”用 my friend Amy；说“一本书”用 a book。介绍多件物品需要其他句型，本课只练单数。',
    limitations: ['this 指近处的一个人或物，不随意换成 that。', '不省略单数可数物品前的 a，也不把 is 换成 are。'],
    slots: [
      _Slot('my friend Amy', '我的朋友艾米', '你向老师介绍站在身边的朋友艾米，请说明她是你的朋友。'),
      _Slot('my teacher Tom', '我的老师汤姆', '你向朋友介绍身边的老师汤姆，请说明他是你的老师。'),
      _Slot('a book', '一本书', '你向小朋友展示手中这一本书，请说明这是什么物品。'),
      _Slot('a bag', '一个包', '你向小朋友展示手中这一个包，请说明这是什么物品。'),
    ],
    dialogue: [
      ('Tom', 'This is my friend Amy.', '这是我的朋友艾米。'),
      ('Lucy', 'Hello, Amy.', '你好，艾米。'),
      ('Amy', 'This is a book.', '这是一本书。'),
      ('Lucy', 'Thank you.', '谢谢你。'),
    ],
    chunks: [
      ('This is', '这是……'),
      ('my friend Amy', '我的朋友艾米'),
      ('my teacher Tom', '我的老师汤姆'),
      ('a book', '一本书'),
      ('a bag', '一个包'),
      ('Thank you.', '谢谢你。'),
    ],
  ),
  _Frame(
    id: 'like',
    frame: 'I like …',
    prefix: 'I like ',
    title: '表达喜好',
    meaning: '我喜欢……，用来表达平常的喜好。',
    rule:
        '泛指喜欢苹果、香蕉时用复数 apples、bananas；tea、milk 是不可数名词，表达一般喜好时不加 a。本课不练 like 后接动词的用法。',
    limitations: [
      '本课说自己的喜好，主语用 I。',
      '喜好中的 apples 不等于点餐中的 an apple；不要添加数量或换成想要的句型。',
    ],
    slots: [
      _Slot('apples', '苹果', '朋友为野餐挑水果，问你的平常喜好，请告诉朋友你喜欢苹果。'),
      _Slot('bananas', '香蕉', '家人问你平常喜欢哪种水果，请说你喜欢香蕉。'),
      _Slot('tea', '茶', '朋友想了解你的饮品喜好，请告诉朋友你平常喜欢茶。'),
      _Slot('milk', '牛奶', '同学询问你平常喜欢什么饮品，请说你喜欢牛奶。'),
    ],
    dialogue: [
      ('Amy', 'Do you like apples?', '你喜欢苹果吗？'),
      ('Tom', 'I like apples.', '我喜欢苹果。'),
      ('Amy', 'I like tea, too.', '我也喜欢茶。'),
      ('Tom', 'I like milk.', '我喜欢牛奶。'),
    ],
    chunks: [
      ('I like', '我喜欢……'),
      ('Do you like apples?', '你喜欢苹果吗？'),
      ('apples', '苹果（复数，泛指喜好）'),
      ('bananas', '香蕉（复数）'),
      ('tea', '茶（不可数）'),
      ('milk', '牛奶（不可数）'),
    ],
  ),
  _Frame(
    id: 'dont_like',
    frame: 'I don’t like …',
    prefix: "I don't like ",
    title: '表达不喜欢',
    meaning: '我不喜欢……，用来表达不喜欢的东西。',
    rule:
        'don’t 是 do not 的缩写。完整说法 I do not like 和缩写 I don’t like 都接受；like 后仍用泛指复数水果或不可数饮品。',
    limitations: ['不喜欢必须保留 don’t 或 do not，不能省略否定。', '本课不使用 doesn’t，不添加任意数量。'],
    slots: [
      _Slot('apples', '苹果', '朋友问你的水果喜好，你平常不喜欢苹果，请告诉朋友。'),
      _Slot('bananas', '香蕉', '家人准备水果，你平常不喜欢香蕉，请表达这个喜好。'),
      _Slot('tea', '茶', '同学询问饮品喜好，你平常不喜欢茶，请告诉同学。'),
      _Slot('milk', '牛奶', '朋友问你平常是否喜欢牛奶，你不喜欢，请说明。'),
    ],
    dialogue: [
      ('Amy', 'Do you like tea?', '你喜欢茶吗？'),
      ('Tom', "I don't like tea.", '我不喜欢茶。'),
      ('Amy', 'I like milk.', '我喜欢牛奶。'),
      ('Tom', "I don't like milk.", '我不喜欢牛奶。'),
    ],
    chunks: [
      ("I don't like", '我不喜欢……'),
      ('I do not like', 'I don’t like 的完整形式'),
      ('Do you like tea?', '你喜欢茶吗？'),
      ('apples', '苹果（复数）'),
      ('bananas', '香蕉（复数）'),
      ('tea', '茶'),
      ('milk', '牛奶'),
    ],
  ),
  _Frame(
    id: 'do_you_like',
    frame: 'Do you like …?',
    prefix: 'Do you like ',
    suffix: '?',
    title: '询问对方的喜好',
    meaning: '你喜欢……吗？用来询问另一个人的喜好。',
    rule:
        'Do 放在句首，接 you like 和名词。本课问题可用 Yes, I do.／No, I don’t. 作简短回答。练习要求提问时，必须问对方而不是陈述自己的喜好。',
    limitations: ['主语是 you，不换成 I。', '泛指水果用 apples、bananas，不添加一两个的数量。'],
    slots: [
      _Slot('apples', '苹果', '你准备和朋友买水果，想知道朋友平常是否喜欢苹果，请向朋友提问。'),
      _Slot('bananas', '香蕉', '你为同学准备水果，想知道同学平常是否喜欢香蕉，请提问。'),
      _Slot('tea', '茶', '你和朋友讨论饮品，想知道朋友平常是否喜欢茶，请提问。'),
      _Slot('milk', '牛奶', '你为同学准备早餐，想知道同学平常是否喜欢牛奶，请提问。'),
    ],
    dialogue: [
      ('Amy', 'Do you like tea?', '你喜欢茶吗？'),
      ('Tom', 'Yes, I do.', '是的，我喜欢。'),
      ('Amy', 'Do you like milk?', '你喜欢牛奶吗？'),
      ('Tom', "No, I don't.", '不，我不喜欢。'),
    ],
    chunks: [
      ('Do you like', '你喜欢……吗？'),
      ('Yes, I do.', '是的，我喜欢。'),
      ("No, I don't.", '不，我不喜欢。'),
      ('apples', '苹果（复数）'),
      ('bananas', '香蕉（复数）'),
      ('tea', '茶'),
      ('milk', '牛奶'),
    ],
  ),
  _Frame(
    id: 'need',
    frame: 'I need …',
    prefix: 'I need ',
    title: '表达实际需要',
    meaning: '我需要……，用来说明完成事情所需的物品。',
    rule:
        '空位填物品：一个用 a（a pen、a book），两个包用 two bags；water 不可数，“一些水”用 some water。本课只练 need 后接名词。递交物品的人可以说 Here you are.（给你。）。',
    limitations: [
      'need 表达需要，不随意换成 want。',
      '场景中的一个、两个、一些必须保持，不使用 need to 的动作结构。',
    ],
    slots: [
      _Slot('a pen', '一支笔', '你在教室里要写字但没有笔，请向老师说明你需要一支笔。'),
      _Slot('a book', '一本书', '你准备阅读但没有书，请向老师说明你需要一本书。'),
      _Slot('some water', '一些水', '你运动后口渴，请向家人说明你需要一些水。'),
      _Slot('two bags', '两个包', '你要把两组物品分别装好，请向家人说明你需要两个包。'),
    ],
    dialogue: [
      ('Tom', 'I need a pen.', '我需要一支笔。'),
      ('Amy', 'Here you are.', '给你。'),
      ('Tom', 'I need a book, too.', '我还需要一本书。'),
      ('Amy', 'Here you are.', '给你。'),
    ],
    chunks: [
      ('I need', '我需要……'),
      ('a pen', '一支笔'),
      ('a book', '一本书'),
      ('some water', '一些水'),
      ('two bags', '两个包'),
      ('Here you are.', '给你。（把对方需要的物品递给对方时说）'),
    ],
  ),
  _Frame(
    id: 'want',
    frame: 'I want …',
    prefix: 'I want ',
    title: '表达想要的东西',
    meaning: '我想要……，用来直接表达想得到的东西。',
    rule:
        '一个苹果用 an apple；两个香蕉用 two bananas；milk 不可数，“一些牛奶”用 some milk。I want 比 I would like 更直接，本课在家人朋友之间表达想要。',
    limitations: [
      '保持指定物品和数量，不把 an apple 改为 apples。',
      '本课不用 want to 的动词结构，也不把 want 改成 need。',
    ],
    slots: [
      _Slot('an apple', '一个苹果', '在家里选水果，家人问你想要什么，请直接说你想要一个苹果。'),
      _Slot('some milk', '一些牛奶', '早餐时家人问你想喝什么，请直接说你想要一些牛奶。'),
      _Slot('two bananas', '两个香蕉', '朋友给你选野餐水果，请直接告诉朋友你想要两个香蕉。'),
      _Slot('a bag', '一个包', '家人让你选择用品，请直接说你想要一个包。'),
    ],
    dialogue: [
      ('Tom', 'I want an apple.', '我想要一个苹果。'),
      ('Amy', 'I want two bananas.', '我想要两个香蕉。'),
      ('Tom', 'I want some milk, too.', '我还想要一些牛奶。'),
      ('Amy', 'I like milk.', '我喜欢牛奶。'),
    ],
    chunks: [
      ('I want', '我想要……'),
      ('an apple', '一个苹果'),
      ('some milk', '一些牛奶'),
      ('two bananas', '两个香蕉'),
      ('a bag', '一个包'),
    ],
  ),
  _Frame(
    id: 'would_like',
    frame: 'I would like …',
    prefix: 'I would like ',
    title: '礼貌点餐',
    meaning: '我想要……，适合礼貌点餐或提出需求。',
    rule:
        'I would like 可缩写为 I’d like。空位是名词短语：a sandwich、some tea、two apples、some water。句尾可以加 please；本课礼貌任务不接受更直接的 I want。',
    limitations: [
      '保持 a／some／two 的数量，不替换指定食物饮品。',
      '本课只练名词短语，不加入 would like to 的动词结构。',
    ],
    slots: [
      _Slot('a sandwich', '一个三明治', '你在咖啡店向服务员点午餐，请礼貌地要一个三明治。'),
      _Slot('some tea', '一些茶', '服务员问你想喝什么，请礼貌地要一些茶。'),
      _Slot('two apples', '两个苹果', '你在餐厅给两个人选水果，请向服务员礼貌地要两个苹果。'),
      _Slot('some water', '一些水', '你在餐厅用餐口渴，请向服务员礼貌地要一些水。'),
    ],
    dialogue: [
      ('Tom', 'I would like a sandwich, please.', '我想要一个三明治，谢谢。'),
      ('Amy', 'I would like some tea, please.', '我想要一些茶，谢谢。'),
      ('Server', 'Here you are.', '给你。'),
      ('Tom', 'Thank you.', '谢谢你。'),
    ],
    chunks: [
      ('I would like', '我想要……（礼貌）'),
      ("I'd like", 'I would like 的口语缩写'),
      ('a sandwich', '一个三明治'),
      ('some tea', '一些茶'),
      ('two apples', '两个苹果'),
      ('some water', '一些水'),
      ('please', '请；用来使请求更礼貌'),
      ('Here you are.', '给你。'),
    ],
  ),
  _Frame(
    id: 'what_this',
    frame: 'What is this?',
    prefix: 'What is this',
    suffix: '?',
    title: '询问近处物品是什么',
    meaning: '这是什么？当你不知道近处一个物品的名称时使用。',
    rule:
        '本句型是固定问题，没有名词空位。面对不同的近处物品都可以问 What is this?，口语可缩写为 What’s this?。对方用 This is a book. 等句子回答。',
    limitations: [
      '不把物品名称加到 this 后，不说 What is this book?。',
      '本课只问近处单个物品，不换成 that 或复数 these。',
    ],
    slots: [
      _Slot('', '这是什么？', '你在书桌旁看到一本不认识的书，指着近处这一个物品，向老师询问它是什么；不要说出物品名称。'),
      _Slot('', '这是什么？', '你在商店看到近处一个不认识的包，指着它向店员询问它是什么；不要说出物品名称。'),
      _Slot('', '这是什么？', '你在教室看到近处一支不认识的笔，指着它向老师询问它是什么；不要说出物品名称。'),
      _Slot('', '这是什么？', '你在水果摊看到近处一个不认识的苹果，指着它向店员询问它是什么；不要说出物品名称。'),
    ],
    dialogue: [
      ('Tom', 'What is this?', '这是什么？'),
      ('Amy', 'This is a book.', '这是一本书。'),
      ('Tom', 'What is this?', '这是什么？'),
      ('Amy', 'This is a pen.', '这是一支笔。'),
    ],
    chunks: [
      ('What is this?', '这是什么？（固定问题）'),
      ("What's this?", 'What is this? 的口语缩写'),
      ('This is a book.', '这是一本书。'),
      ('a bag', '一个包'),
      ('a pen', '一支笔'),
      ('an apple', '一个苹果'),
    ],
  ),
  _Frame(
    id: 'price',
    frame: 'How much is …?',
    prefix: 'How much is ',
    suffix: '?',
    title: '询问单个商品的价格',
    meaning: '……多少钱？用来询问近处单个商品的价格。',
    rule:
        '空位放单数商品，如 this book、this bag。How much is this book? 问这一本书的价格；对方可以回答 It is five yuan.。复数价格用 are，本课不练。',
    limitations: ['this 指眼前的这一个，不能换成 that。', '保持单数物品和 is，不改成 are these books。'],
    slots: [
      _Slot('this book', '这本书', '你在书店指着眼前这一本书，向店员询问这本书的价格。'),
      _Slot('this bag', '这个包', '你在商店指着眼前这一个包，向店员询问这个包的价格。'),
      _Slot('this pen', '这支笔', '你在文具店指着眼前这一支笔，向店员询问这支笔的价格。'),
      _Slot('this apple', '这个苹果', '你在水果摊指着眼前这一个苹果，向店员询问这个苹果的价格。'),
    ],
    dialogue: [
      ('Tom', 'How much is this book?', '这本书多少钱？'),
      ('Seller', 'It is five yuan.', '它五元。'),
      ('Tom', 'How much is this pen?', '这支笔多少钱？'),
      ('Seller', 'It is two yuan.', '它两元。'),
    ],
    chunks: [
      ('How much is', '……多少钱？（单数物品）'),
      ('this book', '这本书'),
      ('this bag', '这个包'),
      ('this pen', '这支笔'),
      ('this apple', '这个苹果'),
      ('It is five yuan.', '它五元。'),
      ('It is two yuan.', '它两元。'),
    ],
  ),
  _Frame(
    id: 'can_have',
    frame: 'Can I have …?',
    prefix: 'Can I have ',
    suffix: '?',
    title: '请求取得物品',
    meaning: '我可以要……吗？向对方请求物品。',
    rule:
        'Can I have 后填物品和数量：a bag、two apples、some water、a pen；句尾可以加 please。与 I want 的直接表达不同，本课要向对方提出请求。',
    limitations: ['本课请求自己要物品，保留 I，不换成 you。', '物品和 a／two／some 的数量必须与场景一致。'],
    slots: [
      _Slot('a bag', '一个包', '你在商店结账，请向店员请求一个包来装东西。'),
      _Slot('two apples', '两个苹果', '你在水果摊购买水果，请向店员请求两个苹果。'),
      _Slot('some water', '一些水', '你在餐厅用餐，请向服务员请求一些水。'),
      _Slot('a pen', '一支笔', '你在教室填表，请向老师请求一支笔。'),
    ],
    dialogue: [
      ('Tom', 'Can I have a bag, please?', '我可以要一个包吗？'),
      ('Seller', 'Here you are.', '给你。'),
      ('Tom', 'Can I have two apples, please?', '我可以要两个苹果吗？'),
      ('Seller', 'Here you are.', '给你。'),
    ],
    chunks: [
      ('Can I have', '我可以要……吗？'),
      ('a bag', '一个包'),
      ('two apples', '两个苹果'),
      ('some water', '一些水'),
      ('a pen', '一支笔'),
      ('please', '请（礼貌请求）'),
      ('Here you are.', '给你。'),
    ],
  ),
];

// Word glosses fill gaps around the taught chunks, so even introductory
// dialogue language is available inside each lesson without older courses.
const _wordMeanings = <String, String>{
  'i': '我（主语）',
  'am': '是／处于某种状态（与 I 搭配）',
  "i'm": 'I am 的缩写',
  'a': '一个／一件（用于单数可数名词前）',
  'an': '一个（用于元音音素开头的词前）',
  'tom': '汤姆（姓名）',
  'amy': '艾米（姓名）',
  'lucy': '露西（姓名）',
  'li': '李（Li Ming 姓名的一部分）',
  'ming': '明（Li Ming 姓名的一部分）',
  'student': '学生',
  'happy': '开心的',
  'ready': '准备好的',
  'hello': '你好',
  'my': '我的',
  'name': '名字',
  "name's": 'name is 的缩写',
  'is': '是（与单数主语搭配）',
  'what': '什么',
  "what's": 'what is 的缩写',
  'your': '你的',
  'nice': '令人愉快的',
  'to': '用于 Nice to meet you 等固定表达',
  'meet': '认识／见到',
  'you': '你',
  'too': '也／还',
  'this': '这个／这位（近处，单数）',
  'friend': '朋友',
  'teacher': '老师',
  'book': '书',
  'bag': '包',
  'bags': '包（复数）',
  'pen': '笔',
  'thank': '感谢（Thank you 表示谢谢你）',
  'like': '喜欢',
  'do': '助动词（用于提问或否定）',
  "don't": 'do not 的缩写，表示否定',
  'not': '不',
  'yes': '是的',
  'no': '不／不是',
  'apples': '苹果（复数）',
  'apple': '苹果（单数）',
  'bananas': '香蕉（复数）',
  'tea': '茶（不可数）',
  'milk': '牛奶（不可数）',
  'water': '水（不可数）',
  'need': '需要',
  'want': '想要',
  'some': '一些（本课搭配不可数名词）',
  'two': '二／两个',
  'would': '与 like 搭配构成礼貌表达',
  "i'd": 'I would 的缩写（本课）',
  'sandwich': '三明治',
  'please': '请（礼貌请求）',
  'here': '这里（Here you are 表示给你）',
  'are': '与 you 搭配（Here you are 是固定表达）',
  'how': '怎样（How much 询问价格）',
  'much': '多少（How much 询问价格）',
  'it': '它',
  'five': '五',
  'yuan': '元（人民币单位）',
  'can': '可以（请求）',
  'have': '得到／要（Can I have 中的用法）',
};

// Review uses the same taught targets in new social situations, with four
// stable IDs for deterministic two-item rotation by the account review store.
const _reviewScenes = <String, List<String>>{
  'am': [
    '你是汤姆，参加新社团时向活动负责人介绍自己是谁。',
    '你是一名学生，在图书馆办借书证时向工作人员说明自己的身份。',
    '你收到朋友的礼物，现在很开心，请向送礼物的朋友说明自己的状态。',
    '同伴准备开始游戏，你已准备好，请告诉同伴你的状态。',
  ],
  'name': [
    '你叫汤姆，第一次给老师打电话时，请介绍自己的姓名。',
    '你叫艾米，在图书馆登记时，请告诉工作人员自己的姓名。',
    '你叫李明，初次认识邻居时，请介绍自己的姓名。',
    '你叫露西，参加新社团时，请告诉负责人自己的姓名。',
  ],
  'this': [
    '朋友艾米站在你身边，请向新同学介绍她是你的朋友。',
    '老师汤姆站在你身边，请向家人介绍他是你的老师。',
    '你在家里拿起近处一本书，请向家人说明这一个物品是什么。',
    '你在教室拿起近处一个包，请向同学说明这一个物品是什么。',
  ],
  'like': [
    '新同学想了解你的水果喜好，请说你平常喜欢苹果。',
    '邻居问你的水果喜好，请说你平常喜欢香蕉。',
    '家人准备采购饮品，请说你平常喜欢茶。',
    '朋友为聚会选饮品，请说你平常喜欢牛奶。',
  ],
  'dont_like': [
    '邻居问你的水果喜好，请说你平常不喜欢苹果。',
    '同学准备野餐水果，请说你平常不喜欢香蕉。',
    '家人想了解你的饮品喜好，请说你平常不喜欢茶。',
    '新同学问你的饮品喜好，请说你平常不喜欢牛奶。',
  ],
  'do_you_like': [
    '在聚会上想了解新朋友的水果喜好，请问对方是否喜欢苹果。',
    '和家人商量购物清单，请问家人平常是否喜欢香蕉。',
    '准备聚会饮品时，请问邻居平常是否喜欢茶。',
    '讨论早餐喜好时，请问朋友平常是否喜欢牛奶。',
  ],
  'need': [
    '你在图书馆做笔记却没有笔，请向工作人员说明你需要一支笔。',
    '你在家准备阅读，请向家人说明你需要一本书。',
    '你走路后口渴，请向同伴说明你需要一些水。',
    '你收拾两组野餐用品，请向同伴说明你需要两个包。',
  ],
  'want': [
    '朋友请你选择水果，请直接告诉朋友你想要一个苹果。',
    '在家准备晚餐时，请直接告诉家人你想要一些牛奶。',
    '家人给你选择水果，请直接说你想要两个香蕉。',
    '朋友让你选择礼物，请直接说你想要一个包。',
  ],
  'would_like': [
    '在餐厅点早餐，请向服务员礼貌地要一个三明治。',
    '在咖啡店点饮品，请向店员礼貌地要一些茶。',
    '在餐厅点餐后选水果，请向服务员礼貌地要两个苹果。',
    '在咖啡店用餐口渴，请向店员礼貌地要一些水。',
  ],
  'what_this': [
    '你在图书馆看到近处一个不知道名称的物品（一本书），请向工作人员问它是什么，不说出名称。',
    '你在朋友家看到近处一个不知道名称的物品（一个包），请向朋友问它是什么，不说出名称。',
    '你在文具店看到近处一个不知道名称的物品（一支笔），请向店员问它是什么，不说出名称。',
    '你在家里看到近处一个不知道名称的物品（一个苹果），请向家人问它是什么，不说出名称。',
  ],
  'price': [
    '你在书摊指着近处这一本书，请向摊主问这本书多少钱。',
    '你在礼品店指着近处这一个包，请向店员问这个包多少钱。',
    '你在商店结账前指着近处这一支笔，请向收银员问这支笔多少钱。',
    '你在超市指着近处这一个苹果，请向工作人员问这个苹果多少钱。',
  ],
  'can_have': [
    '你在图书馆领取用品，请向工作人员请求一个包。',
    '你在超市买水果，请向工作人员请求两个苹果。',
    '你在咖啡店用餐，请向店员请求一些水。',
    '你在图书馆填表，请向工作人员请求一支笔。',
  ],
};

String _sentence(_Frame frame, _Slot slot) =>
    '${frame.prefix}${slot.text}${frame.suffix}';

List<String> _alternatives(_Frame frame, _Slot slot) => switch (frame.id) {
  'am' => ["I'm ${slot.text}."],
  'name' => ["My name's ${slot.text}."],
  'dont_like' => ['I do not like ${slot.text}.'],
  'would_like' => [
    "I'd like ${slot.text}.",
    'I would like ${slot.text}, please.',
    "I'd like ${slot.text}, please.",
  ],
  'what_this' => ["What's this?"],
  'can_have' => ['Can I have ${slot.text}, please?'],
  _ => [],
};

Map<String, dynamic> _exercise(
  String id,
  String type,
  String prompt,
  String answer, {
  List<String> alternatives = const [],
  List<String> tokens = const [],
  List<String> options = const [],
  bool scenario = false,
  String? support,
}) => {
  'id': id,
  'type': type,
  'prompt': prompt,
  'sentence': answer,
  'options': options,
  'answer': answer,
  'audioId': id,
  if (alternatives.isNotEmpty) 'acceptedAnswers': alternatives,
  if (tokens.isNotEmpty) 'tokens': tokens,
  if (scenario) 'speakingMode': 'scenario',
  if (support != null) 'support': support,
};

List<String> _tokens(_Frame frame, _Slot slot) => frame.id == 'what_this'
    ? ['What', 'is', 'this?']
    : [frame.prefix.trim(), '${slot.text}${frame.suffix}'];

List<String> _options(_Frame frame, int correct) {
  final choices = frame.id == 'what_this'
      ? ['What is this?', 'This is a book.', 'This is a bag.', 'This is a pen.']
      : frame.slots.map((slot) => _sentence(frame, slot)).toList();
  // Rotate the options while retaining exactly four taught, distinct sentences.
  return [...choices.skip(correct), ...choices.take(correct)];
}

List<Map<String, dynamic>> _dialogue(
  String lessonId,
  List<(String, String, String)> turns,
) => [
  for (var i = 0; i < turns.length; i++)
    {
      'speaker': turns[i].$1,
      'text': turns[i].$2,
      'translation': turns[i].$3,
      'audioId': '${lessonId}_dialogue_${i + 1}',
    },
];

List<Map<String, dynamic>> _vocabulary(
  String lessonId,
  List<(String, String)> chunks,
  Iterable<Map<String, dynamic>> exercises,
  List<Map<String, dynamic>> dialogue,
) {
  final allText = [
    for (final turn in dialogue) turn['text'] as String,
    for (final e in exercises) ...[
      e['sentence'] as String,
      ...((e['acceptedAnswers'] as List?)?.cast<String>() ?? []),
      ...((e['options'] as List?)?.cast<String>() ?? []),
    ],
  ].join(' ');
  Set<String> words(String text) => RegExp(
    r"[A-Za-z]+(?:'[A-Za-z]+)?",
  ).allMatches(text.toLowerCase()).map((m) => m[0]!).toSet();
  final taught = chunks
      .map((chunk) => words(chunk.$1))
      .expand((v) => v)
      .toSet();
  final missing = words(allText).difference(taught).toList()..sort();
  final entries = [...chunks];
  for (final word in missing) {
    final meaning = _wordMeanings[word];
    if (meaning == null) {
      throw StateError('Missing local vocabulary gloss: $lessonId $word');
    }
    entries.add((word == 'i' ? 'I' : word, meaning));
  }
  return [
    for (var i = 0; i < entries.length; i++)
      {
        'text': entries[i].$1,
        'meaning': entries[i].$2,
        'audioId': '${lessonId}_vocab_${i + 1}',
      },
  ];
}

Map<String, dynamic> _patternLesson(int unit, int number, _Frame frame) {
  final lessonId = 'mp_u${unit}l$number';
  const selections = [0, 1, 1, 2, 0, 2, 1, 3, 2, 3];
  final exercises = <Map<String, dynamic>>[];
  for (var i = 0; i < 10; i++) {
    final slot = frame.slots[selections[i]];
    final type = i < 2
        ? 'listeningChoice'
        : i < 4
        ? 'wordBank'
        : i < 6
        ? 'speaking'
        : i < 8
        ? 'translateInput'
        : 'speaking';
    exercises.add(
      _exercise(
        '${lessonId}_e${i + 1}',
        type,
        i < 2
            ? '听音，选择你听到的英文句子。'
            : i < 4
            ? '${slot.scene}用句块拼出本课句型。'
            : i < 6
            ? '跟读范句：${slot.meaning}。'
            : '${slot.scene}使用本课句型回答。',
        _sentence(frame, slot),
        alternatives: _alternatives(frame, slot),
        tokens: type == 'wordBank' ? _tokens(frame, slot) : [],
        options: i < 2 ? _options(frame, i + 1) : [],
        scenario: i >= 8,
      ),
    );
  }
  final examples = [
    for (var i = 0; i < 3; i++)
      _exercise(
        '${lessonId}_example_${i + 1}',
        'speaking',
        frame.slots[i].scene,
        _sentence(frame, frame.slots[i]),
      ),
  ];
  final review = [
    for (var i = 0; i < 4; i++)
      _exercise(
        '${lessonId}_review_${i + 1}',
        'speaking',
        '${_reviewScenes[frame.id]![i]}使用本课句型回答。',
        _sentence(frame, frame.slots[i]),
        alternatives: _alternatives(frame, frame.slots[i]),
        scenario: true,
      ),
  ];
  final dialogue = _dialogue(lessonId, frame.dialogue);
  return {
    'id': lessonId,
    'title': '${frame.frame}｜${frame.title}',
    'exercises': exercises,
    'patternLesson': {
      'id': 'mp_${frame.id}',
      'version': 1,
      'kind': 'pattern',
      'frame': frame.frame.replaceAll('’', "'"),
      'meaning': frame.meaning,
      'slotRule': frame.rule,
      'limitations': frame.limitations,
      'dialogue': dialogue,
      'vocabulary': _vocabulary(lessonId, frame.chunks, [
        ...exercises,
        ...examples,
        ...review,
      ], dialogue),
      'examples': examples,
      'review': review,
      'patternIds': ['mp_${frame.id}'],
      'phases': [
        for (var i = 0; i < 5; i++)
          {
            'type': ['listening', 'chunks', 'repeat', 'recall', 'scenario'][i],
            'exerciseIds': [
              '${lessonId}_e${2 * i + 1}',
              '${lessonId}_e${2 * i + 2}',
            ],
          },
      ],
    },
  };
}

const _unitTitles = ['认识自己和身边的人物', '交流日常喜好', '表达需要与礼貌点餐', '询问商品与购买'];
const _dialogueTitles = ['新同学见面', '一起准备野餐', '准备午餐', '在商店购物'];
const _unitDialogues = <List<(String, String, String)>>[
  [
    ('Tom', 'Hello. My name is Tom.', '你好。我叫汤姆。'),
    ('Amy', 'My name is Amy.', '我叫艾米。'),
    ('Tom', 'I am a student.', '我是一名学生。'),
    ('Tom', 'This is my friend Lucy.', '这是我的朋友露西。'),
    ('Lucy', 'Nice to meet you.', '很高兴认识你。'),
    ('Amy', 'This is a book.', '这是一本书。'),
    ('Tom', 'Thank you.', '谢谢你。'),
  ],
  [
    ('Amy', 'Do you like apples?', '你喜欢苹果吗？'),
    ('Tom', 'I like apples.', '我喜欢苹果。'),
    ('Amy', 'Do you like milk?', '你喜欢牛奶吗？'),
    ('Tom', "I don't like milk.", '我不喜欢牛奶。'),
    ('Tom', 'Do you like tea?', '你喜欢茶吗？'),
    ('Amy', 'I like tea.', '我喜欢茶。'),
  ],
  [
    ('Tom', 'I need some water.', '我需要一些水。'),
    ('Amy', 'I want an apple.', '我想要一个苹果。'),
    ('Tom', 'I would like a sandwich, please.', '我想要一个三明治，谢谢。'),
    ('Amy', 'I would like some tea, please.', '我想要一些茶，谢谢。'),
    ('Server', 'Here you are.', '给你。'),
    ('Tom', 'Thank you.', '谢谢你。'),
  ],
  [
    ('Tom', 'What is this?', '这是什么？'),
    ('Seller', 'This is a bag.', '这是一个包。'),
    ('Tom', 'How much is this bag?', '这个包多少钱？'),
    ('Seller', 'It is five yuan.', '它五元。'),
    ('Tom', 'Can I have a bag, please?', '我可以要一个包吗？'),
    ('Seller', 'Here you are.', '给你。'),
  ],
];

// Four role responses in each integration lesson: the setting identifies the
// speaker, object/count and communicative intention, and shows no English answer.
const _dialogueTargets = <List<(int, int, String)>>[
  [
    (0, 1, '你扮演新同学汤姆。老师问你的身份，你是一名学生，请介绍自己的身份。'),
    (1, 0, '你扮演汤姆。新同学问你的名字，请告诉同学你叫汤姆。'),
    (2, 0, '你扮演汤姆。身边站着你的朋友艾米，请向老师介绍这位朋友。'),
    (2, 2, '你扮演汤姆。你手里拿着一本书，请向新同学介绍这一个物品。'),
  ],
  [
    (3, 0, '你扮演汤姆。朋友正在准备野餐，问你的水果喜好，请说你平常喜欢苹果。'),
    (4, 3, '你扮演汤姆。朋友问你是否喜欢牛奶，你平常不喜欢，请表达完整的否定喜好。'),
    (5, 2, '你扮演汤姆。你想知道朋友平常是否喜欢茶，请向朋友提问。'),
    (5, 1, '你扮演汤姆。你想知道朋友平常是否喜欢香蕉，请向朋友提问。'),
  ],
  [
    (6, 2, '你扮演汤姆。准备午餐时你口渴，需要一些水，请向同伴说明实际需要。'),
    (7, 0, '你扮演汤姆。家人让你选水果，请直接说你想要一个苹果。'),
    (8, 0, '你扮演汤姆。到了咖啡店，请向服务员礼貌地要一个三明治。'),
    (8, 1, '你扮演汤姆。服务员询问饮品，请礼貌地要一些茶。'),
  ],
  [
    (9, 1, '你扮演顾客汤姆。指着店内近处一个你不认识的包，向店员询问这个物品是什么，不说出名称。'),
    (10, 1, '你扮演顾客汤姆。店员说近处这个物品是一个包，请询问这一个包的价格。'),
    (11, 0, '你扮演顾客汤姆。准备结账，请向店员请求一个包。'),
    (11, 1, '你扮演顾客汤姆。在水果摊选水果，请向店员请求两个苹果。'),
  ],
];

Map<String, dynamic> _integrationLesson(int unit) {
  final lessonId = 'mp_u${unit}l4';
  final targets = _dialogueTargets[unit - 1];
  final localFrames = _frames.sublist((unit - 1) * 3, unit * 3);
  final exercises = <Map<String, dynamic>>[];
  // Listening/chunks/repeat practice two roles before four independent replies.
  for (var i = 0; i < 10; i++) {
    final target = targets[i < 6 ? i % 2 : i - 6];
    final frame = _frames[target.$1];
    final slot = frame.slots[target.$2];
    final type = i < 2
        ? 'listeningChoice'
        : i < 4
        ? 'wordBank'
        : 'speaking';
    exercises.add(
      _exercise(
        '${lessonId}_e${i + 1}',
        type,
        i < 2
            ? '听音，选择对话中你听到的英文句子。'
            : i < 4
            ? '${target.$3}用句块练习这个回应。'
            : i < 6
            ? '跟读角色回应：${slot.meaning}。'
            : target.$3,
        _sentence(frame, slot),
        alternatives: _alternatives(frame, slot),
        tokens: type == 'wordBank' ? _tokens(frame, slot) : [],
        options: i < 2 ? _options(frame, i + 1) : [],
        scenario: i >= 6,
      ),
    );
  }
  final dialogue = _dialogue(lessonId, _unitDialogues[unit - 1]);
  final chunks = [for (final frame in localFrames) ...frame.chunks];
  return {
    'id': lessonId,
    'title': '综合对话｜${_dialogueTitles[unit - 1]}',
    'exercises': exercises,
    'patternLesson': {
      'id': 'mp_dialogue_u$unit',
      'version': 1,
      'kind': 'dialogue',
      'frame': localFrames.map((f) => f.frame.replaceAll('’', "'")).join(' / '),
      'meaning': '把本单元的三个句型用于“${_dialogueTitles[unit - 1]}”的真实交流。',
      'slotRule': '先听完整对话并认识词汇，再练习听音、句块和有提示跟读。最后四次回应按角色、物品、数量和表达目的选择已经学过的句型。',
      'limitations': [
        '只回答当前角色需要说的一句话，不把整段对话背下来。',
        '保持指定人名、物品、数量与意图；礼貌请求与直接表达不可任意互换。',
      ],
      'dialogue': dialogue,
      'vocabulary': _vocabulary(lessonId, chunks, exercises, dialogue),
      'examples': <Map<String, dynamic>>[],
      'review': <Map<String, dynamic>>[],
      'patternIds': localFrames.map((f) => 'mp_${f.id}').toList(),
      'phases': [
        {
          'type': 'listening',
          'exerciseIds': ['${lessonId}_e1', '${lessonId}_e2'],
        },
        {
          'type': 'chunks',
          'exerciseIds': ['${lessonId}_e3', '${lessonId}_e4'],
        },
        {
          'type': 'repeat',
          'exerciseIds': ['${lessonId}_e5', '${lessonId}_e6'],
        },
        {
          'type': 'scenario',
          'exerciseIds': [for (var i = 7; i <= 10; i++) '${lessonId}_e$i'],
        },
      ],
    },
  };
}

/// Pure authored pack builder. It never loads or modifies ordinary courses.
Map<String, dynamic> buildMotherPatternCourse() => {
  'id': 'motherPattern',
  'title': '母句型听说',
  'language': 'english',
  'explanationLanguage': 'chinese',
  'units': [
    for (var unit = 1; unit <= 4; unit++)
      {
        'id': 'mp_u$unit',
        'title': '单元 $unit｜${_unitTitles[unit - 1]}',
        'description': '三个母句型与一节综合对话，听说为主，句块与输入辅助。',
        'lessons': [
          for (var lesson = 1; lesson <= 3; lesson++)
            _patternLesson(unit, lesson, _frames[(unit - 1) * 3 + lesson - 1]),
          _integrationLesson(unit),
        ],
      },
  ],
};

/// Existing editorial changes survive ordinary reruns. Only explicit refresh
/// replaces this new pack; no path to an older course is accepted.
String generateMotherPatternCourse({bool write = false, bool refresh = false}) {
  final file = File(motherPatternAssetPath);
  if (!refresh && file.existsSync()) return file.readAsStringSync();
  final text = '${_encoder.convert(buildMotherPatternCourse())}\n';
  if (write) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(text);
  }
  return text;
}

/// Exact audio ID -> English text, including every instructional and task item.
Map<String, dynamic> exportMotherPatternAudio(Map<String, dynamic> course) {
  if (course['id'] != 'motherPattern') {
    throw ArgumentError('Expected motherPattern');
  }
  final audio = <String, String>{};
  void add(String id, String text) {
    if (!id.startsWith('mp_') || text.trim().isEmpty || audio.containsKey(id)) {
      throw StateError('Invalid or duplicate mother pattern audio ID: $id');
    }
    audio[id] = text;
  }

  for (final unit in course['units'] as List) {
    for (final lesson in unit['lessons'] as List) {
      final metadata = lesson['patternLesson'] as Map;
      for (final item in metadata['dialogue'] as List) {
        add(item['audioId'] as String, item['text'] as String);
      }
      for (final item in metadata['vocabulary'] as List) {
        add(item['audioId'] as String, item['text'] as String);
      }
      for (final exercise in [
        ...lesson['exercises'],
        ...metadata['examples'],
        ...metadata['review'],
      ]) {
        add(exercise['audioId'] as String, exercise['sentence'] as String);
      }
    }
  }
  return {'courseId': 'motherPattern', 'version': 1, 'audio': audio};
}

void main(List<String> args) {
  if (args.any(
    (arg) => !['--refresh', '--check', '--audio-manifest'].contains(arg),
  )) {
    throw ArgumentError('Use --refresh, --check or --audio-manifest');
  }
  if (args.contains('--audio-manifest')) {
    final course =
        jsonDecode(generateMotherPatternCourse()) as Map<String, dynamic>;
    stdout.write('${_encoder.convert(exportMotherPatternAudio(course))}\n');
    return;
  }
  if (args.contains('--check')) {
    final file = File(motherPatternAssetPath);
    if (!file.existsSync() ||
        jsonEncode(jsonDecode(file.readAsStringSync())) !=
            jsonEncode(buildMotherPatternCourse())) {
      stderr.writeln(
        'The new pack differs from the authored builder. Review edits before --refresh.',
      );
      exitCode = 1;
    } else {
      stdout.writeln(
        'motherPattern authored pack matches; ordinary courses untouched.',
      );
    }
    return;
  }
  generateMotherPatternCourse(write: true, refresh: args.contains('--refresh'));
  stdout.writeln(motherPatternAssetPath);
}
