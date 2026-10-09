# -*- coding: utf-8 -*-
"""幂等补齐 unit_dialogues.json：初级 u17–u34、零基础 z_u1–z_u34。"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "dialogues" / "unit_dialogues.json"

NEW = {
    # beginner u17-u32 (gap fill)
    "u17": [
        {"speaker": 0, "english": "What are you going to do this weekend?", "chinese": "这个周末你打算做什么？"},
        {"speaker": 1, "english": "Let's meet at three and study together.", "chinese": "我们三点见面，一起学习吧。"},
        {"speaker": 0, "english": "Great! I want to improve my speaking too.", "chinese": "太好了！我也想提高口语。"},
    ],
    "u18": [
        {"speaker": 0, "english": "Which bag do you like better?", "chinese": "你更喜欢哪个包？"},
        {"speaker": 1, "english": "This one is better, and it is my favorite color.", "chinese": "这个更好，而且是我最喜欢的颜色。"},
        {"speaker": 0, "english": "I agree. This is bigger than that one.", "chinese": "同意。这个比那个大。"},
    ],
    "u19": [
        {"speaker": 0, "english": "What did you do yesterday?", "chinese": "你昨天做什么了？"},
        {"speaker": 1, "english": "I went to the park. It was an unforgettable day.", "chinese": "我去了公园。那是难忘的一天。"},
        {"speaker": 0, "english": "Nice! I went to Beijing last year.", "chinese": "真棒！我去年去了北京。"},
    ],
    "u20": [
        {"speaker": 0, "english": "I feel tired today. What should I do?", "chinese": "我今天很累。我该怎么办？"},
        {"speaker": 1, "english": "You should drink more water and rest.", "chinese": "你应该多喝水，休息一下。"},
        {"speaker": 0, "english": "Thanks. Could you help me with my homework later?", "chinese": "谢谢。之后你能帮我做作业吗？"},
    ],
    "u21": [
        {"speaker": 0, "english": "Who is that girl with long hair?", "chinese": "那个留长发的女孩是谁？"},
        {"speaker": 1, "english": "She is my best friend. She is friendly and likes football.", "chinese": "她是我最好的朋友。她很友好，还喜欢足球。"},
        {"speaker": 0, "english": "I'd love to meet her!", "chinese": "我很想见见她！"},
    ],
    "u22": [
        {"speaker": 0, "english": "The mountains are high. Shall we go hiking?", "chinese": "山很高。我们去爬山好吗？"},
        {"speaker": 1, "english": "Yes, but please save water on the way.", "chinese": "好，不过路上请节约用水。"},
        {"speaker": 0, "english": "Of course. Parks need trees too.", "chinese": "当然。公园也需要树木。"},
    ],
    "u23": [
        {"speaker": 0, "english": "Oh no, my phone is out of battery.", "chinese": "糟糕，我手机没电了。"},
        {"speaker": 1, "english": "Use my charger. Smart watches are cool, but phones come first.", "chinese": "用我的充电器吧。智能手表很酷，但手机更重要。"},
        {"speaker": 0, "english": "Thanks! And please mute in the meeting later.", "chinese": "谢谢！等会儿开会请静音。"},
    ],
    "u24": [
        {"speaker": 0, "english": "I am busy today. Can we cooperate on this task?", "chinese": "我今天很忙。这个任务我们能合作吗？"},
        {"speaker": 1, "english": "Sure. Sorry to interrupt—please introduce yourself first.", "chinese": "当然。抱歉打断——请先介绍一下自己。"},
        {"speaker": 0, "english": "No problem. Let's start.", "chinese": "没问题。我们开始吧。"},
    ],
    "u25": [
        {"speaker": 0, "english": "I run three times a week now.", "chinese": "我现在每周跑步三次。"},
        {"speaker": 1, "english": "Good! Eat more vegetables and sleep well.", "chinese": "很好！多吃蔬菜，好好睡觉。"},
        {"speaker": 0, "english": "I will. I was under some pressure last month.", "chinese": "我会的。上个月我压力有点大。"},
    ],
    "u26": [
        {"speaker": 0, "english": "Happy Spring Festival, Leo!", "chinese": "里奥，春节快乐！"},
        {"speaker": 1, "english": "Happy Mid-Autumn Festival to your family too!", "chinese": "也祝你家人中秋快乐！"},
        {"speaker": 0, "english": "When in Rome, do as the Romans do.", "chinese": "入乡随俗。"},
    ],
    "u27": [
        {"speaker": 0, "english": "This movie is touching. Want to watch it again?", "chinese": "这部电影很感人。想再看一遍吗？"},
        {"speaker": 1, "english": "Maybe later. This song is beautiful too.", "chinese": "晚点吧。这首歌也很好听。"},
        {"speaker": 0, "english": "True. And this book is worth reading.", "chinese": "没错。而且这本书值得读。"},
    ],
    "u28": [
        {"speaker": 0, "english": "The neighbors are friendly. I want to be a volunteer.", "chinese": "邻居很友善。我想做志愿者。"},
        {"speaker": 1, "english": "Great! The library is free, and we can help there.", "chinese": "太好了！图书馆免费开放，我们可以去帮忙。"},
        {"speaker": 0, "english": "If there is danger, please call emergency services.", "chinese": "如果有危险，请拨打急救电话。"},
    ],
    "u29": [
        {"speaker": 0, "english": "I keep accounts now. I want to save for a trip.", "chinese": "我现在记账了。我想存钱去旅行。"},
        {"speaker": 1, "english": "Smart. I use mobile payment and compare before I buy.", "chinese": "聪明。我用移动支付，买之前先比较。"},
        {"speaker": 0, "english": "Same here. Let's be careful with money.", "chinese": "我也是。我们花钱要小心。"},
    ],
    "u30": [
        {"speaker": 0, "english": "I want to book a ticket and a hotel room.", "chinese": "我想订票，再订一间酒店房。"},
        {"speaker": 1, "english": "I booked a room already. Don't get lost!", "chinese": "我已经订好房间了。别迷路！"},
        {"speaker": 0, "english": "Thanks. I hope the view exceeds expectations.", "chinese": "谢谢。希望景色超出预期。"},
    ],
    "u31": [
        {"speaker": 0, "english": "What do you think about online learning?", "chinese": "你怎么看在线学习？"},
        {"speaker": 1, "english": "I agree with you. It is more convenient.", "chinese": "我同意你的看法。它更方便。"},
        {"speaker": 0, "english": "My view is to keep learning every day.", "chinese": "我的观点是每天坚持学习。"},
    ],
    "u32": [
        {"speaker": 0, "english": "I have an exam next week. I'm a bit nervous.", "chinese": "我下周有考试。有点紧张。"},
        {"speaker": 1, "english": "You have improved a lot. Just keep practicing.", "chinese": "你已经进步很多了。继续练习就好。"},
        {"speaker": 0, "english": "Thanks! Let's celebrate after the test.", "chinese": "谢谢！考完我们庆祝一下。"},
    ],
    # beginner new units
    "u33": [
        {"speaker": 0, "english": "I am sorry I am late. That was my fault.", "chinese": "对不起，我迟到了。这是我的错。"},
        {"speaker": 1, "english": "It's okay. Can you help me fix this problem?", "chinese": "没关系。你能帮我解决这个问题吗？"},
        {"speaker": 0, "english": "Sure. Let's deal with it and start over.", "chinese": "当然。我们处理好，然后重新开始。"},
    ],
    "u34": [
        {"speaker": 0, "english": "My dream is to travel around the world.", "chinese": "我的梦想是环游世界。"},
        {"speaker": 1, "english": "You can do it. Do not give up!", "chinese": "你可以做到。不要放弃！"},
        {"speaker": 0, "english": "I will practice every day. The future is in our hands.", "chinese": "我会每天练习。未来掌握在我们手中。"},
    ],
    # zero dialogues z_u1 - z_u34
    "z_u1": [
        {"speaker": 0, "english": "This is A. Can you say B?", "chinese": "这是 A。你能说 B 吗？"},
        {"speaker": 1, "english": "B! And this is C.", "chinese": "B！这是 C。"},
        {"speaker": 0, "english": "Great job!", "chinese": "很棒！"},
    ],
    "z_u2": [
        {"speaker": 0, "english": "How many apples do you see?", "chinese": "你看到几个苹果？"},
        {"speaker": 1, "english": "I see three apples.", "chinese": "我看到三个苹果。"},
        {"speaker": 0, "english": "Yes! One, two, three.", "chinese": "对！一、二、三。"},
    ],
    "z_u3": [
        {"speaker": 0, "english": "What color is this?", "chinese": "这是什么颜色？"},
        {"speaker": 1, "english": "It is red. I like blue too.", "chinese": "是红色。我也喜欢蓝色。"},
        {"speaker": 0, "english": "Red and blue are nice colors.", "chinese": "红色和蓝色都很好看。"},
    ],
    "z_u4": [
        {"speaker": 0, "english": "Please sit down and open your book.", "chinese": "请坐好，打开书。"},
        {"speaker": 1, "english": "Okay. May I ask a question?", "chinese": "好的。我可以问个问题吗？"},
        {"speaker": 0, "english": "Yes. Listen carefully, please.", "chinese": "可以。请仔细听。"},
    ],
    "z_u5": [
        {"speaker": 0, "english": "Touch your head, please.", "chinese": "请摸摸你的头。"},
        {"speaker": 1, "english": "This is my hand, and these are my feet.", "chinese": "这是我的手，这些是我的脚。"},
        {"speaker": 0, "english": "Very good!", "chinese": "非常好！"},
    ],
    "z_u6": [
        {"speaker": 0, "english": "This is my mom. Who is that?", "chinese": "这是我妈妈。那是谁？"},
        {"speaker": 1, "english": "That is my dad. I love my family.", "chinese": "那是我爸爸。我爱我的家人。"},
        {"speaker": 0, "english": "Your family looks happy.", "chinese": "你的家人看起来很幸福。"},
    ],
    "z_u7": [
        {"speaker": 0, "english": "I am hungry. Can I have some bread?", "chinese": "我饿了。我可以吃点面包吗？"},
        {"speaker": 1, "english": "Sure. Would you like some water too?", "chinese": "当然。你也想来点水吗？"},
        {"speaker": 0, "english": "Yes, please. Thank you!", "chinese": "好的，谢谢！"},
    ],
    "z_u8": [
        {"speaker": 0, "english": "Look! A cat and a dog.", "chinese": "看！一只猫和一只狗。"},
        {"speaker": 1, "english": "I like birds. Do you like fish?", "chinese": "我喜欢鸟。你喜欢鱼吗？"},
        {"speaker": 0, "english": "Yes, fish are cute.", "chinese": "喜欢，鱼很可爱。"},
    ],
    "z_u9": [
        {"speaker": 0, "english": "It is cold today. Wear a coat.", "chinese": "今天很冷。穿件外套。"},
        {"speaker": 1, "english": "Okay. Is it sunny outside?", "chinese": "好。外面是晴天吗？"},
        {"speaker": 0, "english": "No, it is cloudy.", "chinese": "不是，是阴天。"},
    ],
    "z_u10": [
        {"speaker": 0, "english": "What time is it?", "chinese": "现在几点了？"},
        {"speaker": 1, "english": "It is seven. Time for breakfast.", "chinese": "七点了。该吃早餐了。"},
        {"speaker": 0, "english": "I go to bed at nine.", "chinese": "我九点睡觉。"},
    ],
    "z_u11": [
        {"speaker": 0, "english": "This is my school bag.", "chinese": "这是我的书包。"},
        {"speaker": 1, "english": "Where is your classroom?", "chinese": "你的教室在哪里？"},
        {"speaker": 0, "english": "It is next to the library.", "chinese": "在图书馆旁边。"},
    ],
    "z_u12": [
        {"speaker": 0, "english": "The park is on the left.", "chinese": "公园在左边。"},
        {"speaker": 1, "english": "Is the shop on the right?", "chinese": "商店在右边吗？"},
        {"speaker": 0, "english": "Yes. Go straight, please.", "chinese": "是的。请直走。"},
    ],
    "z_u13": [
        {"speaker": 0, "english": "How do you feel today?", "chinese": "你今天感觉怎么样？"},
        {"speaker": 1, "english": "I feel happy. Are you sad?", "chinese": "我很开心。你难过吗？"},
        {"speaker": 0, "english": "No, I feel fine.", "chinese": "不，我感觉很好。"},
    ],
    "z_u14": [
        {"speaker": 0, "english": "How do you go to school?", "chinese": "你怎么去学校？"},
        {"speaker": 1, "english": "I go by bus. Sometimes I walk.", "chinese": "我坐公交车。有时我走路。"},
        {"speaker": 0, "english": "The subway is fast too.", "chinese": "地铁也很快。"},
    ],
    "z_u15": [
        {"speaker": 0, "english": "How much is this pen?", "chinese": "这支笔多少钱？"},
        {"speaker": 1, "english": "It is five yuan. Please take it.", "chinese": "五元。请拿好。"},
        {"speaker": 0, "english": "Thank you very much!", "chinese": "非常感谢！"},
    ],
    "z_u16": [
        {"speaker": 0, "english": "Let's review. What color is the book?", "chinese": "我们复习一下。这本书是什么颜色？"},
        {"speaker": 1, "english": "It is green. I can count to ten.", "chinese": "绿色。我能数到十。"},
        {"speaker": 0, "english": "You are doing great!", "chinese": "你做得很好！"},
    ],
    "z_u17": [
        {"speaker": 0, "english": "Good morning, Amy!", "chinese": "早上好，艾米！"},
        {"speaker": 1, "english": "Good morning! This is my friend Ben.", "chinese": "早上好！这是我的朋友本。"},
        {"speaker": 0, "english": "Nice to meet you, Ben.", "chinese": "本，很高兴认识你。"},
    ],
    "z_u18": [
        {"speaker": 0, "english": "What is your name?", "chinese": "你叫什么名字？"},
        {"speaker": 1, "english": "My name is Leo. I am ten years old.", "chinese": "我叫里奥。我十岁。"},
        {"speaker": 0, "english": "I am Mia. Nice to meet you.", "chinese": "我是米娅。很高兴认识你。"},
    ],
    "z_u19": [
        {"speaker": 0, "english": "I have two pencils.", "chinese": "我有两支铅笔。"},
        {"speaker": 1, "english": "I have many books on my desk.", "chinese": "我桌上有很多书。"},
        {"speaker": 0, "english": "How many bags do you have?", "chinese": "你有几个包？"},
    ],
    "z_u20": [
        {"speaker": 0, "english": "This box is big. That one is small.", "chinese": "这个盒子很大。那个很小。"},
        {"speaker": 1, "english": "Is the ball round?", "chinese": "球是圆的吗？"},
        {"speaker": 0, "english": "Yes. The table is square.", "chinese": "是的。桌子是方的。"},
    ],
    "z_u21": [
        {"speaker": 0, "english": "Where is the kitchen?", "chinese": "厨房在哪里？"},
        {"speaker": 1, "english": "It is next to the living room.", "chinese": "在客厅旁边。"},
        {"speaker": 0, "english": "My bedroom is upstairs.", "chinese": "我的卧室在楼上。"},
    ],
    "z_u22": [
        {"speaker": 0, "english": "Please put the toys away.", "chinese": "请把玩具收好。"},
        {"speaker": 1, "english": "I will clean my desk now.", "chinese": "我现在就打扫书桌。"},
        {"speaker": 0, "english": "Good. Keep the room tidy.", "chinese": "很好。保持房间整洁。"},
    ],
    "z_u23": [
        {"speaker": 0, "english": "What day is it today?", "chinese": "今天星期几？"},
        {"speaker": 1, "english": "Today is Monday. School starts at eight.", "chinese": "今天星期一。八点上课。"},
        {"speaker": 0, "english": "See you on Friday!", "chinese": "星期五见！"},
    ],
    "z_u24": [
        {"speaker": 0, "english": "I get up early every day.", "chinese": "我每天早起。"},
        {"speaker": 1, "english": "I brush my teeth after breakfast.", "chinese": "早饭后我刷牙。"},
        {"speaker": 0, "english": "Good habits help a lot.", "chinese": "好习惯很有帮助。"},
    ],
    "z_u25": [
        {"speaker": 0, "english": "Do you like apples or bananas?", "chinese": "你喜欢苹果还是香蕉？"},
        {"speaker": 1, "english": "I like apples. What about you?", "chinese": "我喜欢苹果。你呢？"},
        {"speaker": 0, "english": "I like both!", "chinese": "我都喜欢！"},
    ],
    "z_u26": [
        {"speaker": 0, "english": "Can I be your friend?", "chinese": "我能做你的朋友吗？"},
        {"speaker": 1, "english": "Yes! Let's play together.", "chinese": "可以！我们一起玩吧。"},
        {"speaker": 0, "english": "Friends help each other.", "chinese": "朋友互相帮助。"},
    ],
    "z_u27": [
        {"speaker": 0, "english": "Can you run fast?", "chinese": "你能跑得很快吗？"},
        {"speaker": 1, "english": "I can jump and swim.", "chinese": "我能跳，也能游泳。"},
        {"speaker": 0, "english": "Let's play ball outside.", "chinese": "我们去外面打球吧。"},
    ],
    "z_u28": [
        {"speaker": 0, "english": "It is raining. Take an umbrella.", "chinese": "下雨了。带把伞。"},
        {"speaker": 1, "english": "Summer is hot. Winter is cold.", "chinese": "夏天热。冬天冷。"},
        {"speaker": 0, "english": "I like spring best.", "chinese": "我最喜欢春天。"},
    ],
    "z_u29": [
        {"speaker": 0, "english": "The park is near my home.", "chinese": "公园在我家附近。"},
        {"speaker": 1, "english": "Let's go to the library later.", "chinese": "我们晚点去图书馆吧。"},
        {"speaker": 0, "english": "The neighbors are kind.", "chinese": "邻居们很友善。"},
    ],
    "z_u30": [
        {"speaker": 0, "english": "How much is this notebook?", "chinese": "这本笔记本多少钱？"},
        {"speaker": 1, "english": "Ten yuan. Do you want the blue bag too?", "chinese": "十元。你也想要蓝色的包吗？"},
        {"speaker": 0, "english": "Yes. I will take it. Thank you!", "chinese": "要。我买了。谢谢！"},
    ],
    "z_u31": [
        {"speaker": 0, "english": "I feel tired today.", "chinese": "我今天觉得累。"},
        {"speaker": 1, "english": "You should see a doctor if you feel worse.", "chinese": "如果更难受，你应该去看医生。"},
        {"speaker": 0, "english": "I will rest and drink water.", "chinese": "我会休息，再喝点水。"},
    ],
    "z_u32": [
        {"speaker": 0, "english": "I will read one page today.", "chinese": "我今天会读一页。"},
        {"speaker": 1, "english": "What does this word mean?", "chinese": "这个词是什么意思？"},
        {"speaker": 0, "english": "I will practice again tomorrow.", "chinese": "我明天会再练习。"},
    ],
    "z_u33": [
        {"speaker": 0, "english": "Happy birthday! This gift is for you.", "chinese": "生日快乐！这是给你的礼物。"},
        {"speaker": 1, "english": "Thank you! Let us cut the cake.", "chinese": "谢谢！我们来切蛋糕吧。"},
        {"speaker": 0, "english": "Make a wish!", "chinese": "许个愿望！"},
    ],
    "z_u34": [
        {"speaker": 0, "english": "Be careful when you cross the road.", "chinese": "过马路要小心。"},
        {"speaker": 1, "english": "I will. Please help me if I get lost.", "chinese": "我会的。如果我迷路了请帮帮我。"},
        {"speaker": 0, "english": "Safety comes first.", "chinese": "安全第一。"},
    ],
}


def main() -> None:
    data = json.loads(SRC.read_text(encoding="utf-8"))
    added = 0
    for key, lines in NEW.items():
        if key in data and isinstance(data[key], list) and len(data[key]) == 3:
            continue
        data[key] = lines
        added += 1
        print(f"set {key}")
    SRC.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"DONE added_or_updated={added} total_keys={len(data)}")


if __name__ == "__main__":
    main()
