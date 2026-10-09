# -*- coding: utf-8 -*-
"""生成初级 u33-u34 两个单元，追加到 course_beginner.json。"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_units7to10 import append_units

UNITS = [
    {
        "id": "u33",
        "title": "问题解决与道歉",
        "description": "学习道歉、投诉与解决问题的礼貌表达。",
        "lessons": [
            (
                "道歉致歉",
                [
                    ("对不起，我迟到了。", "I am sorry I am late."),
                    ("这是我的错。", "That was my fault."),
                    ("请原谅我。", "Please forgive me."),
                    ("我不是故意的。", "I did not mean to do that."),
                    ("希望你能接受我的道歉。", "I hope you can accept my apology."),
                    ("下次我会更小心。", "I will be more careful next time."),
                ],
            ),
            (
                "说明问题",
                [
                    ("出了一点问题。", "There is a small problem."),
                    ("这个软件坏了。", "This software is broken."),
                    ("我找不到我的钥匙。", "I cannot find my keys."),
                    ("网络速度太慢了。", "The internet is too slow."),
                    ("房间里没有热水。", "There is no hot water in the room."),
                    ("订单送错了。", "The order was delivered wrongly."),
                ],
            ),
            (
                "投诉与请求",
                [
                    ("我想投诉。", "I would like to make a complaint."),
                    ("你能帮我解决吗？", "Can you help me fix this?"),
                    ("请再检查一次。", "Please check it again."),
                    ("我需要退款。", "I need a refund."),
                    ("请尽快处理。", "Please deal with it as soon as possible."),
                    ("谢谢你的帮助。", "Thank you for your help."),
                ],
            ),
            (
                "达成解决",
                [
                    ("问题已经解决了。", "The problem has been solved."),
                    ("这样就好多了。", "That is much better."),
                    ("我们达成了一致。", "We reached an agreement."),
                    ("下次我们提前沟通。", "Next time we will talk earlier."),
                    ("我很高兴我们解决了它。", "I am glad we fixed it."),
                    ("让我们重新开始吧。", "Let us start over."),
                ],
            ),
        ],
    },
    {
        "id": "u34",
        "title": "未来与梦想",
        "description": "谈论未来计划、梦想与持续学习。",
        "lessons": [
            (
                "未来计划",
                [
                    ("明年我要学开车。", "I will learn to drive next year."),
                    ("我打算去读研究生。", "I plan to go to graduate school."),
                    ("五年后我想换工作。", "I want to change jobs in five years."),
                    ("我们会搬到新城市。", "We will move to a new city."),
                    ("周末我要开始这个项目。", "I will start this project this weekend."),
                    ("我的计划是每天练习。", "My plan is to practice every day."),
                ],
            ),
            (
                "梦想目标",
                [
                    ("我的梦想是环游世界。", "My dream is to travel around the world."),
                    ("她想成为一名老师。", "She wants to become a teacher."),
                    ("他梦想开一家咖啡馆。", "He dreams of opening a cafe."),
                    ("我希望帮助更多人。", "I hope to help more people."),
                    ("坚持梦想很重要。", "It is important to keep your dream."),
                    ("一步一步靠近目标。", "Move toward your goal step by step."),
                ],
            ),
            (
                "准备行动",
                [
                    ("我正在存钱。", "I am saving money."),
                    ("我报名了一个课程。", "I signed up for a course."),
                    ("我需要更多练习。", "I need more practice."),
                    ("先制定一个小计划。", "First make a small plan."),
                    ("我每天进步一点点。", "I improve a little every day."),
                    ("准备好了就开始。", "Start when you are ready."),
                ],
            ),
            (
                "鼓励前行",
                [
                    ("你可以做到。", "You can do it."),
                    ("不要放弃。", "Do not give up."),
                    ("失败是学习的一部分。", "Failure is part of learning."),
                    ("相信你自己。", "Believe in yourself."),
                    ("今天的努力会有回报。", "Today's effort will pay off."),
                    ("未来掌握在你手中。", "The future is in your hands."),
                ],
            ),
        ],
    },
]

if __name__ == "__main__":
    append_units(UNITS)
