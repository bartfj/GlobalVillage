# -*- coding: utf-8 -*-
"""生成 u11-u14 四个单元（16 课 × 8 题）追加到 course_beginner.json。"""
import sys
sys.path.insert(0, r'd:\workspace\github_code\地球村\.trae')
from gen_units7to10 import append_units

UNITS = [
    {
        'id': 'u11', 'title': '工作与学习',
        'description': '学习谈论职业、学校生活与学科的表达。',
        'lessons': [
            ('职业', [
                ('她是一名老师。', 'She is a teacher.'),
                ('我的爸爸是医生。', 'My father is a doctor.'),
                ('他想成为一名警察。', 'He wants to be a policeman.'),
                ('我的妈妈是护士。', 'My mother is a nurse.'),
                ('他的哥哥是工程师。', 'His brother is an engineer.'),
                ('我想成为科学家。', 'I want to be a scientist.'),
            ]),
            ('学校生活', [
                ('我七点起床。', 'I get up at seven.'),
                ('学校八点上课。', 'School starts at eight.'),
                ('我们上午有四节课。', 'We have four classes in the morning.'),
                ('我在学校吃午饭。', 'I have lunch at school.'),
                ('学校四点放学。', 'School ends at four.'),
                ('我放学后做作业。', 'I do my homework after school.'),
            ]),
            ('学科', [
                ('我最喜欢的科目是英语。', 'My favorite subject is English.'),
                ('数学对我来说很难。', 'Math is difficult for me.'),
                ('我们周五有音乐课。', 'We have music on Friday.'),
                ('我很喜欢体育课。', 'I like P.E. very much.'),
                ('历史很有趣。', 'History is interesting.'),
                ('我们每天学习语文。', 'We study Chinese every day.'),
            ]),
            ('考试与成绩', [
                ('考试在下周一。', 'The exam is next Monday.'),
                ('我取得了好成绩。', 'I got a good grade.'),
                ('请复习你的功课。', 'Please review your lessons.'),
                ('不要担心考试。', 'Do not worry about the exam.'),
                ('她通过了测试。', 'She passed the test.'),
                ('熟能生巧。', 'Practice makes perfect.'),
            ]),
        ],
    },
    {
        'id': 'u12', 'title': '爱好与娱乐',
        'description': '学习谈论爱好、电影与音乐的表达。',
        'lessons': [
            ('爱好', [
                ('我喜欢读书。', 'I like reading books.'),
                ('他收集旧硬币。', 'He collects old coins.'),
                ('她擅长画画。', 'She is good at drawing.'),
                ('我喜欢下棋。', 'I enjoy playing chess.'),
                ('我的爱好是拍照。', 'My hobby is taking photos.'),
                ('我们爱去远足。', 'We love going hiking.'),
            ]),
            ('电影', [
                ('我们去看电影吧。', 'Let us go to the movies.'),
                ('这部电影很刺激。', 'This movie is very exciting.'),
                ('我喜欢动作片。', 'I like action movies.'),
                ('她看悲伤的电影哭了。', 'She cried at the sad movie.'),
                ('票卖完了。', 'The tickets are sold out.'),
                ('电影七点开始。', 'The movie starts at seven.'),
            ]),
            ('音乐', [
                ('我每天听音乐。', 'I listen to music every day.'),
                ('她钢琴弹得好。', 'She plays the piano well.'),
                ('这首歌很流行。', 'This song is very popular.'),
                ('我喜欢流行音乐。', 'I like pop music.'),
                ('他在乐队里唱歌。', 'He sings in a band.'),
                ('音乐让我快乐。', 'Music makes me happy.'),
            ]),
            ('看比赛', [
                ('你昨晚看比赛了吗？', 'Did you watch the game last night?'),
                ('我们队赢了比赛。', 'Our team won the match.'),
                ('比分是二比一。', 'The score was two to one.'),
                ('他是一名著名球员。', 'He is a famous player.'),
                ('我为我们队加油。', 'I cheer for my team.'),
                ('比赛非常接近。', 'The game was very close.'),
            ]),
        ],
    },
    {
        'id': 'u13', 'title': '社交与朋友',
        'description': '学习邀请、道歉与祝贺的表达。',
        'lessons': [
            ('邀请', [
                ('你想来我的派对吗？', 'Would you like to come to my party?'),
                ('谢谢你的邀请。', 'Thanks for inviting me.'),
                ('我很乐意来。', 'I would love to come.'),
                ('抱歉，我那天很忙。', 'Sorry, I am busy that day.'),
                ('你周六能来吗？', 'Can you come on Saturday?'),
                ('派对上见。', 'See you at the party.'),
            ]),
            ('道歉', [
                ('对不起我迟到了。', 'I am sorry I am late.'),
                ('没关系。', 'It does not matter.'),
                ('请原谅我。', 'Please forgive me.'),
                ('我不是故意伤害你。', 'I did not mean to hurt you.'),
                ('那是我的错。', 'It was my mistake.'),
                ('别放在心上。', 'Do not worry about it.'),
            ]),
            ('祝贺', [
                ('祝你生日快乐！', 'Happy birthday to you!'),
                ('祝贺你找到新工作。', 'Congratulations on your new job.'),
                ('干得好！', 'Well done!'),
                ('我为你骄傲。', 'I am so proud of you.'),
                ('祝你考试顺利。', 'Good luck with your exam.'),
                ('这是你应得的。', 'You deserve it.'),
            ]),
            ('打电话', [
                ('我可以和汤姆通话吗？', 'May I speak to Tom?'),
                ('我就是汤姆。', 'This is Tom speaking.'),
                ('我可以帮你带个口信吗？', 'Can I take a message?'),
                ('我稍后给你回电话。', 'I will call you back later.'),
                ('请稍等。', 'Please hold on a moment.'),
                ('我的手机没电了。', 'My phone is out of battery.'),
            ]),
        ],
    },
    {
        'id': 'u14', 'title': '旅行与文化',
        'description': '学习节日、观光与文化体验的表达。',
        'lessons': [
            ('节日', [
                ('圣诞节在十二月。', 'Christmas is in December.'),
                ('中秋节我们吃月饼。', 'We eat mooncakes at Mid-Autumn Festival.'),
                ('春节是最大的节日。', 'Spring Festival is the biggest holiday.'),
                ('我今年收到了红包。', 'I got red packets this year.'),
                ('我们看龙舟比赛。', 'We watch dragon boat races.'),
                ('北方人吃饺子。', 'People eat dumplings in the north.'),
            ]),
            ('观光', [
                ('长城很壮观。', 'The Great Wall is amazing.'),
                ('我们在湖上划船。', 'We took a boat on the lake.'),
                ('山顶的风景很美。', 'The view from the top is beautiful.'),
                ('我买了一些纪念品。', 'I bought some souvenirs.'),
                ('博物馆周日免费。', 'The museum is free on Sundays.'),
                ('别忘了带相机。', 'Do not forget your camera.'),
            ]),
            ('饮食文化', [
                ('我爱中国菜。', 'I love Chinese food.'),
                ('这道菜有点辣。', 'This dish is a little spicy.'),
                ('尝尝当地小吃。', 'Try some local snacks.'),
                ('面条很好吃。', 'The noodles taste great.'),
                ('茶在中国很流行。', 'Tea is popular in China.'),
                ('我们用筷子吃饭。', 'We use chopsticks to eat.'),
            ]),
            ('问路与求助', [
                ('打扰一下，酒店在哪里？', 'Excuse me, where is the hotel?'),
                ('你能帮我吗？', 'Could you help me, please?'),
                ('我迷路了。', 'I am lost.'),
                ('这附近有银行吗？', 'Is there a bank near here?'),
                ('走路要多久？', 'How long does it take to walk?'),
                ('谢谢你的帮助。', 'Thank you for your help.'),
            ]),
        ],
    },
]

if __name__ == '__main__':
    append_units(UNITS)
