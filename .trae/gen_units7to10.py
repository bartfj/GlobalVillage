# -*- coding: utf-8 -*-
"""生成 u7-u10 四个单元（16 课 × 8 题）追加到 course_beginner.json。"""
import json
import hashlib
import random
import re

SRC = r'd:\workspace\github_code\地球村\assets\courses\course_beginner.json'

# 每课 6 组句对 (中文, 英文)
UNITS = [
    {
        'id': 'u7', 'title': '天气与季节',
        'description': '学习谈论天气、四季与温度的基本表达。',
        'lessons': [
            ('询问天气', [
                ('今天天气怎么样？', 'How is the weather today?'),
                ('今天是晴天。', 'It is sunny today.'),
                ('现在正在下雨。', 'It is raining now.'),
                ('今天是阴天。', 'It is cloudy today.'),
                ('今天天气很好。', 'The weather is nice today.'),
                ('今天冷吗？', 'Is it cold today?'),
            ]),
            ('四季', [
                ('我喜欢春天。', 'I like spring.'),
                ('夏天很热。', 'Summer is hot.'),
                ('秋天很凉爽。', 'Autumn is cool.'),
                ('冬天很冷。', 'Winter is cold.'),
                ('我最喜欢的季节是秋天。', 'My favorite season is autumn.'),
                ('冬天过后春天来。', 'Spring comes after winter.'),
            ]),
            ('温度', [
                ('今天非常热。', 'It is very hot today.'),
                ('外面冷得结冰。', 'It is freezing outside.'),
                ('气温是三十度。', 'The temperature is thirty degrees.'),
                ('请关上窗户。', 'Please close the window.'),
                ('我觉得冷。', 'I feel cold.'),
                ('请打开风扇。', 'Turn on the fan, please.'),
            ]),
            ('天气预报', [
                ('明天会下雨。', 'It will rain tomorrow.'),
                ('这个周末是晴天。', 'It will be sunny this weekend.'),
                ('下周会下雪。', 'There will be snow next week.'),
                ('带上雨伞。', 'Take an umbrella with you.'),
                ('暴风雨要来了。', 'The storm is coming.'),
                ('今天穿件外套。', 'Wear a coat today.'),
            ]),
        ],
    },
    {
        'id': 'u8', 'title': '交通与出行',
        'description': '学习交通工具、问路与乘机的实用句子。',
        'lessons': [
            ('交通工具', [
                ('我坐公交上学。', 'I go to school by bus.'),
                ('他开车上班。', 'He drives a car to work.'),
                ('她每天骑自行车。', 'She rides a bike every day.'),
                ('我们坐火车去北京。', 'We take the train to Beijing.'),
                ('地铁很快。', 'The subway is fast.'),
                ('我走路去公园。', 'I walk to the park.'),
            ]),
            ('问路', [
                ('公交站在哪里？', 'Where is the bus stop?'),
                ('我怎么去机场？', 'How can I get to the airport?'),
                ('在红绿灯处左转。', 'Turn left at the traffic light.'),
                ('直走两个街区。', 'Go straight for two blocks.'),
                ('离这里远吗？', 'Is it far from here?'),
                ('你可以坐出租车。', 'You can take a taxi.'),
            ]),
            ('机场', [
                ('我的航班九点起飞。', 'My flight leaves at nine.'),
                ('请出示你的护照。', 'Please show me your passport.'),
                ('我想要靠窗的座位。', 'I want a window seat.'),
                ('飞机准点。', 'The plane is on time.'),
                ('我的行李在哪里？', 'Where is my luggage?'),
                ('请系好安全带。', 'Fasten your seatbelt, please.'),
            ]),
            ('旅行', [
                ('我们下个月去旅行。', 'We will travel next month.'),
                ('我在网上买了两张票。', 'I bought two tickets online.'),
                ('酒店在海边。', 'The hotel is near the sea.'),
                ('我们昨天参观了博物馆。', 'We visited the museum yesterday.'),
                ('这次旅行很棒。', 'The trip was wonderful.'),
                ('我拍了很多照片。', 'I took many photos.'),
            ]),
        ],
    },
    {
        'id': 'u9', 'title': '购物与金钱',
        'description': '学习询价、超市购物、付款与退换的表达。',
        'lessons': [
            ('买东西', [
                ('这件衬衫多少钱？', 'How much is this shirt?'),
                ('我想买一双鞋。', 'I want to buy a pair of shoes.'),
                ('这条裙子太贵了。', 'This dress is too expensive.'),
                ('价格合理。', 'The price is reasonable.'),
                ('有小一点的尺码吗？', 'Do you have a smaller size?'),
                ('我买了。', 'I will take it.'),
            ]),
            ('超市', [
                ('我需要牛奶和鸡蛋。', 'I need some milk and eggs.'),
                ('水果在哪里？', 'Where can I find the fruit?'),
                ('今天的苹果很新鲜。', 'The apples are fresh today.'),
                ('把它放进购物车。', 'Put it in the shopping cart.'),
                ('我需要一个购物袋。', 'I need a shopping bag.'),
                ('商店九点关门。', 'The store closes at nine.'),
            ]),
            ('付款', [
                ('可以刷卡吗？', 'Can I pay by card?'),
                ('你们接受手机支付吗？', 'Do you accept mobile payment?'),
                ('这是找你的零钱。', 'Here is your change.'),
                ('今天打折。', 'It is on sale today.'),
                ('我有一张优惠券。', 'I have a coupon.'),
                ('一共五十元。', 'The total is fifty yuan.'),
            ]),
            ('退换', [
                ('能便宜一点吗？', 'Can you give me a discount?'),
                ('我想退掉这件商品。', 'I want to return this item.'),
                ('尺码不对。', 'This is not the right size.'),
                ('可以换一个新的吗？', 'Can I exchange it for a new one?'),
                ('请给我发票。', 'Please give me the receipt.'),
                ('钱不够。', 'The money is not enough.'),
            ]),
        ],
    },
    {
        'id': 'u10', 'title': '身体与健康',
        'description': '学习身体部位、看病、运动与健康习惯的表达。',
        'lessons': [
            ('身体部位', [
                ('我头疼。', 'My head hurts.'),
                ('她有一头长发。', 'She has long hair.'),
                ('他昨天伤了腿。', 'He hurt his leg yesterday.'),
                ('请洗手。', 'Wash your hands, please.'),
                ('我今天早上刷了牙。', 'I brushed my teeth this morning.'),
                ('我的眼睛累了。', 'My eyes are tired.'),
            ]),
            ('看病', [
                ('我发烧了。', 'I have a fever.'),
                ('你应该去看医生。', 'You should see a doctor.'),
                ('这药一天吃两次。', 'Take this medicine twice a day.'),
                ('多喝水多休息。', 'Drink more water and rest.'),
                ('我嗓子疼。', 'I have a sore throat.'),
                ('医生检查了我的心脏。', 'The doctor checked my heart.'),
            ]),
            ('运动', [
                ('我每天早上跑步。', 'I run every morning.'),
                ('游泳有益健康。', 'Swimming is good for health.'),
                ('他周末打篮球。', 'He plays basketball on weekends.'),
                ('我们在公园锻炼。', 'We do exercise in the park.'),
                ('跑步前拉伸。', 'Stretch before you run.'),
                ('我每天走一万步。', 'I walk ten thousand steps a day.'),
            ]),
            ('健康习惯', [
                ('多吃蔬菜水果。', 'Eat more vegetables and fruit.'),
                ('不要熬夜太晚。', 'Do not stay up too late.'),
                ('每晚睡八小时。', 'Sleep eight hours every night.'),
                ('饭前洗手。', 'Wash your hands before meals.'),
                ('吸烟有害健康。', 'Smoking is bad for your health.'),
                ('好习惯让你强壮。', 'A good habit makes you strong.'),
            ]),
        ],
    },
]


def strip_en(s):
    return re.sub(r'[.!?,;]+$', '', s.strip())


def strip_cn(s):
    return re.sub(r'[。！？，；、]+$', '', s.strip())


def seed_of(key):
    return int(hashlib.md5(key.encode()).hexdigest(), 16)


def pick_distractors(pool, correct, n, seed):
    """从 pool 中取 n 个不等于 correct 的干扰项，固定种子。"""
    rnd = random.Random(seed)
    cands = [p for p in pool if p != correct]
    rnd.shuffle(cands)
    return cands[:n]


def make_options(pool, correct, seed):
    opts = [correct] + pick_distractors(pool, correct, 3, seed)
    random.Random(seed + 1).shuffle(opts)
    return opts


def make_blank(sentence, seed):
    """挖掉一个 3+ 字母单词，返回 (sentenceWithBlank, word)。"""
    words = re.findall(r"[A-Za-z']+", sentence)
    cands = [w for w in words if len(w) >= 3]
    if not cands:
        cands = words
    word = max(cands, key=len)
    blanked = sentence.replace(word, '____', 1)
    return blanked, word


def append_units(units):
    with open(SRC, encoding='utf-8') as f:
        data = json.load(f)

    existing = {u['id'] for u in data['units']}
    for u in units:
        if u['id'] in existing:
            print(f"skip {u['id']} (已存在)")
            continue
        unit = {'id': u['id'], 'title': u['title'],
                'description': u['description'], 'lessons': []}
        # 单元级句池（英文去标点 / 中文去标点）
        en_pool, cn_pool = [], []
        for _, pairs in u['lessons']:
            for cn, en in pairs:
                en_pool.append(strip_en(en))
                cn_pool.append(strip_cn(cn))
        for li, (ltitle, pairs) in enumerate(u['lessons'], 1):
            lid = f"{u['id']}l{li}"
            exs = []
            s = [(strip_cn(c), strip_en(e), c, e) for c, e in pairs]
            # e1 中→英
            exs.append({
                'id': lid + 'e1', 'type': 'translateChoice',
                'prompt': s[0][0], 'sentence': pairs[0][1],
                'options': make_options(en_pool, s[0][1], seed_of(lid + 'e1')),
                'answer': s[0][1], 'sentenceWithBlank': None,
            })
            # e2 英→中
            exs.append({
                'id': lid + 'e2', 'type': 'translateChoice',
                'prompt': pairs[1][1], 'sentence': pairs[1][1],
                'options': make_options(cn_pool, s[1][0], seed_of(lid + 'e2')),
                'answer': s[1][0], 'sentenceWithBlank': None,
            })
            # e3 中→英
            exs.append({
                'id': lid + 'e3', 'type': 'translateChoice',
                'prompt': s[2][0], 'sentence': pairs[2][1],
                'options': make_options(en_pool, s[2][1], seed_of(lid + 'e3')),
                'answer': s[2][1], 'sentenceWithBlank': None,
            })
            # e4/e5 wordBank
            exs.append({
                'id': lid + 'e4', 'type': 'wordBank',
                'prompt': pairs[3][0], 'sentence': pairs[3][1],
                'options': [], 'answer': pairs[3][1],
                'sentenceWithBlank': None,
            })
            exs.append({
                'id': lid + 'e5', 'type': 'wordBank',
                'prompt': pairs[4][0], 'sentence': pairs[4][1],
                'options': [], 'answer': pairs[4][1],
                'sentenceWithBlank': None,
            })
            # e6/e7 listeningChoice
            exs.append({
                'id': lid + 'e6', 'type': 'listeningChoice',
                'prompt': '听一听，选出正确的意思', 'sentence': pairs[5][1],
                'options': make_options(cn_pool, s[5][0], seed_of(lid + 'e6')),
                'answer': s[5][0], 'sentenceWithBlank': None,
            })
            exs.append({
                'id': lid + 'e7', 'type': 'listeningChoice',
                'prompt': '听一听，选出正确的意思', 'sentence': pairs[0][1],
                'options': make_options(cn_pool, s[0][0], seed_of(lid + 'e7')),
                'answer': s[0][0], 'sentenceWithBlank': None,
            })
            # e8 fillBlank（挖 s4 的英文）
            blanked, word = make_blank(pairs[3][1], lid)
            exs.append({
                'id': lid + 'e8', 'type': 'fillBlank',
                'prompt': '补全句子：' + pairs[3][0], 'sentence': pairs[3][1],
                'options': [], 'answer': word,
                'sentenceWithBlank': blanked,
            })
            unit['lessons'].append({'id': lid, 'title': ltitle,
                                    'exercises': exs})
        data['units'].append(unit)
        print(f"added {u['id']} {u['title']}: {len(unit['lessons'])} lessons")

    with open(SRC, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=True, indent=2)

    # 校验
    nu = len(data['units'])
    nl = sum(len(u['lessons']) for u in data['units'])
    ne = sum(len(l['exercises']) for u in data['units'] for l in u['lessons'])
    print(f'TOTAL units={nu} lessons={nl} exercises={ne}')


if __name__ == '__main__':
    append_units(UNITS)
