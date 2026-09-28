#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""自动生成零基础 64 关，并为初级追加 64 关。"""
from __future__ import annotations

import json
import random
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COURSES = ROOT / "assets" / "courses"

DISTRACTORS_EN = [
    "Hello", "Thanks", "Sorry", "Please", "Goodbye", "Yes", "No", "Okay",
    "Water", "Apple", "Book", "School", "Friend", "Happy", "Today", "Home",
    "Mother", "Father", "Teacher", "Student", "Morning", "Night", "Food",
    "Bus", "Car", "Park", "Music", "Game", "Work", "Study",
]
DISTRACTORS_ZH = [
    "你好", "谢谢", "对不起", "请", "再见", "是的", "不", "好的",
    "水", "苹果", "书", "学校", "朋友", "开心", "今天", "家",
    "妈妈", "爸爸", "老师", "学生", "早上", "晚上", "食物",
    "公交", "汽车", "公园", "音乐", "游戏", "工作", "学习",
]


def _blank_word(sentence: str) -> tuple[str, str]:
    words = sentence.rstrip(".!?").split()
    # 优先挖较长实词
    candidates = [w for w in words if len(w) >= 3 and w[0].islower() or w[0].isupper()]
    if not candidates:
        candidates = words
    target = max(candidates, key=len)
    with_blank = sentence.replace(target, "____", 1)
    return target, with_blank


def _options(correct: str, pool: list[str], k: int = 4) -> list[str]:
    opts = {correct}
    for item in pool:
        if item != correct:
            opts.add(item)
        if len(opts) >= k:
            break
    # 补足
    i = 0
    while len(opts) < k:
        opts.add(f"Option{i}")
        i += 1
    out = list(opts)[:k]
    random.shuffle(out)
    if correct not in out:
        out[0] = correct
        random.shuffle(out)
    return out


def build_lesson(
    lesson_id: str,
    title: str,
    items: list[tuple[str, str]],
    rng: random.Random,
) -> dict:
    """items: (zh, en_sentence) 至少 6 条。"""
    assert len(items) >= 6, lesson_id
    picks = items[:6]
    exercises = []

    # 3x translateChoice — 交替中英方向
    for i, (zh, en) in enumerate(picks[:3]):
        eid = f"{lesson_id}e{i + 1}"
        if i % 2 == 0:
            exercises.append(
                {
                    "id": eid,
                    "type": "translateChoice",
                    "prompt": zh,
                    "sentence": en if en.endswith((".", "!", "?")) else en + ".",
                    "options": _options(
                        en.rstrip(".!?"),
                        [x.rstrip(".!?") for _, x in items] + DISTRACTORS_EN,
                    ),
                    "answer": en.rstrip(".!?"),
                    "sentenceWithBlank": None,
                }
            )
        else:
            sent = en if en.endswith((".", "!", "?")) else en + "."
            exercises.append(
                {
                    "id": eid,
                    "type": "translateChoice",
                    "prompt": sent,
                    "sentence": sent,
                    "options": _options(zh, [z for z, _ in items] + DISTRACTORS_ZH),
                    "answer": zh,
                    "sentenceWithBlank": None,
                }
            )

    # 2x wordBank
    for i, (zh, en) in enumerate(picks[3:5]):
        sent = en if en.endswith((".", "!", "?")) else en + "."
        exercises.append(
            {
                "id": f"{lesson_id}e{4 + i}",
                "type": "wordBank",
                "prompt": zh,
                "sentence": sent,
                "options": [],
                "answer": sent,
                "sentenceWithBlank": None,
            }
        )

    # 2x listeningChoice
    for i, (zh, en) in enumerate(picks[1:3]):
        sent = en if en.endswith((".", "!", "?")) else en + "."
        exercises.append(
            {
                "id": f"{lesson_id}e{6 + i}",
                "type": "listeningChoice",
                "prompt": "听一听，选出正确的意思",
                "sentence": sent,
                "options": _options(zh, [z for z, _ in items] + DISTRACTORS_ZH),
                "answer": zh,
                "sentenceWithBlank": None,
            }
        )

    # fillBlank
    zh, en = picks[5]
    sent = en if en.endswith((".", "!", "?")) else en + "."
    answer, blank = _blank_word(sent)
    exercises.append(
        {
            "id": f"{lesson_id}e8",
            "type": "fillBlank",
            "prompt": f"补全句子：{zh}",
            "sentence": sent,
            "options": [],
            "answer": answer,
            "sentenceWithBlank": blank,
        }
    )

    # speaking
    zh, en = picks[0]
    sent = en if en.endswith((".", "!", "?")) else en + "."
    exercises.append(
        {
            "id": f"{lesson_id}e9",
            "type": "speaking",
            "prompt": zh,
            "sentence": sent,
            "options": [],
            "answer": sent,
        }
    )
    return {"id": lesson_id, "title": title, "exercises": exercises}


def build_unit(
    unit_id: str,
    title: str,
    description: str,
    lesson_specs: list[tuple[str, str, list[tuple[str, str]]]],
    rng: random.Random,
) -> dict:
    lessons = []
    for idx, (lid_suffix, ltitle, items) in enumerate(lesson_specs, start=1):
        lid = f"{unit_id}l{idx}" if not lid_suffix else lid_suffix
        lessons.append(build_lesson(lid, ltitle, items, rng))
    return {
        "id": unit_id,
        "title": title,
        "description": description,
        "lessons": lessons,
    }


# ---------- 零基础 16 单元主题词句 ----------
ZERO_UNITS: list[tuple[str, str, str, list[tuple[str, list[tuple[str, str]]]]]] = [
    (
        "字母与发音",
        "认识常见字母与极简发音词。",
        [
            ("字母 A B C", [
                ("这是 A。", "This is A."),
                ("这是 B。", "This is B."),
                ("说 C。", "Say C."),
                ("字母 D。", "Letter D."),
                ("我看见 E。", "I see E."),
                ("这是 F。", "This is F."),
            ]),
            ("元音字母", [
                ("A 是元音。", "A is a vowel."),
                ("E 是元音。", "E is a vowel."),
                ("I 是元音。", "I is a vowel."),
                ("O 是元音。", "O is a vowel."),
                ("U 是元音。", "U is a vowel."),
                ("读一读 A。", "Read A."),
            ]),
            ("简单拼读", [
                ("猫是 cat。", "Cat."),
                ("狗是 dog。", "Dog."),
                ("太阳是 sun。", "Sun."),
                ("月亮是 moon。", "Moon."),
                ("书是 book。", "Book."),
                ("笔是 pen。", "Pen."),
            ]),
            ("跟我读", [
                ("跟我读。", "Repeat after me."),
                ("再读一次。", "Read again."),
                ("大声读。", "Read aloud."),
                ("慢一点。", "Slowly."),
                ("很好。", "Very good."),
                ("继续。", "Continue."),
            ]),
        ],
    ),
    (
        "数字 1–10",
        "会说一到十。",
        [
            ("一到五", [
                ("一。", "One."),
                ("二。", "Two."),
                ("三。", "Three."),
                ("四。", "Four."),
                ("五。", "Five."),
                ("数到五。", "Count to five."),
            ]),
            ("六到十", [
                ("六。", "Six."),
                ("七。", "Seven."),
                ("八。", "Eight."),
                ("九。", "Nine."),
                ("十。", "Ten."),
                ("数到十。", "Count to ten."),
            ]),
            ("几个？", [
                ("一个苹果。", "One apple."),
                ("两个书。", "Two books."),
                ("三个笔。", "Three pens."),
                ("有多少？", "How many?"),
                ("五个。", "Five."),
                ("十个朋友。", "Ten friends."),
            ]),
            ("电话数字", [
                ("我的号码是一。", "My number is one."),
                ("拨二。", "Dial two."),
                ("按三。", "Press three."),
                ("记住四。", "Remember four."),
                ("写下五。", "Write five."),
                ("号码是六。", "The number is six."),
            ]),
        ],
    ),
    (
        "颜色入门",
        "认识基本颜色词。",
        [
            ("红黄蓝", [
                ("红色。", "Red."),
                ("黄色。", "Yellow."),
                ("蓝色。", "Blue."),
                ("这是红色。", "This is red."),
                ("我喜欢蓝色。", "I like blue."),
                ("黄色的太阳。", "A yellow sun."),
            ]),
            ("绿黑白", [
                ("绿色。", "Green."),
                ("黑色。", "Black."),
                ("白色。", "White."),
                ("绿树。", "A green tree."),
                ("黑猫。", "A black cat."),
                ("白云。", "White clouds."),
            ]),
            ("指认颜色", [
                ("什么颜色？", "What color is it?"),
                ("它是红色的。", "It is red."),
                ("选蓝色。", "Choose blue."),
                ("我看见绿色。", "I see green."),
                ("粉色很好看。", "Pink is pretty."),
                ("橙色的橙子。", "An orange orange."),
            ]),
            ("我的颜色", [
                ("我的书包是蓝色的。", "My bag is blue."),
                ("我的笔是黑色的。", "My pen is black."),
                ("我喜欢红色。", "I like red."),
                ("白色的纸。", "White paper."),
                ("绿色很好。", "Green is nice."),
                ("黄色的花。", "Yellow flowers."),
            ]),
        ],
    ),
    (
        "课堂用语",
        "听懂老师常用指令。",
        [
            ("坐下起立", [
                ("请坐。", "Sit down."),
                ("起立。", "Stand up."),
                ("到前面来。", "Come here."),
                ("回到座位。", "Go back."),
                ("安静。", "Be quiet."),
                ("听我说。", "Listen to me."),
            ]),
            ("打开书", [
                ("打开书。", "Open your book."),
                ("合上书。", "Close your book."),
                ("看黑板。", "Look at the board."),
                ("拿出笔。", "Take out a pen."),
                ("写一写。", "Write it down."),
                ("举手。", "Raise your hand."),
            ]),
            ("问答礼貌", [
                ("我可以问吗？", "May I ask?"),
                ("我不明白。", "I do not understand."),
                ("请再说一次。", "Please say it again."),
                ("谢谢老师。", "Thank you, teacher."),
                ("对不起，我迟到了。", "Sorry I am late."),
                ("我准备好了。", "I am ready."),
            ]),
            ("小组活动", [
                ("两人一组。", "Work in pairs."),
                ("讨论一下。", "Talk about it."),
                ("轮到你了。", "It is your turn."),
                ("开始。", "Start."),
                ("停。", "Stop."),
                ("做得好。", "Well done."),
            ]),
        ],
    ),
    (
        "身体部位",
        "说出头、手、脚等部位。",
        [
            ("头与脸", [
                ("这是头。", "This is my head."),
                ("这是眼睛。", "These are my eyes."),
                ("这是鼻子。", "This is my nose."),
                ("这是嘴巴。", "This is my mouth."),
                ("摸摸头。", "Touch your head."),
                ("闭上眼睛。", "Close your eyes."),
            ]),
            ("手脚", [
                ("这是手。", "This is my hand."),
                ("这是脚。", "This is my foot."),
                ("拍手。", "Clap your hands."),
                ("跺脚。", "Stamp your feet."),
                ("举起手。", "Put up your hand."),
                ("两只手。", "Two hands."),
            ]),
            ("身体动作", [
                ("点头。", "Nod your head."),
                ("摇头。", "Shake your head."),
                ("转一圈。", "Turn around."),
                ("跳一跳。", "Jump."),
                ("跑一跑。", "Run."),
                ("走一走。", "Walk."),
            ]),
            ("不舒服", [
                ("我头疼。", "I have a headache."),
                ("我肚子疼。", "My stomach hurts."),
                ("我累了。", "I am tired."),
                ("我渴了。", "I am thirsty."),
                ("我饿了。", "I am hungry."),
                ("我很好。", "I am fine."),
            ]),
        ],
    ),
    (
        "家庭成员",
        "介绍爸爸妈妈和家人。",
        [
            ("爸爸妈妈", [
                ("这是我爸爸。", "This is my father."),
                ("这是我妈妈。", "This is my mother."),
                ("我爱我的家人。", "I love my family."),
                ("我的爸爸很高。", "My father is tall."),
                ("我的妈妈很亲切。", "My mother is kind."),
                ("我们是一家人。", "We are a family."),
            ]),
            ("兄弟姐妹", [
                ("我有一个哥哥。", "I have a brother."),
                ("我有一个姐姐。", "I have a sister."),
                ("他是我弟弟。", "He is my brother."),
                ("她是我妹妹。", "She is my sister."),
                ("我们一起玩。", "We play together."),
                ("我没有兄弟姐妹。", "I have no brothers or sisters."),
            ]),
            ("祖辈", [
                ("这是我爷爷。", "This is my grandpa."),
                ("这是我奶奶。", "This is my grandma."),
                ("爷爷讲故事。", "Grandpa tells stories."),
                ("奶奶做饭。", "Grandma cooks."),
                ("我看望爷爷。", "I visit grandpa."),
                ("我爱奶奶。", "I love grandma."),
            ]),
            ("我家", [
                ("我家有四口人。", "There are four people in my family."),
                ("我家很温暖。", "My home is warm."),
                ("我住在城里。", "I live in the city."),
                ("这是我家。", "This is my home."),
                ("欢迎来我家。", "Welcome to my home."),
                ("我家不大。", "My home is not big."),
            ]),
        ],
    ),
    (
        "食物饮料",
        "点简单食物和饮料。",
        [
            ("水果", [
                ("我想要苹果。", "I want an apple."),
                ("香蕉很好吃。", "Bananas are tasty."),
                ("橙子是橙色的。", "An orange is orange."),
                ("我喜欢西瓜。", "I like watermelon."),
                ("吃个葡萄。", "Have some grapes."),
                ("这是梨。", "This is a pear."),
            ]),
            ("主食", [
                ("我吃米饭。", "I eat rice."),
                ("我想吃面条。", "I want noodles."),
                ("面包和牛奶。", "Bread and milk."),
                ("早餐吃鸡蛋。", "I eat eggs for breakfast."),
                ("午饭很香。", "Lunch is delicious."),
                ("晚饭简单。", "Dinner is simple."),
            ]),
            ("饮料", [
                ("我想喝水。", "I want some water."),
                ("一杯茶。", "A cup of tea."),
                ("牛奶好喝。", "Milk is nice."),
                ("果汁请。", "Juice, please."),
                ("我不喝咖啡。", "I do not drink coffee."),
                ("热水可以吗？", "Hot water, please?"),
            ]),
            ("点餐", [
                ("菜单在哪里？", "Where is the menu?"),
                ("我要点这个。", "I will have this."),
                ("账单请。", "The bill, please."),
                ("很好吃。", "It is delicious."),
                ("我不吃辣。", "I do not eat spicy food."),
                ("谢谢招待。", "Thank you for the meal."),
            ]),
        ],
    ),
    (
        "动物世界",
        "认识常见动物名称。",
        [
            ("宠物", [
                ("我有一只猫。", "I have a cat."),
                ("狗很友好。", "Dogs are friendly."),
                ("兔子很可爱。", "Rabbits are cute."),
                ("鱼在水里。", "Fish live in water."),
                ("鸟会飞。", "Birds can fly."),
                ("我喜欢宠物。", "I like pets."),
            ]),
            ("农场", [
                ("牛很大。", "Cows are big."),
                ("羊吃草。", "Sheep eat grass."),
                ("马跑得快。", "Horses run fast."),
                ("鸡会叫。", "Chickens crow."),
                ("猪很胖。", "Pigs are fat."),
                ("农场很热闹。", "The farm is busy."),
            ]),
            ("动物园", [
                ("狮子很强壮。", "Lions are strong."),
                ("大象很大。", "Elephants are huge."),
                ("猴子爱玩。", "Monkeys like to play."),
                ("熊猫吃竹子。", "Pandas eat bamboo."),
                ("老虎有条纹。", "Tigers have stripes."),
                ("我去动物园。", "I go to the zoo."),
            ]),
            ("声音动作", [
                ("猫说喵。", "Cats say meow."),
                ("狗说汪。", "Dogs say woof."),
                ("鸟在唱歌。", "Birds are singing."),
                ("鱼在游泳。", "Fish are swimming."),
                ("马在跑。", "Horses are running."),
                ("兔子在跳。", "Rabbits are jumping."),
            ]),
        ],
    ),
    (
        "天气穿衣",
        "谈论天气和衣服。",
        [
            ("晴雨", [
                ("今天晴天。", "It is sunny today."),
                ("今天下雨。", "It is raining today."),
                ("今天多云。", "It is cloudy today."),
                ("刮风了。", "It is windy."),
                ("下雪了。", "It is snowing."),
                ("天气很好。", "The weather is nice."),
            ]),
            ("冷热", [
                ("今天很热。", "It is hot today."),
                ("今天很冷。", "It is cold today."),
                ("有点暖和。", "It is warm."),
                ("我觉得冷。", "I feel cold."),
                ("太热了。", "It is too hot."),
                ("温度正好。", "The temperature is fine."),
            ]),
            ("衣服", [
                ("穿上外套。", "Put on your coat."),
                ("脱下帽子。", "Take off your hat."),
                ("这是我的鞋子。", "These are my shoes."),
                ("我穿 T 恤。", "I wear a T-shirt."),
                ("裤子是蓝色的。", "The pants are blue."),
                ("裙子很漂亮。", "The dress is pretty."),
            ]),
            ("出门准备", [
                ("带上雨伞。", "Take an umbrella."),
                ("戴上太阳镜。", "Wear sunglasses."),
                ("多穿一点。", "Wear more clothes."),
                ("今天适合出门。", "It is good to go out."),
                ("待在家里吧。", "Stay at home."),
                ("记得围巾。", "Remember your scarf."),
            ]),
        ],
    ),
    (
        "时间日常",
        "说几点和一天作息。",
        [
            ("几点了", [
                ("现在几点？", "What time is it?"),
                ("现在七点。", "It is seven o'clock."),
                ("八点半。", "It is half past eight."),
                ("九点了。", "It is nine."),
                ("快到中午了。", "It is almost noon."),
                ("晚上十点。", "It is ten at night."),
            ]),
            ("起床睡觉", [
                ("我六点起床。", "I get up at six."),
                ("我刷牙。", "I brush my teeth."),
                ("我洗脸。", "I wash my face."),
                ("我十点睡觉。", "I go to bed at ten."),
                ("晚安。", "Good night."),
                ("早上好。", "Good morning."),
            ]),
            ("三餐", [
                ("吃早餐。", "Have breakfast."),
                ("吃午餐。", "Have lunch."),
                ("吃晚餐。", "Have dinner."),
                ("我饿了。", "I am hungry."),
                ("吃点心。", "Have a snack."),
                ("喝水吧。", "Drink some water."),
            ]),
            ("一天", [
                ("今天是周一。", "Today is Monday."),
                ("明天是周二。", "Tomorrow is Tuesday."),
                ("周末快乐。", "Have a nice weekend."),
                ("昨天很忙。", "Yesterday was busy."),
                ("见你明天。", "See you tomorrow."),
                ("今天很特别。", "Today is special."),
            ]),
        ],
    ),
    (
        "学校生活",
        "学校里的人与物。",
        [
            ("教室", [
                ("这是教室。", "This is the classroom."),
                ("那是黑板。", "That is the blackboard."),
                ("这是课桌。", "This is a desk."),
                ("椅子在这里。", "The chair is here."),
                ("门是开的。", "The door is open."),
                ("窗很大。", "The window is big."),
            ]),
            ("文具", [
                ("我有一支笔。", "I have a pen."),
                ("这是橡皮。", "This is an eraser."),
                ("尺子很长。", "The ruler is long."),
                ("书包很重。", "The schoolbag is heavy."),
                ("本子是新的。", "The notebook is new."),
                ("铅笔断了。", "The pencil is broken."),
            ]),
            ("老师同学", [
                ("她是我的老师。", "She is my teacher."),
                ("他是我的同学。", "He is my classmate."),
                ("我们是朋友。", "We are friends."),
                ("老师很好。", "The teacher is nice."),
                ("请教我。", "Please teach me."),
                ("一起学习。", "Let's study together."),
            ]),
            ("科目", [
                ("我喜欢英语。", "I like English."),
                ("数学有点难。", "Math is a bit hard."),
                ("音乐课很有趣。", "Music class is fun."),
                ("体育课我很开心。", "I enjoy PE."),
                ("画画时间到了。", "It is time to draw."),
                ("阅读很重要。", "Reading is important."),
            ]),
        ],
    ),
    (
        "方位场所",
        "说上下左右和常见地点。",
        [
            ("上下左右", [
                ("在上面。", "It is up."),
                ("在下面。", "It is down."),
                ("在左边。", "It is on the left."),
                ("在右边。", "It is on the right."),
                ("在中间。", "It is in the middle."),
                ("在附近。", "It is near."),
            ]),
            ("家里位置", [
                ("书在桌子上。", "The book is on the desk."),
                ("猫在椅子下。", "The cat is under the chair."),
                ("包在门边。", "The bag is by the door."),
                ("灯在房间里。", "The lamp is in the room."),
                ("鞋在门口。", "The shoes are at the door."),
                ("钥匙在哪里？", "Where are the keys?"),
            ]),
            ("社区地点", [
                ("学校在附近。", "The school is nearby."),
                ("公园很大。", "The park is big."),
                ("商店开门了。", "The shop is open."),
                ("医院在那边。", "The hospital is over there."),
                ("图书馆很安静。", "The library is quiet."),
                ("我去超市。", "I go to the supermarket."),
            ]),
            ("怎么走", [
                ("怎么走？", "How do I get there?"),
                ("直行。", "Go straight."),
                ("左转。", "Turn left."),
                ("右转。", "Turn right."),
                ("就在前面。", "It is ahead."),
                ("不远。", "It is not far."),
            ]),
        ],
    ),
    (
        "感觉心情",
        "表达简单感受。",
        [
            ("开心难过", [
                ("我很开心。", "I am happy."),
                ("我有点难过。", "I am a little sad."),
                ("我很兴奋。", "I am excited."),
                ("我很紧张。", "I am nervous."),
                ("别担心。", "Do not worry."),
                ("放轻松。", "Relax."),
            ]),
            ("喜好", [
                ("我喜欢猫。", "I like cats."),
                ("我不喜欢雨。", "I do not like rain."),
                ("你喜欢吗？", "Do you like it?"),
                ("我最爱音乐。", "I love music."),
                ("太棒了。", "That is great."),
                ("一般般。", "It is so-so."),
            ]),
            ("能力", [
                ("我会游泳。", "I can swim."),
                ("我不会开车。", "I cannot drive."),
                ("你会吗？", "Can you?"),
                ("让我试试。", "Let me try."),
                ("太难了。", "It is too hard."),
                ("我做到了。", "I did it."),
            ]),
            ("鼓励", [
                ("加油！", "Come on!"),
                ("你可以的。", "You can do it."),
                ("再试一次。", "Try again."),
                ("不要放弃。", "Do not give up."),
                ("我相信你。", "I believe in you."),
                ("一起努力。", "Let's work hard."),
            ]),
        ],
    ),
    (
        "交通出行",
        "说出行方式。",
        [
            ("交通工具", [
                ("我坐公交。", "I take the bus."),
                ("我坐地铁。", "I take the subway."),
                ("我骑自行车。", "I ride a bike."),
                ("我走路去。", "I walk there."),
                ("开车小心。", "Drive carefully."),
                ("打车吧。", "Let's take a taxi."),
            ]),
            ("出行对话", [
                ("去学校怎么走？", "How do I get to school?"),
                ("下一站是哪？", "What is the next stop?"),
                ("车票多少钱？", "How much is the ticket?"),
                ("请让一下。", "Excuse me."),
                ("到了。", "Here we are."),
                ("快点，要迟到了。", "Hurry, we will be late."),
            ]),
            ("安全", [
                ("红灯停。", "Stop at the red light."),
                ("绿灯行。", "Go at the green light."),
                ("系好安全带。", "Fasten your seat belt."),
                ("看两边。", "Look both ways."),
                ("不要跑。", "Do not run."),
                ("排队上车。", "Line up to get on."),
            ]),
            ("旅行准备", [
                ("带上护照。", "Bring your passport."),
                ("收拾行李。", "Pack your suitcase."),
                ("机票在这里。", "The ticket is here."),
                ("我们出发吧。", "Let's go."),
                ("旅途愉快。", "Have a nice trip."),
                ("我想回家。", "I want to go home."),
            ]),
        ],
    ),
    (
        "购物礼貌",
        "简单购物与礼貌用语。",
        [
            ("礼貌用语", [
                ("请。", "Please."),
                ("谢谢。", "Thank you."),
                ("不客气。", "You are welcome."),
                ("对不起。", "I am sorry."),
                ("没关系。", "It is okay."),
                ("请问。", "Excuse me."),
            ]),
            ("买东西", [
                ("这个多少钱？", "How much is this?"),
                ("太贵了。", "It is too expensive."),
                ("便宜一点。", "A little cheaper."),
                ("我买这个。", "I will buy this."),
                ("还有别的颜色吗？", "Any other colors?"),
                ("能试试吗？", "Can I try it on?"),
            ]),
            ("付钱", [
                ("我用现金。", "I pay in cash."),
                ("可以刷卡吗？", "Can I use a card?"),
                ("找钱。", "Here is the change."),
                ("收据请。", "The receipt, please."),
                ("打包。", "Please pack it."),
                ("谢谢光临。", "Thanks for coming."),
            ]),
            ("退换", [
                ("我想退货。", "I want a refund."),
                ("可以换吗？", "Can I exchange it?"),
                ("尺寸不对。", "The size is wrong."),
                ("坏了。", "It is broken."),
                ("保修吗？", "Is there a warranty?"),
                ("我要投诉。", "I want to complain."),
            ]),
        ],
    ),
    (
        "复习综合",
        "综合复习前面主题的短句。",
        [
            ("问候复习", [
                ("你好，我是李明。", "Hello, I am Li Ming."),
                ("很高兴认识你。", "Nice to meet you."),
                ("你好吗？", "How are you?"),
                ("我很好，谢谢。", "I am fine, thank you."),
                ("再见。", "Goodbye."),
                ("明天见。", "See you tomorrow."),
            ]),
            ("描述复习", [
                ("我有一个红色书包。", "I have a red schoolbag."),
                ("我家有三口人。", "There are three people in my family."),
                ("今天很晴朗。", "It is sunny today."),
                ("我喜欢狗。", "I like dogs."),
                ("我会说一点英语。", "I can speak a little English."),
                ("学校在公园旁边。", "The school is next to the park."),
            ]),
            ("请求复习", [
                ("请帮帮我。", "Please help me."),
                ("请再说一次。", "Please say it again."),
                ("可以坐这里吗？", "May I sit here?"),
                ("给我一杯水。", "Give me a glass of water."),
                ("打开窗户好吗？", "Could you open the window?"),
                ("谢谢你的帮助。", "Thank you for your help."),
            ]),
            ("目标句", [
                ("我会继续学习。", "I will keep learning."),
                ("英语很有趣。", "English is fun."),
                ("每天练习一点。", "Practice a little every day."),
                ("我不怕犯错。", "I am not afraid of mistakes."),
                ("我们一起进步。", "We improve together."),
                ("今天也要加油。", "Keep going today."),
            ]),
        ],
    ),
]


# 初级追加 u17–u32（相对入门更进阶）
PRIMARY_EXTRA: list[tuple[str, str, list[tuple[str, list[tuple[str, str]]]]]] = [
    (
        "计划与安排",
        "谈论近期计划与日程安排。",
        [
            ("周末计划", [
                ("这个周末你打算做什么？", "What are you going to do this weekend?"),
                ("我打算去图书馆。", "I am going to the library."),
                ("我们一起看电影吧。", "Let's watch a movie together."),
                ("我可能待在家里。", "I might stay at home."),
                ("计划有变。", "The plan has changed."),
                ("听起来不错。", "That sounds good."),
            ]),
            ("约会时间", [
                ("我们三点见面。", "Let's meet at three."),
                ("你方便吗？", "Are you free?"),
                ("我可能迟到十分钟。", "I may be ten minutes late."),
                ("改到明天吧。", "Let's change it to tomorrow."),
                ("别忘了带材料。", "Don't forget to bring the materials."),
                ("到时候见。", "See you then."),
            ]),
            ("长期目标", [
                ("我想提高口语。", "I want to improve my speaking."),
                ("我的目标是每天学习。", "My goal is to study every day."),
                ("一步一步来。", "One step at a time."),
                ("坚持很重要。", "Persistence is important."),
                ("我会制订计划。", "I will make a plan."),
                ("检查进度。", "Check your progress."),
            ]),
            ("取消改期", [
                ("我得取消会议。", "I have to cancel the meeting."),
                ("我们能改期吗？", "Can we reschedule?"),
                ("抱歉造成不便。", "Sorry for the inconvenience."),
                ("下周一可以吗？", "Is next Monday okay?"),
                ("我发邮件确认。", "I will email to confirm."),
                ("谢谢理解。", "Thanks for understanding."),
            ]),
        ],
    ),
    (
        "比较与选择",
        "用比较级做简单选择。",
        [
            ("更好更差", [
                ("这个更好。", "This one is better."),
                ("那个更便宜。", "That one is cheaper."),
                ("火车更快。", "The train is faster."),
                ("这本书更有趣。", "This book is more interesting."),
                ("哪一个更好？", "Which one is better?"),
                ("对我来说够好了。", "It is good enough for me."),
            ]),
            ("最喜欢", [
                ("这是我最喜欢的。", "This is my favorite."),
                ("夏天最热。", "Summer is the hottest."),
                ("他是班里最高的。", "He is the tallest in the class."),
                ("我最喜欢周末。", "I like weekends the most."),
                ("最好的办法是练习。", "The best way is to practice."),
                ("没有最好，只有更好。", "There is no best, only better."),
            ]),
            ("权衡", [
                ("一方面很方便。", "On the one hand it is convenient."),
                ("另一方面很贵。", "On the other hand it is expensive."),
                ("我更看重质量。", "I care more about quality."),
                ("价格也很重要。", "Price is also important."),
                ("让我想想。", "Let me think."),
                ("我决定了。", "I have decided."),
            ]),
            ("购物比较", [
                ("这个比那个大。", "This is bigger than that."),
                ("质量看起来更好。", "The quality looks better."),
                ("折扣更多。", "There is a bigger discount."),
                ("我选蓝色的。", "I will choose the blue one."),
                ("值得买吗？", "Is it worth buying?"),
                ("我再看看。", "I will look around more."),
            ]),
        ],
    ),
    (
        "过去经历",
        "用一般过去时讲述经历。",
        [
            ("昨天做了什么", [
                ("昨天我去了公园。", "I went to the park yesterday."),
                ("我看了一部电影。", "I watched a movie."),
                ("我遇见了老朋友。", "I met an old friend."),
                ("天气很好。", "The weather was nice."),
                ("我们聊了很久。", "We talked for a long time."),
                ("我十点回家。", "I went home at ten."),
            ]),
            ("旅行回忆", [
                ("去年我去了北京。", "I went to Beijing last year."),
                ("食物很美味。", "The food was delicious."),
                ("我拍了很多照片。", "I took many photos."),
                ("有点累但很开心。", "I was tired but happy."),
                ("我想再去一次。", "I want to go again."),
                ("那是美好的旅程。", "It was a wonderful trip."),
            ]),
            ("学习经历", [
                ("我学英语三年了。", "I have studied English for three years."),
                ("起初很难。", "It was hard at first."),
                ("老师帮助了我。", "The teacher helped me."),
                ("我通过了考试。", "I passed the exam."),
                ("我犯过很多错。", "I made many mistakes."),
                ("错误帮助我成长。", "Mistakes helped me grow."),
            ]),
            ("难忘一天", [
                ("那是难忘的一天。", "That was an unforgettable day."),
                ("我收到了礼物。", "I received a gift."),
                ("大家都很惊喜。", "Everyone was surprised."),
                ("我们一起唱歌。", "We sang together."),
                ("我笑了很久。", "I laughed for a long time."),
                ("我永远记得。", "I will always remember."),
            ]),
        ],
    ),
    (
        "建议劝告",
        "给出礼貌建议。",
        [
            ("健康建议", [
                ("你应该多喝水。", "You should drink more water."),
                ("最好早点睡。", "You had better sleep early."),
                ("为什么不散步？", "Why not take a walk?"),
                ("试试深呼吸。", "Try deep breathing."),
                ("别熬夜。", "Don't stay up late."),
                ("照顾好自己。", "Take care of yourself."),
            ]),
            ("学习建议", [
                ("你应该每天复习。", "You should review every day."),
                ("可以做笔记。", "You can take notes."),
                ("多听多说。", "Listen and speak more."),
                ("不要怕开口。", "Don't be afraid to speak."),
                ("找个学习伙伴。", "Find a study partner."),
                ("设定小目标。", "Set small goals."),
            ]),
            ("礼貌拒绝", [
                ("谢谢，但我不能。", "Thanks, but I can't."),
                ("也许下次吧。", "Maybe next time."),
                ("我有点忙。", "I am a bit busy."),
                ("让我考虑一下。", "Let me think about it."),
                ("抱歉让你失望。", "Sorry to disappoint you."),
                ("希望你理解。", "I hope you understand."),
            ]),
            ("请求帮助", [
                ("你能帮我吗？", "Could you help me?"),
                ("我想问问意见。", "I would like your advice."),
                ("给我些建议吧。", "Please give me some advice."),
                ("这样行得通吗？", "Will this work?"),
                ("我该怎么办？", "What should I do?"),
                ("谢谢你的建议。", "Thanks for your advice."),
            ]),
        ],
    ),
    (
        "描述人物",
        "外貌性格与兴趣。",
        [
            ("外貌", [
                ("她留着长发。", "She has long hair."),
                ("他戴眼镜。", "He wears glasses."),
                ("她个子很高。", "She is very tall."),
                ("他看起来年轻。", "He looks young."),
                ("她总是微笑。", "She always smiles."),
                ("我们长得很像。", "We look alike."),
            ]),
            ("性格", [
                ("他很友好。", "He is friendly."),
                ("她有点害羞。", "She is a little shy."),
                ("他很幽默。", "He is humorous."),
                ("她很认真。", "She is serious."),
                ("他值得信赖。", "He is trustworthy."),
                ("她充满活力。", "She is energetic."),
            ]),
            ("兴趣", [
                ("他喜欢足球。", "He likes football."),
                ("她热爱阅读。", "She loves reading."),
                ("他会弹钢琴。", "He can play the piano."),
                ("她收集邮票。", "She collects stamps."),
                ("我们有共同爱好。", "We share hobbies."),
                ("兴趣让生活有趣。", "Hobbies make life fun."),
            ]),
            ("介绍朋友", [
                ("这是我最好的朋友。", "This is my best friend."),
                ("我们认识很久了。", "We have known each other for a long time."),
                ("他帮助过我很多次。", "He has helped me many times."),
                ("她很会倾听。", "She is a good listener."),
                ("我们互相支持。", "We support each other."),
                ("珍惜这段友谊。", "Cherish this friendship."),
            ]),
        ],
    ),
    (
        "环境自然",
        "谈论自然与环保。",
        [
            ("自然景色", [
                ("山很高。", "The mountains are high."),
                ("河水流淌。", "The river flows."),
                ("森林很安静。", "The forest is quiet."),
                ("海滩很美。", "The beach is beautiful."),
                ("星星在闪耀。", "The stars are shining."),
                ("空气很清新。", "The air is fresh."),
            ]),
            ("环保行动", [
                ("请节约用水。", "Please save water."),
                ("关掉灯。", "Turn off the lights."),
                ("垃圾分类。", "Sort the trash."),
                ("少用塑料袋。", "Use fewer plastic bags."),
                ("骑自行车出行。", "Ride a bike."),
                ("保护地球。", "Protect the Earth."),
            ]),
            ("天气极端", [
                ("暴雨来了。", "A heavy rain is coming."),
                ("今天有雾。", "It is foggy today."),
                ("注意防暑。", "Beware of the heat."),
                ("路面结冰。", "The road is icy."),
                ("风力很强。", "The wind is strong."),
                ("待在室内更安全。", "It is safer indoors."),
            ]),
            ("城市绿色", [
                ("公园需要树木。", "Parks need trees."),
                ("多种花草。", "Plant more flowers."),
                ("减少噪音。", "Reduce the noise."),
                ("保持街道干净。", "Keep the streets clean."),
                ("共享单车很方便。", "Shared bikes are convenient."),
                ("绿色生活从我做起。", "Green living starts with me."),
            ]),
        ],
    ),
    (
        "科技生活",
        "手机、网络与日常科技。",
        [
            ("手机使用", [
                ("我的手机没电了。", "My phone is out of battery."),
                ("你能发我链接吗？", "Can you send me the link?"),
                ("别玩太久手机。", "Don't use the phone too long."),
                ("打开飞行模式。", "Turn on airplane mode."),
                ("我更新了应用。", "I updated the app."),
                ("信号很差。", "The signal is weak."),
            ]),
            ("上网学习", [
                ("我在网上找资料。", "I look up information online."),
                ("小心虚假信息。", "Beware of false information."),
                ("保护密码。", "Protect your password."),
                ("不要点击陌生链接。", "Don't click strange links."),
                ("云盘很方便。", "Cloud storage is convenient."),
                ("我下载了课件。", "I downloaded the slides."),
            ]),
            ("智能设备", [
                ("智能手表很酷。", "Smart watches are cool."),
                ("语音助手能帮忙。", "Voice assistants can help."),
                ("扫码支付。", "Pay by scanning a code."),
                ("导航带我走。", "Navigation guides me."),
                ("耳机没电了。", "The earphones are dead."),
                ("科技改变生活。", "Technology changes life."),
            ]),
            ("数字礼仪", [
                ("开会请静音。", "Please mute in meetings."),
                ("及时回复消息。", "Reply to messages in time."),
                ("不要剧透。", "No spoilers."),
                ("尊重隐私。", "Respect privacy."),
                ("线上也要礼貌。", "Be polite online too."),
                ("少发无意义消息。", "Send fewer useless messages."),
            ]),
        ],
    ),
    (
        "工作职场",
        "简单职场沟通。",
        [
            ("日常工作", [
                ("我今天很忙。", "I am busy today."),
                ("截止日期是周五。", "The deadline is Friday."),
                ("我完成了报告。", "I finished the report."),
                ("我们开个短会。", "Let's have a short meeting."),
                ("把文件发给我。", "Send me the file."),
                ("注意细节。", "Pay attention to details."),
            ]),
            ("团队合作", [
                ("我们需要合作。", "We need to cooperate."),
                ("分工很清楚。", "The division of work is clear."),
                ("我支持你的想法。", "I support your idea."),
                ("有问题及时说。", "Speak up if there is a problem."),
                ("一起解决问题。", "Let's solve it together."),
                ("谢谢团队。", "Thanks, team."),
            ]),
            ("面试基础", [
                ("请介绍一下自己。", "Please introduce yourself."),
                ("我的优势是认真。", "My strength is being careful."),
                ("我能很快学习。", "I can learn quickly."),
                ("你为什么申请？", "Why did you apply?"),
                ("我可以加班。", "I can work overtime."),
                ("期待你的回复。", "I look forward to your reply."),
            ]),
            ("办公礼貌", [
                ("打扰一下。", "Sorry to interrupt."),
                ("方便现在说吗？", "Is now a good time?"),
                ("我会跟进。", "I will follow up."),
                ("收到，谢谢。", "Got it, thanks."),
                ("辛苦了。", "Thanks for your hard work."),
                ("周末愉快。", "Have a nice weekend."),
            ]),
        ],
    ),
    (
        "健康生活",
        "运动、饮食与作息。",
        [
            ("运动习惯", [
                ("我每周跑步三次。", "I run three times a week."),
                ("拉伸很重要。", "Stretching is important."),
                ("别受伤。", "Don't get hurt."),
                ("今天去健身房。", "I am going to the gym today."),
                ("和朋友打球。", "Play ball with friends."),
                ("运动让我快乐。", "Exercise makes me happy."),
            ]),
            ("健康饮食", [
                ("多吃蔬菜。", "Eat more vegetables."),
                ("少喝甜饮料。", "Drink fewer sweet drinks."),
                ("早餐不能省。", "Don't skip breakfast."),
                ("细嚼慢咽。", "Chew slowly."),
                ("多喝温水。", "Drink more warm water."),
                ("均衡饮食。", "Eat a balanced diet."),
            ]),
            ("看病就医", [
                ("我预约了医生。", "I made a doctor's appointment."),
                ("我感冒了。", "I have a cold."),
                ("按说明吃药。", "Take medicine as directed."),
                ("多休息。", "Get more rest."),
                ("量一下体温。", "Take your temperature."),
                ("感觉好多了。", "I feel much better."),
            ]),
            ("心理调节", [
                ("压力有点大。", "I am under some pressure."),
                ("和朋友聊聊。", "Talk with a friend."),
                ("写日记有帮助。", "Keeping a journal helps."),
                ("听听音乐放松。", "Listen to music to relax."),
                ("保持积极。", "Stay positive."),
                ("今天也要善待自己。", "Be kind to yourself today."),
            ]),
        ],
    ),
    (
        "文化节日",
        "节日习俗与祝福。",
        [
            ("春节", [
                ("春节快乐！", "Happy Spring Festival!"),
                ("我们吃团圆饭。", "We have a reunion dinner."),
                ("孩子们收红包。", "Children receive red envelopes."),
                ("放鞭炮要小心。", "Be careful with fireworks."),
                ("回家看看父母。", "Go home to see your parents."),
                ("新年新气象。", "A new year, a new look."),
            ]),
            ("中秋元宵", [
                ("中秋节快乐。", "Happy Mid-Autumn Festival."),
                ("一起赏月。", "Enjoy the moon together."),
                ("月饼很甜。", "Mooncakes are sweet."),
                ("元宵节看灯。", "Watch lanterns at the Lantern Festival."),
                ("猜灯谜很有趣。", "Guessing lantern riddles is fun."),
                ("团圆最重要。", "Reunion matters most."),
            ]),
            ("国际节日", [
                ("圣诞快乐。", "Merry Christmas."),
                ("新年快乐。", "Happy New Year."),
                ("感恩节快乐。", "Happy Thanksgiving."),
                ("万圣节很热闹。", "Halloween is lively."),
                ("送祝福卡片。", "Send a greeting card."),
                ("节日气氛很浓。", "The holiday mood is strong."),
            ]),
            ("习俗尊重", [
                ("入乡随俗。", "When in Rome, do as the Romans do."),
                ("尊重不同文化。", "Respect different cultures."),
                ("先了解习俗。", "Learn the customs first."),
                ("礼貌很重要。", "Politeness matters."),
                ("分享你的节日。", "Share your festival."),
                ("世界很大很精彩。", "The world is big and wonderful."),
            ]),
        ],
    ),
    (
        "媒体娱乐",
        "电影、音乐与网络内容。",
        [
            ("看电影", [
                ("这部电影很感人。", "This movie is touching."),
                ("主演表演很好。", "The leading actor performed well."),
                ("结局出人意料。", "The ending was unexpected."),
                ("我们去电影院吧。", "Let's go to the cinema."),
                ("不要剧透结局。", "Don't spoil the ending."),
                ("我想再看一遍。", "I want to watch it again."),
            ]),
            ("音乐歌曲", [
                ("这首歌很好听。", "This song is beautiful."),
                ("我喜欢流行音乐。", "I like pop music."),
                ("你会唱歌吗？", "Can you sing?"),
                ("戴上耳机听。", "Listen with earphones."),
                ("节奏很轻快。", "The rhythm is lively."),
                ("音乐治愈心灵。", "Music heals the mind."),
            ]),
            ("短视频", [
                ("这个视频很火。", "This video is popular."),
                ("别刷太久。", "Don't scroll for too long."),
                ("内容要真实。", "Content should be real."),
                ("我学会了一个技巧。", "I learned a tip."),
                ("分享给你。", "Sharing it with you."),
                ("理性看待热搜。", "View trending topics rationally."),
            ]),
            ("书籍故事", [
                ("这本书值得读。", "This book is worth reading."),
                ("故事很励志。", "The story is inspiring."),
                ("我做了读书笔记。", "I took reading notes."),
                ("作者很有名。", "The author is famous."),
                ("借给我看看。", "Lend it to me."),
                ("阅读开阔视野。", "Reading broadens the mind."),
            ]),
        ],
    ),
    (
        "社区服务",
        "邻里互助与公共服务。",
        [
            ("邻里相处", [
                ("邻居很友善。", "The neighbors are friendly."),
                ("小声一点。", "Please keep it down."),
                ("帮我收个快递。", "Please help me take a parcel."),
                ("楼道保持干净。", "Keep the hallway clean."),
                ("见面打个招呼。", "Say hello when you meet."),
                ("和睦很重要。", "Harmony matters."),
            ]),
            ("志愿服务", [
                ("我想做志愿者。", "I want to be a volunteer."),
                ("我们打扫公园。", "We clean the park."),
                ("帮助老人过马路。", "Help the elderly cross the road."),
                ("献血很有意义。", "Donating blood is meaningful."),
                ("捐出旧衣服。", "Donate old clothes."),
                ("小小行动很温暖。", "Small actions are warm."),
            ]),
            ("公共服务", [
                ("图书馆免费开放。", "The library is free."),
                ("如何办卡？", "How do I get a card?"),
                ("公交卡可以充值。", "You can top up the bus card."),
                ("报修电话是多少？", "What is the repair hotline?"),
                ("社区有活动。", "There is a community event."),
                ("积极参与。", "Take an active part."),
            ]),
            ("紧急情况", [
                ("请拨打急救电话。", "Please call emergency services."),
                ("保持冷静。", "Stay calm."),
                ("离开危险区域。", "Leave the danger area."),
                ("听从指挥。", "Follow instructions."),
                ("互相帮助。", "Help each other."),
                ("安全第一。", "Safety first."),
            ]),
        ],
    ),
    (
        "金钱理财",
        "花钱、存钱与简单理财。",
        [
            ("日常开支", [
                ("我记账。", "I keep accounts."),
                ("这个月超支了。", "I overspent this month."),
                ("先分清需要和想要。", "Tell needs from wants."),
                ("午餐别太贵。", "Don't spend too much on lunch."),
                ("找找优惠。", "Look for discounts."),
                ("量入为出。", "Live within your means."),
            ]),
            ("存钱目标", [
                ("我想存钱旅行。", "I want to save for a trip."),
                ("每月存一点。", "Save a little each month."),
                ("开一个储蓄账户。", "Open a savings account."),
                ("不要冲动消费。", "Don't buy on impulse."),
                ("目标要具体。", "Make the goal specific."),
                ("坚持就能实现。", "Keep going and you will make it."),
            ]),
            ("支付方式", [
                ("我用移动支付。", "I use mobile payment."),
                ("现金也行。", "Cash is fine too."),
                ("注意支付安全。", "Mind payment security."),
                ("别泄露验证码。", "Don't share verification codes."),
                ("核对账单。", "Check the bill."),
                ("保留凭证。", "Keep the receipt."),
            ]),
            ("理性消费", [
                ("先比较再买。", "Compare before you buy."),
                ("质量比品牌重要。", "Quality matters more than brand."),
                ("二手也能很好。", "Second-hand can be fine."),
                ("共享减少浪费。", "Sharing reduces waste."),
                ("理财从了解开始。", "Money skills start with learning."),
                ("小钱也要认真对待。", "Treat small money carefully too."),
            ]),
        ],
    ),
    (
        "旅行进阶",
        "订票、住宿与旅途沟通。",
        [
            ("订票入住", [
                ("我想订一张票。", "I want to book a ticket."),
                ("还有座位吗？", "Are there seats left?"),
                ("单程还是往返？", "One way or round trip?"),
                ("靠窗的座位。", "A window seat, please."),
                ("行李额度多少？", "What is the baggage allowance?"),
                ("确认邮件发我。", "Send me the confirmation email."),
            ]),
            ("酒店入住", [
                ("我预订了房间。", "I booked a room."),
                ("办理入住。", "Check in, please."),
                ("电梯在哪里？", "Where is the elevator?"),
                ("Wi-Fi 密码是什么？", "What is the Wi-Fi password?"),
                ("明天退房。", "I will check out tomorrow."),
                ("可以延迟退房吗？", "Can I have a late checkout?"),
            ]),
            ("旅途问题", [
                ("我迷路了。", "I am lost."),
                ("地图怎么看？", "How do I read the map?"),
                ("附近有药店吗？", "Is there a pharmacy nearby?"),
                ("我的行李不见了。", "My luggage is missing."),
                ("请帮我叫出租车。", "Please call a taxi for me."),
                ("谢谢你的帮助。", "Thank you for your help."),
            ]),
            ("旅行感受", [
                ("景色超出预期。", "The view exceeded expectations."),
                ("当地人很热情。", "Local people are warm."),
                ("我想再来一次。", "I want to come again."),
                ("拍了很多回忆。", "I took many memories."),
                ("旅途让人成长。", "Travel helps you grow."),
                ("下次去海边。", "Next time, the seaside."),
            ]),
        ],
    ),
    (
        "观点表达",
        "表达同意、反对与理由。",
        [
            ("同意反对", [
                ("我同意你的看法。", "I agree with you."),
                ("我不完全同意。", "I don't completely agree."),
                ("在我看来不同。", "In my view it is different."),
                ("你说得有道理。", "You have a point."),
                ("我们求同存异。", "Let's agree to disagree."),
                ("可以再讨论。", "We can discuss further."),
            ]),
            ("给出理由", [
                ("因为更方便。", "Because it is more convenient."),
                ("所以我选择这个。", "So I choose this."),
                ("主要原因是时间。", "The main reason is time."),
                ("举例来说。", "For example."),
                ("另一方面也不错。", "On the other hand it is fine too."),
                ("总而言之。", "In conclusion."),
            ]),
            ("讨论话题", [
                ("你怎么看这件事？", "What do you think about this?"),
                ("这是一个热门话题。", "This is a hot topic."),
                ("信息要核实。", "Information should be verified."),
                ("换位思考。", "Put yourself in others' shoes."),
                ("理性表达很重要。", "Rational expression matters."),
                ("倾听也很重要。", "Listening is also important."),
            ]),
            ("总结发言", [
                ("我的观点是坚持学习。", "My view is to keep learning."),
                ("关键在于行动。", "The key is action."),
                ("细节决定成败。", "Details decide success."),
                ("合作能走得更远。", "Cooperation goes further."),
                ("今天收获很大。", "I gained a lot today."),
                ("谢谢大家的时间。", "Thanks for your time."),
            ]),
        ],
    ),
    (
        "综合进阶",
        "综合运用计划、比较与观点。",
        [
            ("场景综合一", [
                ("下周我有一场考试。", "I have an exam next week."),
                ("我需要更好的计划。", "I need a better plan."),
                ("早起比熬夜更有效。", "Getting up early works better than staying up late."),
                ("昨天我复习了三小时。", "I reviewed for three hours yesterday."),
                ("你可以给我些建议吗？", "Could you give me some advice?"),
                ("谢谢，我会努力。", "Thanks, I will work hard."),
            ]),
            ("场景综合二", [
                ("这家餐厅比那家安静。", "This restaurant is quieter than that one."),
                ("我们六点见面可以吗？", "Shall we meet at six?"),
                ("我坐地铁更方便。", "Taking the subway is more convenient for me."),
                ("如果下雨就改室内。", "If it rains, we will stay indoors."),
                ("别忘了带伞。", "Don't forget an umbrella."),
                ("期待周末。", "Looking forward to the weekend."),
            ]),
            ("场景综合三", [
                ("我刚看完一部纪录片。", "I just finished a documentary."),
                ("它让我思考环保。", "It made me think about the environment."),
                ("我们应该减少浪费。", "We should reduce waste."),
                ("从小事做起。", "Start with small things."),
                ("你可以加入志愿活动。", "You can join volunteer activities."),
                ("一起让社区更好。", "Let's make the community better."),
            ]),
            ("结业寄语", [
                ("你已经进步很多。", "You have improved a lot."),
                ("继续保持好奇心。", "Keep your curiosity."),
                ("英语是一把钥匙。", "English is a key."),
                ("世界因交流而近。", "The world gets closer through communication."),
                ("下一段旅程更精彩。", "The next journey will be more exciting."),
                ("我们更高处见。", "See you at a higher level."),
            ]),
        ],
    ),
]


def lessons_from_unit_def(prefix: str, unit_index: int, unit_def) -> dict:
    title, desc, lesson_defs = unit_def
    unit_id = f"{prefix}u{unit_index}"
    specs = []
    for i, (ltitle, items) in enumerate(lesson_defs, start=1):
        specs.append((f"{unit_id}l{i}", ltitle, items))
    rng = random.Random(unit_index * 97 + len(prefix))
    return build_unit(unit_id, title, desc, specs, rng)


def generate_zero() -> dict:
    units = []
    for i, udef in enumerate(ZERO_UNITS, start=1):
        # ZERO_UNITS items are (title, desc, lessons) but first element of outer was wrong
        title, desc, lesson_defs = udef
        units.append(lessons_from_unit_def("z_", i, (title, desc, lesson_defs)))
    return {"id": "zero", "title": "英语零基础", "units": units}


def expand_beginner() -> dict:
    path = COURSES / "course_beginner.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    data["title"] = "英语初级"
    # remove any previously appended u17+ if re-run
    data["units"] = [u for u in data["units"] if not re.match(r"^u(1[7-9]|2\d|3[0-2])$", u["id"])]
    start = len(data["units"]) + 1
    assert start == 17, f"expected 16 base units, got {start - 1}"
    for i, udef in enumerate(PRIMARY_EXTRA, start=17):
        unitspec = lessons_from_unit_def("", i, udef)
        # lessons_from_unit_def with prefix "" gives u17
        data["units"].append(unitspec)
    return data


def validate(course: dict, expect_lessons: int) -> None:
    lessons = [l for u in course["units"] for l in u["lessons"]]
    assert len(lessons) == expect_lessons, (course["id"], len(lessons))
    ids = [l["id"] for l in lessons]
    assert len(ids) == len(set(ids))
    for lesson in lessons:
        assert len(lesson["exercises"]) == 9, lesson["id"]
        types = [e["type"] for e in lesson["exercises"]]
        assert types == [
            "translateChoice",
            "translateChoice",
            "translateChoice",
            "wordBank",
            "wordBank",
            "listeningChoice",
            "listeningChoice",
            "fillBlank",
            "speaking",
        ], (lesson["id"], types)


def main() -> None:
    random.seed(42)
    zero = generate_zero()
    validate(zero, 64)
    (COURSES / "course_zero.json").write_text(
        json.dumps(zero, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print("wrote course_zero.json", len(zero["units"]), "units")

    beginner = expand_beginner()
    validate(beginner, 128)
    (COURSES / "course_beginner.json").write_text(
        json.dumps(beginner, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print("wrote course_beginner.json", len(beginner["units"]), "units", beginner["title"])


if __name__ == "__main__":
    main()
