# -*- coding: utf-8 -*-
"""生成 u15-u16 两个单元（8 课 × 8 题）追加到 course_beginner.json。"""
import sys
sys.path.insert(0, r'd:\workspace\github_code\地球村\.trae')
from gen_units7to10 import append_units

UNITS = [
    {
        'id': 'u15', 'title': '日常生活场景',
        'description': '学习购物、点餐、银行与问路的实用表达。',
        'lessons': [
            ('购物', [
                ('这个多少钱？', 'How much is this?'),
                ('我能试穿这个吗？', 'Can I try this on?'),
                ('有更大号的吗？', 'Do you have a bigger size?'),
                ('我要买这个。', 'I will take this one.'),
                ('这个在打折。', 'This one is on sale.'),
                ('我用手机付款。', 'I pay with my phone.'),
            ]),
            ('点餐', [
                ('我想要一杯咖啡。', 'I would like a cup of coffee.'),
                ('我能看看菜单吗？', 'Can I see the menu?'),
                ('我要鸡肉饭。', 'I will have the chicken rice.'),
                ('请给我账单。', 'May I get the bill, please?'),
                ('这汤很好喝。', 'This soup is delicious.'),
                ('我吃饱了，谢谢。', 'I am full, thank you.'),
            ]),
            ('银行', [
                ('我想换一些钱。', 'I want to exchange some money.'),
                ('取款机在哪里？', 'Where is the ATM?'),
                ('我需要开一个账户。', 'I need to open an account.'),
                ('我的卡不能用了。', 'My card does not work.'),
                ('请在这里签名。', 'Please sign here.'),
                ('银行九点开门。', 'The bank opens at nine.'),
            ]),
            ('问路', [
                ('去图书馆怎么走？', 'How can I get to the library?'),
                ('在拐角处左转。', 'Turn left at the corner.'),
                ('它在公园旁边。', 'It is next to the park.'),
                ('公交车站有多远？', 'How far is the bus stop?'),
                ('你一定能找到。', 'You cannot miss it.'),
                ('让我查一下地图。', 'Let me check the map.'),
            ]),
        ],
    },
    {
        'id': 'u16', 'title': '运动户外与健康',
        'description': '学习谈论运动、户外活动与健康的表达。',
        'lessons': [
            ('运动', [
                ('我每周踢两次足球。', 'I play soccer twice a week.'),
                ('她每天早上跑步。', 'She runs every morning.'),
                ('我们赢了篮球赛。', 'We won the basketball game.'),
                ('我能游得很快。', 'I can swim very fast.'),
                ('锻炼让我更强壮。', 'Exercise keeps me strong.'),
                ('我喜欢骑自行车。', 'I like riding my bike.'),
            ]),
            ('户外活动', [
                ('我们周末去爬山吧。', 'Let us go hiking this weekend.'),
                ('森林里的空气很清新。', 'The air in the forest is fresh.'),
                ('带些水在身上。', 'Bring some water with you.'),
                ('我们搭了一顶帐篷。', 'We set up a tent.'),
                ('小心地上的蛇。', 'Watch out for the snakes.'),
                ('山顶的风景很棒。', 'The view from the top is great.'),
            ]),
            ('健康', [
                ('你应该多喝温水。', 'You should drink more warm water.'),
                ('我今天觉得很累。', 'I feel tired today.'),
                ('他去看医生了。', 'He went to see a doctor.'),
                ('这药一天吃两次。', 'Take this medicine twice a day.'),
                ('早睡早起身体好。', 'Sleep early and get up early.'),
                ('新鲜水果对身体好。', 'Fresh fruit is good for you.'),
            ]),
            ('身体部位', [
                ('我今天头疼。', 'I have a headache today.'),
                ('我的腿有点疼。', 'My leg hurts a little.'),
                ('她喉咙痛。', 'She has a sore throat.'),
                ('经常洗手。', 'Wash your hands often.'),
                ('我的眼睛很干。', 'My eyes feel dry.'),
                ('他的膝盖受伤了。', 'He hurt his knee.'),
            ]),
        ],
    },
]

if __name__ == '__main__':
    append_units(UNITS)
