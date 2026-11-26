# -*- coding: utf-8 -*-
"""生成初级 u35-u44 十个单元，追加到 course_beginner.json。"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_units7to10 import append_units

UNITS = [
    {
        "id": "u35",
        "title": "职场沟通",
        "description": "学习开会、汇报与同事协作的职场表达。",
        "lessons": [
            (
                "开会发言",
                [
                    ("会议几点开始？", "What time does the meeting start?"),
                    ("请大家发表意见。", "Please share your opinions."),
                    ("我同意这个计划。", "I agree with this plan."),
                    ("我们需要更多细节。", "We need more details."),
                    ("让我们逐项讨论。", "Let us discuss it point by point."),
                    ("今天的会议到此结束。", "That is all for today's meeting."),
                ],
            ),
            (
                "汇报进度",
                [
                    ("项目进展顺利。", "The project is going well."),
                    ("我已经完成了报告。", "I have finished the report."),
                    ("还需要两天时间。", "It will take two more days."),
                    ("主要问题是预算。", "The main problem is the budget."),
                    ("下周我会更新进度。", "I will update the progress next week."),
                    ("请审阅这份文件。", "Please review this document."),
                ],
            ),
            (
                "同事协作",
                [
                    ("你能帮我看一下吗？", "Could you take a look at this?"),
                    ("我们一起完成这个任务。", "Let us finish this task together."),
                    ("我会把文件发给你。", "I will send you the file."),
                    ("请在周五之前回复。", "Please reply before Friday."),
                    ("谢谢你的支持。", "Thank you for your support."),
                    ("很高兴和你合作。", "I am glad to work with you."),
                ],
            ),
            (
                "礼貌请求",
                [
                    ("请问现在方便吗？", "Is now a good time?"),
                    ("我想约你谈五分钟。", "I would like five minutes with you."),
                    ("可以推迟到明天吗？", "Can we put it off until tomorrow?"),
                    ("请把截止日期告诉我。", "Please tell me the deadline."),
                    ("我会尽快处理。", "I will handle it as soon as possible."),
                    ("感谢你的理解。", "Thank you for your understanding."),
                ],
            ),
        ],
    },
    {
        "id": "u36",
        "title": "邮件与预约",
        "description": "学习写邮件、预约时间与确认安排。",
        "lessons": [
            (
                "写邮件",
                [
                    ("我想给你发一封邮件。", "I would like to send you an email."),
                    ("主题是下周的会议。", "The subject is next week's meeting."),
                    ("请查收附件。", "Please find the attachment."),
                    ("期待你的回复。", "I look forward to your reply."),
                    ("如有问题请告诉我。", "Please let me know if you have questions."),
                    ("祝好。", "Best regards."),
                ],
            ),
            (
                "预约时间",
                [
                    ("我想预约明天下午。", "I would like to book tomorrow afternoon."),
                    ("你周三有空吗？", "Are you free on Wednesday?"),
                    ("三点可以吗？", "Is three o'clock okay?"),
                    ("我们改到周四吧。", "Let us change it to Thursday."),
                    ("请确认预约时间。", "Please confirm the appointment time."),
                    ("我已经加到日历里了。", "I have added it to my calendar."),
                ],
            ),
            (
                "确认与取消",
                [
                    ("我想确认一下预约。", "I want to confirm the appointment."),
                    ("预约已经确认了。", "The appointment is confirmed."),
                    ("抱歉，我必须取消。", "Sorry, I have to cancel."),
                    ("我们可以改期吗？", "Can we reschedule?"),
                    ("下周一同一时间可以吗？", "Is next Monday at the same time okay?"),
                    ("谢谢你提前通知。", "Thank you for letting me know in advance."),
                ],
            ),
            (
                "跟进沟通",
                [
                    ("你收到我的邮件了吗？", "Did you get my email?"),
                    ("我再发一遍给你。", "I will send it to you again."),
                    ("请尽快确认。", "Please confirm as soon as you can."),
                    ("我已更新了时间。", "I have updated the time."),
                    ("会议链接在邮件里。", "The meeting link is in the email."),
                    ("到时候线上见。", "See you online then."),
                ],
            ),
        ],
    },
    {
        "id": "u37",
        "title": "餐饮点餐",
        "description": "学习点餐、口味偏好与结账表达。",
        "lessons": [
            (
                "入座点餐",
                [
                    ("请问有两人桌吗？", "Do you have a table for two?"),
                    ("我想看一下菜单。", "I would like to see the menu."),
                    ("你们有今日特餐吗？", "Do you have a special today?"),
                    ("我要点一份汤。", "I will have a soup."),
                    ("请再给我一杯水。", "Please bring me another glass of water."),
                    ("我们准备好点餐了。", "We are ready to order."),
                ],
            ),
            (
                "口味偏好",
                [
                    ("不要太辣。", "Not too spicy, please."),
                    ("我对海鲜过敏。", "I am allergic to seafood."),
                    ("可以少放盐吗？", "Can you use less salt?"),
                    ("我喜欢清淡的菜。", "I prefer light dishes."),
                    ("这个可以素食吗？", "Can this be made vegetarian?"),
                    ("请把酱汁放在旁边。", "Please put the sauce on the side."),
                ],
            ),
            (
                "用餐交流",
                [
                    ("这道菜很好吃。", "This dish is delicious."),
                    ("你可以尝尝这个。", "You can try this."),
                    ("我还想再来一份米饭。", "I would like another bowl of rice."),
                    ("服务员，请过来一下。", "Waiter, could you come here?"),
                    ("叉子掉了。", "I dropped my fork."),
                    ("请慢用。", "Please enjoy your meal."),
                ],
            ),
            (
                "结账离开",
                [
                    ("请把账单给我。", "Please bring me the bill."),
                    ("我们可以分开付吗？", "Can we split the bill?"),
                    ("我用手机支付。", "I will pay by phone."),
                    ("请开发票。", "Please give me a receipt."),
                    ("服务很好，谢谢。", "The service was great, thank you."),
                    ("我们吃得很开心。", "We enjoyed the meal."),
                ],
            ),
        ],
    },
    {
        "id": "u38",
        "title": "住房与搬家",
        "description": "学习看房、租房与搬家相关表达。",
        "lessons": [
            (
                "看房咨询",
                [
                    ("这套房子还在租吗？", "Is this apartment still for rent?"),
                    ("房租一个月多少钱？", "How much is the rent per month?"),
                    ("水电费包含吗？", "Are utilities included?"),
                    ("附近有地铁站吗？", "Is there a subway station nearby?"),
                    ("我可以看看房间吗？", "May I look at the rooms?"),
                    ("什么时候可以入住？", "When can I move in?"),
                ],
            ),
            (
                "房间设施",
                [
                    ("厨房很干净。", "The kitchen is clean."),
                    ("浴室有热水。", "There is hot water in the bathroom."),
                    ("阳台朝南。", "The balcony faces south."),
                    ("这里有洗衣机吗？", "Is there a washing machine here?"),
                    ("网速够快吗？", "Is the internet fast enough?"),
                    ("家具是全新的。", "The furniture is brand new."),
                ],
            ),
            (
                "签约押金",
                [
                    ("我需要付押金吗？", "Do I need to pay a deposit?"),
                    ("租期是一年。", "The lease is for one year."),
                    ("请给我一份合同。", "Please give me a copy of the contract."),
                    ("我同意这些条款。", "I agree to these terms."),
                    ("押金可以退还吗？", "Is the deposit refundable?"),
                    ("我们下周签合同。", "We will sign the contract next week."),
                ],
            ),
            (
                "搬家安排",
                [
                    ("我下周六搬家。", "I am moving next Saturday."),
                    ("我们需要一辆货车。", "We need a truck."),
                    ("请小心搬这个箱子。", "Please move this box carefully."),
                    ("新地址在公园附近。", "The new address is near the park."),
                    ("钥匙放在桌子上。", "The keys are on the table."),
                    ("欢迎来我的新家。", "Welcome to my new home."),
                ],
            ),
        ],
    },
    {
        "id": "u39",
        "title": "数字生活",
        "description": "学习上网、应用与网络隐私相关表达。",
        "lessons": [
            (
                "上网设备",
                [
                    ("我的手机没电了。", "My phone is out of battery."),
                    ("请帮我连上无线网。", "Please help me connect to Wi-Fi."),
                    ("密码是多少？", "What is the password?"),
                    ("电脑运行很慢。", "The computer is running slowly."),
                    ("请更新这个软件。", "Please update this software."),
                    ("屏幕坏了。", "The screen is broken."),
                ],
            ),
            (
                "应用使用",
                [
                    ("请下载这个应用。", "Please download this app."),
                    ("我忘记密码了。", "I forgot my password."),
                    ("点击这个按钮。", "Tap this button."),
                    ("把照片发给我。", "Send me the photo."),
                    ("视频加载失败了。", "The video failed to load."),
                    ("请分享这个链接。", "Please share this link."),
                ],
            ),
            (
                "网络隐私",
                [
                    ("不要分享个人信息。", "Do not share personal information."),
                    ("请开启两步验证。", "Please turn on two-factor authentication."),
                    ("这条消息可能是诈骗。", "This message may be a scam."),
                    ("定期更换密码。", "Change your password regularly."),
                    ("不要点不明链接。", "Do not click unknown links."),
                    ("保护好你的账号。", "Keep your account safe."),
                ],
            ),
            (
                "线上沟通",
                [
                    ("我们视频通话吧。", "Let us have a video call."),
                    ("你能听到我吗？", "Can you hear me?"),
                    ("请打开摄像头。", "Please turn on your camera."),
                    ("网络有点卡。", "The connection is a bit laggy."),
                    ("我发你一条消息。", "I will send you a message."),
                    ("稍后回复你。", "I will reply later."),
                ],
            ),
        ],
    },
    {
        "id": "u40",
        "title": "运动健身",
        "description": "学习运动计划、健身习惯与身体感受表达。",
        "lessons": [
            (
                "运动计划",
                [
                    ("我每周跑步三次。", "I run three times a week."),
                    ("今天去健身房吗？", "Shall we go to the gym today?"),
                    ("我喜欢打羽毛球。", "I like playing badminton."),
                    ("我们一起游泳吧。", "Let us swim together."),
                    ("热身很重要。", "Warming up is important."),
                    ("我设定了一个健身目标。", "I set a fitness goal."),
                ],
            ),
            (
                "健身动作",
                [
                    ("请做十个俯卧撑。", "Please do ten push-ups."),
                    ("保持背部挺直。", "Keep your back straight."),
                    ("慢慢放下哑铃。", "Put the dumbbell down slowly."),
                    ("休息一分钟。", "Rest for one minute."),
                    ("再做一组。", "Do one more set."),
                    ("动作要标准。", "Keep the form correct."),
                ],
            ),
            (
                "身体感受",
                [
                    ("我有点累。", "I feel a bit tired."),
                    ("腿有点酸。", "My legs are sore."),
                    ("呼吸要均匀。", "Breathe evenly."),
                    ("喝点水吧。", "Have some water."),
                    ("今天状态不错。", "I feel good today."),
                    ("不要强迫自己。", "Do not push yourself too hard."),
                ],
            ),
            (
                "健康习惯",
                [
                    ("早睡早起很重要。", "Going to bed early and getting up early matters."),
                    ("多吃蔬菜。", "Eat more vegetables."),
                    ("少喝含糖饮料。", "Drink fewer sugary drinks."),
                    ("每天走一走。", "Take a walk every day."),
                    ("运动后要拉伸。", "Stretch after exercise."),
                    ("坚持就会看到变化。", "You will see changes if you keep going."),
                ],
            ),
        ],
    },
    {
        "id": "u41",
        "title": "礼仪与文化",
        "description": "学习社交礼仪、节日习俗与文化差异表达。",
        "lessons": [
            (
                "社交礼仪",
                [
                    ("见面时请握手。", "Please shake hands when you meet."),
                    ("进门前先敲门。", "Knock before you enter."),
                    ("请不要大声说话。", "Please do not speak loudly."),
                    ("排队等候。", "Please wait in line."),
                    ("收到礼物要说谢谢。", "Say thank you when you receive a gift."),
                    ("迟到要道歉。", "Apologize if you are late."),
                ],
            ),
            (
                "餐桌礼仪",
                [
                    ("请等主人先动筷。", "Please wait for the host to start."),
                    ("嘴里有食物时不要讲话。", "Do not talk with food in your mouth."),
                    ("请把餐巾放在腿上。", "Please put the napkin on your lap."),
                    ("不要用筷子指人。", "Do not point at people with chopsticks."),
                    ("请把手机收起来。", "Please put your phone away."),
                    ("离开前说声再见。", "Say goodbye before you leave."),
                ],
            ),
            (
                "节日习俗",
                [
                    ("春节我们吃团圆饭。", "We have a reunion dinner at Spring Festival."),
                    ("中秋节看月亮。", "We watch the moon at Mid-Autumn Festival."),
                    ("有些节日要送红包。", "People give red envelopes on some festivals."),
                    ("西方过圣诞节。", "People in the West celebrate Christmas."),
                    ("不同国家习俗不同。", "Customs differ from country to country."),
                    ("了解文化很有趣。", "Learning about culture is interesting."),
                ],
            ),
            (
                "文化差异",
                [
                    ("在这里要脱鞋进门。", "Here you take off your shoes at the door."),
                    ("有些地方拥抱表示友好。", "In some places a hug shows friendliness."),
                    ("请尊重当地习惯。", "Please respect local customs."),
                    ("如果不确定就礼貌询问。", "If you are unsure, ask politely."),
                    ("微笑是通用的礼貌。", "A smile is a universal courtesy."),
                    ("开放的心态很重要。", "An open mind is important."),
                ],
            ),
        ],
    },
    {
        "id": "u42",
        "title": "紧急求助",
        "description": "学习报警、就医与紧急情况下的求助表达。",
        "lessons": [
            (
                "报警求助",
                [
                    ("请马上报警。", "Please call the police right away."),
                    ("这里发生了事故。", "There has been an accident here."),
                    ("有人受伤了。", "Someone is hurt."),
                    ("请告诉我你的位置。", "Please tell me your location."),
                    ("保持冷静。", "Stay calm."),
                    ("救援正在路上。", "Help is on the way."),
                ],
            ),
            (
                "就医表达",
                [
                    ("我需要看医生。", "I need to see a doctor."),
                    ("我发烧了。", "I have a fever."),
                    ("我的头很痛。", "I have a bad headache."),
                    ("请带我去医院。", "Please take me to the hospital."),
                    ("我对我的药过敏。", "I am allergic to my medicine."),
                    ("请叫救护车。", "Please call an ambulance."),
                ],
            ),
            (
                "丢失物品",
                [
                    ("我的钱包丢了。", "I lost my wallet."),
                    ("我找不到护照。", "I cannot find my passport."),
                    ("请帮我报失。", "Please help me report the loss."),
                    ("最后一次看见是在车站。", "I last saw it at the station."),
                    ("里面有我的身份证。", "My ID card is inside."),
                    ("如果找到请联系我。", "Please contact me if you find it."),
                ],
            ),
            (
                "安全提示",
                [
                    ("夜间出门要小心。", "Be careful when you go out at night."),
                    ("不要跟陌生人走。", "Do not go with strangers."),
                    ("看到危险请离开。", "Leave if you see danger."),
                    ("记住紧急电话。", "Remember the emergency number."),
                    ("告诉朋友你的位置。", "Tell a friend where you are."),
                    ("安全第一。", "Safety comes first."),
                ],
            ),
        ],
    },
    {
        "id": "u43",
        "title": "环保生活",
        "description": "学习节约资源、垃圾分类与绿色出行表达。",
        "lessons": [
            (
                "节约资源",
                [
                    ("请随手关灯。", "Please turn off the lights."),
                    ("不要浪费水。", "Do not waste water."),
                    ("夏天把空调调高一点。", "Turn the air conditioner a bit higher in summer."),
                    ("用完电脑请关机。", "Turn off the computer when you finish."),
                    ("少用一次性餐具。", "Use fewer disposable utensils."),
                    ("节约能源人人有责。", "Everyone should save energy."),
                ],
            ),
            (
                "垃圾分类",
                [
                    ("请把垃圾分类。", "Please sort the trash."),
                    ("塑料瓶可以回收。", "Plastic bottles can be recycled."),
                    ("厨余放这个桶。", "Put food waste in this bin."),
                    ("电池要单独处理。", "Batteries need special disposal."),
                    ("不要乱扔垃圾。", "Do not litter."),
                    ("回收能保护环境。", "Recycling protects the environment."),
                ],
            ),
            (
                "绿色出行",
                [
                    ("我骑自行车上班。", "I bike to work."),
                    ("今天坐公交吧。", "Let us take the bus today."),
                    ("短途可以走路。", "You can walk for short trips."),
                    ("少开车更环保。", "Driving less is greener."),
                    ("地铁比开车快。", "The subway is faster than driving."),
                    ("拼车能减少排放。", "Carpooling can cut emissions."),
                ],
            ),
            (
                "爱护自然",
                [
                    ("请爱护树木。", "Please take care of the trees."),
                    ("不要采摘野花。", "Do not pick wild flowers."),
                    ("公园里请安静。", "Please be quiet in the park."),
                    ("我们一起去植树。", "Let us plant trees together."),
                    ("干净的河流很重要。", "Clean rivers are important."),
                    ("保护地球从我做起。", "Protecting the Earth starts with me."),
                ],
            ),
        ],
    },
    {
        "id": "u44",
        "title": "综合表达",
        "description": "综合运用计划、观点、请求与故事讲述。",
        "lessons": [
            (
                "计划安排",
                [
                    ("这个周末你有空吗？", "Are you free this weekend?"),
                    ("我们一起学习英语吧。", "Let us study English together."),
                    ("我打算先完成作业。", "I plan to finish my homework first."),
                    ("三点在咖啡馆见面。", "Meet at the cafe at three."),
                    ("如果下雨我们就改期。", "If it rains, we will reschedule."),
                    ("听起来不错。", "That sounds good."),
                ],
            ),
            (
                "表达观点",
                [
                    ("我认为这个主意很好。", "I think this idea is great."),
                    ("我有不同看法。", "I have a different view."),
                    ("原因是它更方便。", "The reason is that it is more convenient."),
                    ("你说得有道理。", "You have a point."),
                    ("我们再想想吧。", "Let us think about it again."),
                    ("最后我们达成一致。", "In the end we reached an agreement."),
                ],
            ),
            (
                "请求帮助",
                [
                    ("你能帮我一下吗？", "Could you help me for a moment?"),
                    ("请解释得慢一点。", "Please explain a bit more slowly."),
                    ("我不太明白。", "I do not quite understand."),
                    ("可以再说一遍吗？", "Could you say that again?"),
                    ("谢谢你的耐心。", "Thank you for your patience."),
                    ("现在我明白了。", "Now I understand."),
                ],
            ),
            (
                "讲述经历",
                [
                    ("昨天我去了博物馆。", "I went to the museum yesterday."),
                    ("那是难忘的一天。", "It was an unforgettable day."),
                    ("我学到了很多新东西。", "I learned many new things."),
                    ("朋友们也很开心。", "My friends were happy too."),
                    ("我想再去一次。", "I want to go again."),
                    ("下次带你一起去。", "I will take you with me next time."),
                ],
            ),
        ],
    },
]

if __name__ == "__main__":
    append_units(UNITS)
