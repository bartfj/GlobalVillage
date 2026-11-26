# -*- coding: utf-8 -*-
"""生成零基础 z_u33-z_u34 两个单元，追加到 course_zero.json。"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_units7to10 import ROOT, append_units

UNITS = [
    {
        "id": "z_u33",
        "title": "节日与庆祝",
        "description": "学习节日问候与简单庆祝表达。",
        "lessons": [
            (
                "生日祝福",
                [
                    ("生日快乐！", "Happy birthday!"),
                    ("这是给你的礼物。", "This gift is for you."),
                    ("我们来切蛋糕吧。", "Let us cut the cake."),
                    ("许个愿望。", "Make a wish."),
                    ("我很开心。", "I am very happy."),
                    ("谢谢你来参加。", "Thank you for coming."),
                ],
            ),
            (
                "节日问候",
                [
                    ("新年快乐！", "Happy New Year!"),
                    ("节日快乐！", "Happy holiday!"),
                    ("春节快乐！", "Happy Spring Festival!"),
                    ("圣诞快乐！", "Merry Christmas!"),
                    ("祝你一切顺利。", "I wish you all the best."),
                    ("我们一起庆祝吧。", "Let us celebrate together."),
                ],
            ),
            (
                "聚会准备",
                [
                    ("请带一些水果。", "Please bring some fruit."),
                    ("聚会在晚上七点。", "The party is at seven."),
                    ("我来装饰房间。", "I will decorate the room."),
                    ("我们需要更多椅子。", "We need more chairs."),
                    ("音乐准备好了吗？", "Is the music ready?"),
                    ("大家都到了。", "Everyone is here."),
                ],
            ),
            (
                "感谢分享",
                [
                    ("今天很有趣。", "Today was fun."),
                    ("谢谢你的邀请。", "Thank you for the invitation."),
                    ("我玩得很开心。", "I had a great time."),
                    ("下次再见。", "See you next time."),
                    ("记得分享照片。", "Remember to share the photos."),
                    ("我们很快再聚。", "We will meet again soon."),
                ],
            ),
        ],
    },
    {
        "id": "z_u34",
        "title": "安全与提醒",
        "description": "学习安全提醒与简单求助表达。",
        "lessons": [
            (
                "出行安全",
                [
                    ("过马路要小心。", "Be careful when you cross the road."),
                    ("红灯请停下。", "Please stop at the red light."),
                    ("系好安全带。", "Fasten your seat belt."),
                    ("不要跑太快。", "Do not run too fast."),
                    ("握住我的手。", "Hold my hand."),
                    ("跟着老师走。", "Follow the teacher."),
                ],
            ),
            (
                "居家提醒",
                [
                    ("出门请关门。", "Please close the door when you leave."),
                    ("不要玩火。", "Do not play with fire."),
                    ("先洗手再吃饭。", "Wash your hands before eating."),
                    ("晚上早点睡觉。", "Go to bed early at night."),
                    ("把玩具收好。", "Put the toys away."),
                    ("保持房间整洁。", "Keep the room tidy."),
                ],
            ),
            (
                "寻求帮助",
                [
                    ("请帮帮我。", "Please help me."),
                    ("我迷路了。", "I am lost."),
                    ("我需要帮助。", "I need help."),
                    ("你可以打电话吗？", "Can you make a phone call?"),
                    ("请问警察在哪里？", "Where is the police station?"),
                    ("谢谢你的帮助。", "Thank you for your help."),
                ],
            ),
            (
                "保护自己",
                [
                    ("陌生人不要跟。", "Do not follow strangers."),
                    ("有事告诉家长。", "Tell your parents if something happens."),
                    ("记住自己的名字。", "Remember your own name."),
                    ("保护好你的包。", "Keep your bag safe."),
                    ("有危险就大声说。", "Speak up if there is danger."),
                    ("安全第一。", "Safety comes first."),
                ],
            ),
        ],
    },
]

if __name__ == "__main__":
    append_units(UNITS, course_path=ROOT / "assets" / "courses" / "course_zero.json")
