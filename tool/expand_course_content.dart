import 'dart:convert';
import 'dart:io';

import 'package:english_village/data/models/course.dart';
import 'improve_learning_content.dart' as improvement;

// Unit title (on the first lesson), lesson title, then four English/Chinese pairs.
const zeroMaterial = '''
农场一天|认识农场|This is a farm.|这是一个农场。|The farmer grows corn.|农民种玉米。|There are sheep here.|这里有绵羊。|The cow eats grass.|奶牛吃草。
|照顾动物|Please feed the hens.|请喂母鸡。|Give the horse water.|给马喝水。|The duck is hungry.|鸭子饿了。|Keep the gate closed.|让大门保持关闭。
|收获食物|We pick ripe tomatoes.|我们摘成熟的番茄。|These eggs are fresh.|这些鸡蛋很新鲜。|Put the carrots here.|把胡萝卜放这里。|I carry a basket.|我提着一个篮子。
|参观农场|We visit the farm today.|我们今天参观农场。|The tractor is big.|拖拉机很大。|Please stay with me.|请跟着我。|We wash our boots.|我们洗靴子。
花园植物|认识植物|This flower is pink.|这朵花是粉色的。|The tree has roots.|树有根。|These leaves are green.|这些叶子是绿色的。|The stem is strong.|茎很结实。
|种下种子|Put seeds in the soil.|把种子放进土里。|Cover them with soil.|用土盖住它们。|Water the seeds gently.|轻轻给种子浇水。|The pot is small.|花盆很小。
|照顾花园|Plants need sunlight.|植物需要阳光。|The soil feels dry.|土摸起来很干。|Please water this plant.|请给这株植物浇水。|Do not pick the flowers.|不要摘花。
|观察生长|A new leaf appears.|一片新叶出现了。|The plant grows taller.|植物长高了。|I see a small bud.|我看到一个小花蕾。|Our garden looks beautiful.|我们的花园看起来很美。
野餐准备|打包食物|We need some sandwiches.|我们需要一些三明治。|Put apples in the bag.|把苹果放进包里。|Bring a bottle of water.|带一瓶水。|I pack four cups.|我装了四个杯子。
|找到地点|This spot is shady.|这个地方有树荫。|Let us sit here.|我们坐这里吧。|The grass is soft.|草很柔软。|Spread the blanket out.|把毯子铺开。
|分享午餐|Would you like a sandwich?|你想要一个三明治吗？|Please pass the apples.|请把苹果递过来。|This juice tastes sweet.|这果汁喝起来很甜。|We eat lunch outside.|我们在户外吃午饭。
|收拾离开|Pick up the empty cups.|把空杯子捡起来。|Put rubbish in the bin.|把垃圾放进垃圾桶。|Fold the blanket carefully.|仔细叠好毯子。|Leave the park clean.|离开时保持公园干净。
邮局寄信|信和信封|I write a short letter.|我写一封短信。|This envelope is white.|这个信封是白色的。|Put the letter inside.|把信放进去。|Write your name here.|在这里写你的名字。
|写好地址|What is your address?|你的地址是什么？|My street is Green Road.|我住的街道是绿路。|Our house number is six.|我们的门牌号是六号。|Please check the address.|请检查地址。
|购买邮票|I need a stamp.|我需要一张邮票。|How much is this stamp?|这张邮票多少钱？|Stick it on the envelope.|把它贴在信封上。|The post office is open.|邮局开门了。
|等待回信|The letter is for Grandma.|这封信是给奶奶的。|The postman brings letters.|邮递员送信。|I check our mailbox.|我查看我们的信箱。|Grandma sends a reply.|奶奶寄来了回信。
博物馆参观|买票入场|Two tickets, please.|请给我两张票。|The museum opens today.|博物馆今天开放。|Show your ticket here.|在这里出示你的票。|We enter the museum.|我们进入博物馆。
|观察展品|This bowl is old.|这个碗很古老。|Look at that painting.|看那幅画。|The model is small.|这个模型很小。|Read the label first.|先读标签。
|参观规则|Please do not touch.|请不要触摸。|Walk slowly in here.|在这里慢慢走。|No food is allowed.|这里不允许吃东西。|Keep your voice low.|小声说话。
|分享发现|I like this painting.|我喜欢这幅画。|The colors are bright.|颜色很鲜艳。|What did you see?|你看到了什么？|I saw an old clock.|我看到了一个古老的钟。
游泳池|准备游泳|Bring your swimming cap.|带上你的泳帽。|My towel is blue.|我的毛巾是蓝色的。|Change your clothes here.|在这里换衣服。|Take a shower first.|先淋浴。
|水中动作|I can float now.|我现在会漂浮了。|Kick your legs gently.|轻轻踢腿。|Move your arms slowly.|慢慢移动手臂。|Hold the edge here.|抓住这里的池边。
|泳池安全|Do not run here.|不要在这里跑。|Stay near the shallow end.|待在浅水区附近。|Listen to the swimming teacher.|听游泳老师的话。|Ask an adult for help.|向大人求助。
|游泳之后|I feel tired now.|我现在觉得累。|Dry your hair well.|把头发擦干。|Drink some clean water.|喝些干净的水。|Put your towel away.|把毛巾收好。
火车旅行|准备车票|We take a train today.|我们今天乘火车。|Keep your ticket safe.|保管好你的票。|The station is busy.|车站很忙碌。|Our train leaves soon.|我们的火车快出发了。
|找到座位|This is our carriage.|这是我们的车厢。|My seat is number five.|我的座位是五号。|Put your bag above.|把包放到上面。|Please sit by the window.|请坐在窗边。
|旅途见闻|I see fields outside.|我看到外面的田野。|The train moves fast.|火车开得很快。|We pass a small town.|我们经过一个小镇。|The sky looks clear.|天空看起来很晴朗。
|到站下车|Our stop is next.|下一站就是我们要下的站。|Take your bag with you.|带上你的包。|Wait until the train stops.|等火车停下来。|Grandpa meets us here.|爷爷在这里接我们。
短篇故事|一个雨天|It rains this morning.|今天早上下雨。|Mia takes an umbrella.|米娅带了一把伞。|Her friend has no umbrella.|她的朋友没有伞。|They walk together.|他们一起走。
|丢失的帽子|Ben cannot find his hat.|本找不到他的帽子。|He looks under the chair.|他看椅子下面。|The hat is on the shelf.|帽子在架子上。|He puts it on.|他把它戴上了。
|帮助朋友|Lucy carries a heavy bag.|露西提着一个重包。|Tom offers to help.|汤姆主动帮忙。|They carry it together.|他们一起提它。|Lucy thanks her friend.|露西感谢她的朋友。
|快乐的一天|We visit Grandma today.|我们今天去看奶奶。|She makes warm soup.|她做了热汤。|We tell her a story.|我们给她讲一个故事。|Everyone smiles at dinner.|晚饭时大家都笑了。
''';

const beginnerMaterial = '''
机场手续|办理登机|I would like to check in for my flight.|我想办理航班登机手续。|May I see your passport, please?|请出示您的护照好吗？|I have one bag to check.|我有一个包要托运。|Could I have a window seat?|能给我一个靠窗座位吗？
|通过安检|Please place your bag on the belt.|请把包放在传送带上。|Do I need to remove my jacket?|我需要脱掉外套吗？|Put your laptop in a separate tray.|把笔记本电脑放在单独的托盘里。|Please walk through the scanner.|请走过扫描设备。
|登机口变化|Our flight has been delayed.|我们的航班延误了。|The new gate is number twelve.|新的登机口是十二号。|When will boarding begin?|什么时候开始登机？|Please listen for the announcement.|请留意广播通知。
|领取行李|Where can I collect my luggage?|我在哪里领取行李？|Your bags are on belt three.|您的行李在三号传送带上。|My suitcase has not arrived yet.|我的行李箱还没有到。|Please describe your missing bag.|请描述您丢失的包。
银行办事|开户咨询|I would like to open an account.|我想开一个账户。|What documents do I need?|我需要哪些文件？|Please bring proof of your address.|请带上您的地址证明。|There is no monthly account fee.|这个账户没有月费。
|存款取款|I need to withdraw some cash.|我需要取一些现金。|Please enter your PIN privately.|请私下输入您的密码。|I want to deposit fifty pounds.|我想存五十英镑。|Would you like a receipt?|您需要收据吗？
|转账确认|I would like to transfer money.|我想转账。|Please check the account number.|请检查账号。|How long will the transfer take?|转账需要多长时间？|The payment should arrive tomorrow.|款项应该明天到账。
|银行卡问题|My bank card is missing.|我的银行卡不见了。|Please block the card immediately.|请立即冻结这张卡。|I do not recognize this payment.|我不认识这笔付款。|How can I request a replacement?|我如何申请补卡？
维修与服务|描述故障|The washing machine will not start.|洗衣机无法启动。|It makes a strange noise.|它发出奇怪的噪声。|The problem started yesterday.|这个问题昨天开始出现。|Could you send someone to inspect it?|您能派人来检查吗？
|预约上门|When is the technician available?|维修人员什么时候有空？|I will be home after two.|我两点以后会在家。|Please call before you arrive.|请在到达前打电话。|Friday afternoon works for me.|星期五下午我方便。
|报价沟通|How much will the repair cost?|维修要花多少钱？|Does the price include the parts?|价格包括零件吗？|Please send me a written estimate.|请发给我一份书面报价。|I need time to consider the price.|我需要时间考虑这个价格。
|检查结果|The machine is working again.|机器又正常工作了。|Could you explain what was wrong?|您能解释一下哪里出了问题吗？|This part needs to be replaced.|这个零件需要更换。|How long is the repair guaranteed?|这次维修保修多久？
志愿服务|报名参与|I would like to volunteer here.|我想在这里做志愿者。|What kind of help do you need?|你们需要哪种帮助？|I am available on Saturday mornings.|我星期六上午有空。|Please complete this application form.|请填写这份申请表。
|分配任务|We need to sort these donations.|我们需要整理这些捐赠物。|Could you welcome the visitors?|你能接待来访者吗？|I will help prepare the tables.|我会帮忙准备桌子。|Let us divide the work fairly.|我们公平分配工作吧。
|团队协作|Please let me know if you need help.|如果你需要帮助请告诉我。|We have finished the first task.|我们完成了第一个任务。|Who is responsible for the supplies?|谁负责物资？|We should check everything together.|我们应该一起检查所有东西。
|活动总结|Thank you for giving your time.|谢谢你奉献自己的时间。|We helped thirty families today.|我们今天帮助了三十个家庭。|What could we improve next time?|我们下次可以改进什么？|I would be happy to join again.|我很乐意再次参加。
信息核实|询问信息|Where did you find this information?|你在哪里找到这个信息的？|Is this the official website?|这是官方网站吗？|Who wrote this article?|谁写了这篇文章？|Let us check the publication date.|我们检查一下发布日期吧。
|比较来源|These two reports give different numbers.|这两篇报道给出了不同的数字。|We need another reliable source.|我们需要另一个可靠来源。|This page explains the details clearly.|这个页面清楚解释了细节。|Do not rely on the headline alone.|不要只依赖标题。
|确认理解|Do you mean the event is free?|你的意思是活动免费吗？|Could you confirm the starting time?|你能确认开始时间吗？|I may have misunderstood the message.|我可能误解了这条消息。|Let me repeat the main points.|让我重复一下要点。
|更正错误|I gave you the wrong date earlier.|我之前给了你错误的日期。|The correct date is next Tuesday.|正确日期是下星期二。|Please update the shared document.|请更新共享文档。|Thank you for pointing that out.|谢谢你指出这一点。
个人预算|记录支出|I keep a record of my spending.|我记录自己的支出。|How much did we spend on food?|我们在食物上花了多少钱？|This bill includes a service charge.|这张账单包含服务费。|Let us add up the total.|我们把总额加起来吧。
|计划预算|We need to set a weekly budget.|我们需要制定每周预算。|I plan to save a little each month.|我计划每月存一点钱。|Rent is our biggest expense.|房租是我们最大的支出。|We should leave money for emergencies.|我们应该留钱应付紧急情况。
|比较价格|This option costs less overall.|这个选项总体花费更低。|The cheaper plan has fewer features.|更便宜的方案功能更少。|Is delivery included in the price?|价格包括配送吗？|Let us compare the final costs.|我们比较一下最终费用吧。
|调整计划|We spent more than we expected.|我们花得比预期多。|I can cut back on snacks.|我可以减少买零食。|We do not need to buy it today.|我们不需要今天买它。|Our budget is easier to manage now.|我们的预算现在更容易管理了。
学习交流|加入课程|I would like to join the evening class.|我想参加晚间课程。|What level is this course for?|这门课程适合什么水平？|Can I attend a trial lesson?|我可以试听一节课吗？|Classes meet twice a week.|课程每周上两次。
|讨论作业|Could you explain the assignment?|你能解释一下作业吗？|When do we need to submit it?|我们什么时候需要提交？|I have a question about the examples.|我对例子有一个问题。|Please show how you reached the answer.|请展示你如何得出答案。
|给予反馈|Your explanation was very clear.|你的解释很清楚。|This paragraph needs another example.|这一段需要另一个例子。|Could you speak a little more slowly?|你能说得再慢一点吗？|I appreciate your useful suggestions.|我感谢你有用的建议。
|制定目标|I want to improve my listening skills.|我想提高听力能力。|I will practice for fifteen minutes daily.|我会每天练习十五分钟。|Let us review our progress next month.|我们下个月回顾进展吧。|Small steps can make a big difference.|小步骤能带来很大改变。
旅行经历|讲述出发|We left home early in the morning.|我们一大早就离开了家。|The journey took about three hours.|旅程大约用了三个小时。|We arrived before the hotel opened.|我们在酒店开门前就到了。|I was excited to explore the city.|我很兴奋能探索这座城市。
|遇到变化|It started raining during our walk.|我们散步时开始下雨了。|We decided to visit a museum instead.|我们决定改去博物馆。|Luckily, we had booked tickets online.|幸运的是我们已经在网上订票了。|The change made our day more interesting.|这个变化让我们的一天更有趣。
|推荐地点|I recommend the small cafe by the river.|我推荐河边的小咖啡馆。|The staff were friendly and helpful.|工作人员友善又乐于助人。|You should try the local soup.|你应该尝尝当地的汤。|It is worth visiting early in the day.|值得在一天较早的时候去参观。
|总结旅程|The best part was meeting new people.|最棒的部分是认识新朋友。|I learned a lot about local life.|我学到了很多关于当地生活的知识。|Next time I would stay longer.|下次我会待得更久。|I hope we can travel together again.|我希望我们能再一起旅行。
''';

const dialogueMaterial = '''
z_u35|Is this your farm?|这是你的农场吗？|Yes, we grow corn here.|是的，我们在这里种玉米。|Can I help feed the hens?|我可以帮忙喂母鸡吗？
z_u36|Why is this plant dry?|这株植物为什么干了？|It needs some water.|它需要一些水。|I will water it gently.|我会轻轻给它浇水。
z_u37|Where shall we have our picnic?|我们在哪里野餐呢？|Let us sit under that tree.|我们坐在那棵树下吧。|Great, I will spread the blanket.|太好了，我来铺毯子。
z_u38|Who is this letter for?|这封信是给谁的？|It is for my grandma.|它是给我奶奶的。|Let us buy a stamp.|我们去买一张邮票吧。
z_u39|Which painting do you like?|你喜欢哪幅画？|I like the one with flowers.|我喜欢有花的那幅。|The colors are very bright.|颜色很鲜艳。
z_u40|Are you ready to swim?|你准备好游泳了吗？|Yes, I have my swimming cap.|是的，我带了泳帽。|Good, take a shower first.|好，先淋浴。
z_u41|Is this our train?|这是我们的火车吗？|Yes, our seats are by the window.|是的，我们的座位在窗边。|Let us find our carriage.|我们找我们的车厢吧。
z_u42|Why are you smiling?|你为什么笑？|My friend helped me find my hat.|我的朋友帮我找到了帽子。|That was kind of your friend.|你的朋友真友善。
u45|Could I check in for my flight?|我可以办理航班登机手续吗？|Certainly. May I see your passport?|当然，请出示您的护照好吗？|Here it is. I have one bag to check.|在这里，我有一个包要托运。
u46|I think I have lost my bank card.|我想我丢了银行卡。|We can block it and arrange a replacement.|我们可以冻结它并安排补卡。|Thank you. What information do you need?|谢谢，您需要什么信息？
u47|My washing machine will not start.|我的洗衣机无法启动。|I can send a technician on Friday afternoon.|我可以安排维修人员星期五下午上门。|That works for me. Please call before arriving.|我方便，请到达前打电话。
u48|Would you like to volunteer on Saturday?|你想星期六做志愿者吗？|Yes. What kind of help do you need?|想，你们需要哪种帮助？|We need someone to welcome the visitors.|我们需要人接待来访者。
u49|This message says the event starts at ten.|这条消息说活动十点开始。|The official website says eleven. Let us check.|官方网站说十一点，我们核实一下吧。|Good idea. I will contact the organizer.|好主意，我会联系组织者。
u50|We spent more than our budget this week.|我们这周花得超过预算了。|Let us check the bills and plan next week.|我们检查账单并计划下周吧。|I can cut back on snacks to save money.|我可以减少买零食来省钱。
u51|What skill would you like to improve?|你想提高哪项技能？|I want to understand spoken English better.|我想更好地理解英语口语。|Let us practice listening for fifteen minutes daily.|我们每天练十五分钟听力吧。
u52|What was the best part of your trip?|你旅行中最棒的部分是什么？|Meeting local people and trying their food.|认识当地人并品尝他们的食物。|That sounds wonderful. I hope to go there too.|听起来很棒，我也希望去那里。
''';

Map<String, dynamic> exercise(
  String id,
  int n,
  String type,
  String prompt,
  String sentence,
  String answer, {
  List<String> options = const [],
  String? blank,
  List<MatchPair> pairs = const [],
}) => {
  'id': '${id}e$n',
  'type': type,
  'prompt': prompt,
  'sentence': sentence,
  'answer': answer,
  'options': options,
  'sentenceWithBlank': blank,
  if (pairs.isNotEmpty)
    'pairs': [
      for (final p in pairs) {'left': p.left, 'right': p.right},
    ],
};

List<Map<String, dynamic>> buildExercises(
  String id,
  List<MatchPair> pairs,
  int index,
) {
  final en = [for (final p in pairs) p.right];
  final zh = [for (final p in pairs) p.left];
  final words = en[3].split(' ');
  final target = words.indexWhere((w) => RegExp(r'^[a-z]{3,10}$').hasMatch(w));
  if (target < 0) throw FormatException('No blank word for $id');
  final answer = words[target];
  words[target] = '____';
  List<String> rotated(List<String> values, int n) => [
    ...values.skip(n),
    ...values.take(n),
  ];
  return [
    exercise(
      id,
      1,
      'translateChoice',
      zh[0],
      en[0],
      en[0],
      options: rotated(en, index % 4),
    ),
    exercise(
      id,
      2,
      'translateChoice',
      en[1],
      en[1],
      zh[1],
      options: rotated(zh, (index + 1) % 4),
    ),
    exercise(
      id,
      3,
      'matchPairs',
      '配对中英文表达',
      '',
      MatchPair.encode(pairs),
      pairs: pairs,
    ),
    exercise(id, 4, 'wordBank', zh[3], en[3], en[3]),
    exercise(
      id,
      5,
      index.isEven ? 'wordBank' : 'translateInput',
      zh[0],
      en[0],
      en[0],
    ),
    exercise(
      id,
      6,
      'listeningChoice',
      '听一听，选出正确的意思',
      en[1],
      zh[1],
      options: rotated(zh, (index + 2) % 4),
    ),
    exercise(
      id,
      7,
      index.isEven ? 'listeningWordBank' : 'dictation',
      index.isEven ? '听音组句' : '听写句子',
      en[2],
      en[2],
    ),
    exercise(
      id,
      8,
      'fillBlank',
      '补全句子：${zh[3]}',
      en[3],
      answer,
      blank: words.join(' '),
    ),
    exercise(id, 9, 'speaking', zh[0], en[0], en[0]),
  ];
}

void main() {
  final dialogueFile = File('assets/dialogues/unit_dialogues.json');
  final dialogues =
      jsonDecode(dialogueFile.readAsStringSync()) as Map<String, dynamic>;
  for (final track in ['zero', 'beginner']) {
    final file = File('assets/courses/course_$track.json');
    final course = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final units = course['units'] as List;
    final base = track == 'zero' ? 34 : 44;
    final prefix = track == 'zero' ? 'z_u' : 'u';
    if (units.length != base && units.length < base + 8) {
      throw StateError('Unexpected $track unit count: ${units.length}');
    }
    final laterUnits = units.skip(base + 8).toList();
    // Only replace units owned by this extension, preserving all earlier data.
    units.removeRange(base, units.length);
    Map<String, dynamic>? unit;
    var lessonIndex = 0;
    for (final line
        in (track == 'zero' ? zeroMaterial : beginnerMaterial).trim().split(
          '\n',
        )) {
      final fields = line.split('|');
      if (fields.length != 10) {
        throw FormatException('Expected four pairs: $line');
      }
      if (fields[0].isNotEmpty) {
        if (unit != null && lessonIndex != 4) {
          throw StateError('Incomplete unit');
        }
        unit = {
          'id': '$prefix${units.length + 1}',
          'title': fields[0],
          'description': '练习${fields[0]}中的常用表达。',
          'lessons': <Map<String, dynamic>>[],
        };
        units.add(unit);
        lessonIndex = 0;
      }
      if (unit == null) throw StateError('Missing unit');
      final pairs = [
        for (var i = 2; i < 10; i += 2)
          MatchPair(left: fields[i + 1], right: fields[i]),
      ];
      if (pairs.map((p) => p.left).toSet().length != 4 ||
          pairs.map((p) => p.right).toSet().length != 4) {
        throw FormatException('Duplicate pair in $line');
      }
      final id = '${unit['id']}l${lessonIndex + 1}';
      (unit['lessons'] as List).add({
        'id': id,
        'title': fields[1],
        'exercises': buildExercises(id, pairs, lessonIndex),
      });
      if (lessonIndex == 0) {
        dialogues[unit['id'] as String] = [
          for (var i = 0; i < 3; i++)
            {
              'speaker': i % 2,
              'english': pairs[i].right,
              'chinese': pairs[i].left,
            },
        ];
      }
      lessonIndex++;
    }
    if (units.length != base + 8 || lessonIndex != 4) {
      throw StateError('Incomplete expansion');
    }
    units.addAll(laterUnits);
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(course)}\n',
    );
  }
  for (final line in dialogueMaterial.trim().split('\n')) {
    final fields = line.split('|');
    if (fields.length != 7) throw FormatException('Invalid dialogue');
    dialogues[fields[0]] = [
      for (var i = 0; i < 3; i++)
        {
          'speaker': i % 2,
          'english': fields[1 + i * 2],
          'chinese': fields[2 + i * 2],
        },
    ];
  }
  dialogueFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(dialogues)}\n',
  );
  improvement.main();
}
