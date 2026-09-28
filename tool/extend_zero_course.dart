import 'dart:convert';
import 'dart:io';

// Each lesson has four distinct sentence/translation pairs. Keep this source
// alongside the generated JSON so new course material remains reviewable.
const _material = '''
日常问候|早上见面|Good morning, Amy.|早上好，艾米。|How are you today?|你今天好吗？|I am fine, thanks.|我很好，谢谢。|See you this afternoon.|下午见。
|晚上道别|Good evening, Dad.|晚上好，爸爸。|How was your day?|你今天过得怎样？|It was a good day.|今天过得很好。|Good night, everyone.|大家晚安。
|介绍朋友|This is my friend Ben.|这是我的朋友本。|He is in my class.|他在我班上。|We study English together.|我们一起学英语。|Please say hello to Ben.|请和本打招呼。
|礼貌回应|Thank you for your help.|谢谢你的帮助。|You are welcome here.|欢迎你来这里。|Please come in now.|请现在进来。|I am sorry about that.|对此我很抱歉。
认识自己|姓名和年龄|My name is Lucy.|我叫露西。|I am ten years old.|我十岁了。|What is your name?|你叫什么名字？|How old are you?|你几岁了？
|来自哪里|I am from Beijing.|我来自北京。|Where are you from?|你来自哪里？|My home is in China.|我的家在中国。|We live in the same city.|我们住在同一个城市。
|我的兴趣|I like drawing pictures.|我喜欢画画。|My friend likes singing.|我的朋友喜欢唱歌。|We play games after school.|放学后我们玩游戏。|What do you like doing?|你喜欢做什么？
|自我介绍|I am a new student.|我是一名新学生。|I have a little brother.|我有一个弟弟。|My favorite color is green.|我最喜欢绿色。|I want to learn English.|我想学习英语。
数量与物品|数到二十|I have eleven pencils.|我有十一支铅笔。|There are twelve books.|有十二本书。|Count the thirteen stars.|数一数十三颗星星。|We need twenty chairs.|我们需要二十把椅子。
|单数和复数|This is one apple.|这是一个苹果。|These are two apples.|这些是两个苹果。|That is one box.|那是一个盒子。|Those are three boxes.|那些是三个盒子。
|教室里的数量|There are four desks here.|这里有四张桌子。|How many pens are there?|那里有多少支钢笔？|I can see six bags.|我能看到六个包。|We have eight notebooks.|我们有八本笔记本。
|比较多少|I have more cards.|我的卡片更多。|You have fewer stickers.|你的贴纸更少。|We have the same number.|我们的数量一样。|There are five cups in all.|总共有五个杯子。
形状与大小|常见形状|This is a round clock.|这是一个圆形的钟。|The window is square.|窗户是方形的。|Draw a small triangle.|画一个小三角形。|That table is a rectangle.|那张桌子是长方形的。
|大与小|This bag is big.|这个包很大。|That cup is small.|那个杯子很小。|My room is bigger.|我的房间更大。|Her pencil is shorter.|她的铅笔更短。
|长与短|The ruler is long.|这把尺子很长。|This road is short.|这条路很短。|The blue rope is longer.|蓝色绳子更长。|I need a shorter line.|我需要一条更短的线。
|描述物品|I have a small red ball.|我有一个红色的小球。|The big box is heavy.|这个大箱子很重。|This round plate is white.|这个圆盘是白色的。|That long pencil is yellow.|那支长铅笔是黄色的。
家中的房间|客厅|We sit in the living room.|我们坐在客厅里。|The sofa is near the door.|沙发在门附近。|I watch a film with Mom.|我和妈妈看电影。|Please turn off the light.|请关灯。
|卧室|My bed is by the window.|我的床在窗边。|The lamp is on the desk.|灯在书桌上。|I make my bed every day.|我每天整理床铺。|Where is my blue pillow?|我的蓝色枕头在哪里？
|厨房|Dad is in the kitchen.|爸爸在厨房里。|The cups are on the table.|杯子在桌上。|Please wash the vegetables.|请洗蔬菜。|We cook dinner together.|我们一起做晚饭。
|浴室|The bathroom is upstairs.|浴室在楼上。|Wash your hands with soap.|用肥皂洗手。|The towel is behind the door.|毛巾在门后。|I brush my teeth here.|我在这里刷牙。
整理房间|放在哪里|Put the book on the shelf.|把书放在架子上。|The toy is under the bed.|玩具在床下。|My shoes are by the door.|我的鞋子在门边。|Keep your bag in the closet.|把包放进衣柜。
|寻找物品|Where is my notebook?|我的笔记本在哪里？|It is inside your bag.|它在你的包里。|Look behind the chair.|看看椅子后面。|I found it near the window.|我在窗边找到了它。
|保持整洁|Please tidy your desk.|请整理你的书桌。|Put the toys away now.|现在把玩具收好。|The floor is clean today.|今天地板很干净。|We clean our room on Sunday.|我们星期天打扫房间。
|请求帮忙|Can you help me move this?|你能帮我搬这个吗？|Please hold the box for me.|请帮我拿着箱子。|Let us clean the table.|我们来擦桌子吧。|Thank you for cleaning up.|谢谢你帮忙收拾。
时间与日期|整点时间|It is seven o'clock.|现在七点整。|School starts at eight.|学校八点开始上课。|We eat lunch at twelve.|我们十二点吃午饭。|I go home at five.|我五点回家。
|上午和下午|I read in the morning.|我早上读书。|We play in the afternoon.|我们下午玩耍。|Dad cooks in the evening.|爸爸晚上做饭。|I sleep at night.|我夜里睡觉。
|星期安排|Today is Tuesday.|今天是星期二。|We swim on Wednesday.|我们星期三游泳。|Friday is my busy day.|星期五是我忙碌的一天。|I rest on Sunday.|我星期天休息。
|日期和生日|My birthday is in May.|我的生日在五月。|Today is the first of June.|今天是六月一日。|Her party is on Saturday.|她的聚会在星期六。|What is the date today?|今天是几号？
规律与习惯|每天早晨|I get up at seven.|我七点起床。|I wash my face first.|我先洗脸。|Then I eat my breakfast.|然后我吃早餐。|I walk to school with Ben.|我和本步行上学。
|放学以后|I go home after school.|我放学后回家。|I do my homework first.|我先做作业。|Then I play with my dog.|然后我和狗玩。|We eat dinner at six.|我们六点吃晚饭。
|经常和有时|I usually take the bus.|我通常坐公交车。|She sometimes rides a bike.|她有时骑自行车。|We often read together.|我们经常一起阅读。|He never forgets his bag.|他从不忘带包。
|我的周末|I visit Grandma on Saturday.|我星期六去看奶奶。|We make cakes together.|我们一起做蛋糕。|On Sunday I play outside.|星期天我在外面玩。|My weekend is always fun.|我的周末总是很有趣。
喜好与选择|喜欢的食物|I like bananas very much.|我很喜欢香蕉。|She loves warm soup.|她喜欢热汤。|Do you like noodles?|你喜欢面条吗？|We like different fruit.|我们喜欢不同的水果。
|不喜欢什么|I do not like onions.|我不喜欢洋葱。|He does not like milk.|他不喜欢牛奶。|This soup is too salty.|这汤太咸了。|I prefer water to juice.|比起果汁我更喜欢水。
|选择饮料|Would you like some water?|你想喝点水吗？|I would like a cup of tea.|我想要一杯茶。|She wants a glass of milk.|她想要一杯牛奶。|Please give me some juice.|请给我一些果汁。
|一起分享|We can share this cake.|我们可以分享这个蛋糕。|Would you like a piece?|你想要一块吗？|Please take the last apple.|请拿最后一个苹果。|Thank you for sharing with me.|谢谢你和我分享。
认识朋友|他和她|He is my classmate.|他是我的同学。|She is my best friend.|她是我最好的朋友。|His name is Jack.|他叫杰克。|Her name is Lily.|她叫莉莉。
|朋友的样子|Jack has short hair.|杰克留着短发。|Lily has big eyes.|莉莉有一双大眼睛。|My friend is very tall.|我的朋友很高。|She wears a red hat.|她戴着一顶红帽子。
|朋友的性格|He is kind to everyone.|他对每个人都很友善。|She is quiet in class.|她上课时很安静。|My friend is always helpful.|我的朋友总是乐于助人。|We are happy together.|我们在一起很开心。
|邀请朋友|Can you come to my home?|你能来我家吗？|Let us play after school.|我们放学后玩吧。|I can meet you at three.|我三点可以见你。|See you at the playground.|操场见。
运动与动作|我会做什么|I can run fast.|我能跑得很快。|She can jump high.|她能跳得很高。|We can dance together.|我们可以一起跳舞。|Can you throw the ball?|你会扔球吗？
|球类游戏|Let us play football.|我们踢足球吧。|Pass the ball to me.|把球传给我。|He can catch the ball.|他能接住球。|We play basketball on Friday.|我们星期五打篮球。
|公园活动|I walk in the park.|我在公园散步。|The children fly a kite.|孩子们放风筝。|We ride our bikes slowly.|我们慢慢骑自行车。|Please stay on the path.|请走在小路上。
|运动安全|Warm up before you run.|跑步前要热身。|Drink water after playing.|玩耍后喝水。|Please do not push others.|请不要推别人。|Take a rest when tired.|累了就休息一下。
天气和季节|春天|Spring is warm and green.|春天温暖又绿意盎然。|Flowers grow in the garden.|花儿在花园里生长。|I wear a light jacket.|我穿一件薄外套。|We go outside in spring.|春天我们去户外。
|夏天|Summer days are very hot.|夏天的日子很热。|I drink a lot of water.|我喝很多水。|We swim in the pool.|我们在游泳池里游泳。|Wear a hat in the sun.|在太阳下要戴帽子。
|秋天|The leaves turn yellow.|树叶变黄了。|Autumn is cool and windy.|秋天凉爽又多风。|We pick apples in autumn.|我们在秋天摘苹果。|I wear my warm sweater.|我穿上暖和的毛衣。
|冬天|Winter days are cold.|冬天的日子很冷。|Please put on your coat.|请穿上外套。|Snow falls on the ground.|雪落在地上。|We drink warm milk inside.|我们在屋里喝热牛奶。
社区生活|附近的地方|The library is near my home.|图书馆在我家附近。|The park is across the road.|公园在马路对面。|There is a shop on this street.|这条街上有一家商店。|Our school is next to the bank.|我们的学校在银行旁边。
|去图书馆|I want to borrow a book.|我想借一本书。|Please speak quietly here.|请在这里小声说话。|The books are on that shelf.|书在那个架子上。|I will return this book soon.|我会尽快还这本书。
|去商店|We need some bread today.|我们今天需要一些面包。|The shop opens at nine.|商店九点开门。|Please show me the milk.|请给我看看牛奶。|I will pay at the counter.|我会在收银台付款。
|问路|Excuse me, where is the park?|打扰一下，公园在哪里？|Go straight along this road.|沿着这条路直走。|Turn right at the corner.|在拐角处右转。|The park is on your left.|公园在你的左边。
简单购物|询问价格|How much is this notebook?|这本笔记本多少钱？|It costs five yuan.|它要五元。|That pen is cheaper.|那支笔更便宜。|The blue bag costs ten yuan.|蓝色包要十元。
|颜色和尺码|Do you have a red shirt?|你们有红色衬衫吗？|This shirt is too small.|这件衬衫太小了。|I need a larger size.|我需要大一点的尺码。|The blue one fits me well.|蓝色那件很合身。
|付款|I want to buy this book.|我想买这本书。|Can I pay with cash?|我可以用现金付款吗？|Here is your change.|这是找你的零钱。|Please keep the receipt.|请收好收据。
|购物对话|May I help you today?|今天需要帮忙吗？|I am looking for a hat.|我在找一顶帽子。|Please try this one on.|请试戴这一顶。|Thank you, I will take it.|谢谢，我买这个。
身体与健康|身体感觉|I feel tired today.|我今天觉得累。|My head hurts a little.|我的头有点疼。|She has a sore throat.|她嗓子疼。|He feels better now.|他现在感觉好些了。
|寻求帮助|I need to see a doctor.|我需要看医生。|Please call my mother.|请打电话给我妈妈。|Can you help me sit down?|你能扶我坐下吗？|The nurse is coming now.|护士现在过来了。
|健康习惯|Wash your hands before meals.|饭前洗手。|Eat fruit every day.|每天吃水果。|Go to bed early tonight.|今晚早点睡觉。|A short walk is good for you.|短暂散步对你有好处。
|照顾他人|Are you feeling better today?|你今天感觉好些了吗？|Please drink some warm water.|请喝点温水。|I can carry your bag.|我可以帮你拿包。|Get well soon, my friend.|朋友，祝你早日康复。
学习与目标|学习计划|I will read one page today.|我今天会读一页。|We can practice after lunch.|我们可以午饭后练习。|I want to learn new words.|我想学新单词。|Let us study for ten minutes.|我们学十分钟吧。
|课堂提问|What does this word mean?|这个词是什么意思？|Please say it again slowly.|请再慢慢说一遍。|How do you spell this word?|这个词怎么拼写？|I do not understand yet.|我还不明白。
|表达进步|I can read this sentence.|我能读这个句子。|You speak more clearly now.|你现在说得更清楚了。|We learn a little every day.|我们每天学一点。|I am proud of my progress.|我为自己的进步感到自豪。
|继续前进|I will practice again tomorrow.|我明天会再练习。|Mistakes help us learn.|错误帮助我们学习。|We can ask for help.|我们可以寻求帮助。|I am ready for the next lesson.|我准备好学下一节了。
''';

List<Map<String, dynamic>> _exercises(String id, List<(String, String)> pairs) {
  final english = [for (final pair in pairs) pair.$1];
  final chinese = [for (final pair in pairs) pair.$2];
  Map<String, dynamic> item(
    int number,
    String type,
    String prompt,
    String sentence,
    String answer, [
    List<String> options = const [],
    String? blank,
  ]) => {
    'id': '${id}e$number',
    'type': type,
    'prompt': prompt,
    'sentence': sentence,
    'options': options,
    'answer': answer,
    'sentenceWithBlank': blank,
  };

  // Use a short, non-repeated word for the typed answer.
  final words = english[3].split(' ');
  final blankIndex = words.indexWhere(
    (word) =>
        word.length >= 3 &&
        word.length <= 10 &&
        RegExp(r'^[A-Za-z]+$').hasMatch(word) &&
        words.where((w) => w == word).length == 1,
  );
  if (blankIndex < 0) throw FormatException('No usable blank: $id');
  final blankAnswer = words[blankIndex];
  words[blankIndex] = '____';

  return [
    item(
      1,
      'translateChoice',
      chinese[0],
      english[0],
      english[0].replaceFirst(RegExp(r'[.!?]$'), ''),
      [for (final value in english) value.replaceFirst(RegExp(r'[.!?]$'), '')],
    ),
    item(2, 'translateChoice', english[1], english[1], chinese[1], chinese),
    item(
      3,
      'translateChoice',
      chinese[2],
      english[2],
      english[2].replaceFirst(RegExp(r'[.!?]$'), ''),
      [for (final value in english) value.replaceFirst(RegExp(r'[.!?]$'), '')],
    ),
    item(4, 'wordBank', chinese[3], english[3], english[3]),
    item(5, 'wordBank', chinese[0], english[0], english[0]),
    item(6, 'listeningChoice', '听一听，选出正确的意思', english[1], chinese[1], chinese),
    item(7, 'listeningChoice', '听一听，选出正确的意思', english[2], chinese[2], chinese),
    item(
      8,
      'fillBlank',
      '补全句子：${chinese[3]}',
      english[3],
      blankAnswer,
      const [],
      words.join(' '),
    ),
    item(9, 'speaking', chinese[0], english[0], english[0]),
  ];
}

void main() {
  final file = File('assets/courses/course_zero.json');
  final course = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final units = course['units'] as List<dynamic>;
  // Regeneration replaces only the extension; the first 64 lessons stay intact.
  units.removeWhere(
    (unit) => int.parse((unit as Map)['id'].toString().substring(3)) > 16,
  );
  Map<String, dynamic>? unit;
  var lessonNumber = 0;
  for (final rawLine in _material.trim().split('\n')) {
    final fields = rawLine.trim().split('|');
    if (fields.length != 10) {
      throw FormatException('Expected title + 4 pairs: $rawLine');
    }
    if (fields[0].isNotEmpty) {
      if (unit != null && lessonNumber != 4) {
        throw FormatException('Incomplete unit');
      }
      unit = {
        'id': 'z_u${units.length + 1}',
        'title': fields[0],
        'description': '学习${fields[0]}的常用词句与日常表达。',
        'lessons': <Map<String, dynamic>>[],
      };
      units.add(unit);
      lessonNumber = 0;
    }
    if (unit == null) throw FormatException('Lesson without unit');
    lessonNumber++;
    final pairs = [for (var i = 2; i < 10; i += 2) (fields[i], fields[i + 1])];
    if (pairs.map((p) => p.$1).toSet().length != 4 ||
        pairs.map((p) => p.$2).toSet().length != 4) {
      throw FormatException('Duplicate answers: $rawLine');
    }
    final id = '${unit['id']}l$lessonNumber';
    (unit['lessons'] as List).add({
      'id': id,
      'title': fields[1],
      'exercises': _exercises(id, pairs),
    });
  }
  if (units.length != 32 || lessonNumber != 4) {
    throw FormatException('Expected 32 units');
  }
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(course)}\n',
  );
}
