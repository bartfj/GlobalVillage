# -*- coding: utf-8 -*-
"""幂等补齐 unit_dialogues.json：初级 u35–u44。"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "dialogues" / "unit_dialogues.json"

NEW = {
    "u35": [
        {"speaker": 0, "english": "What time does the meeting start?", "chinese": "会议几点开始？"},
        {"speaker": 1, "english": "At three. Could you take a look at this report?", "chinese": "三点。你能看一下这份报告吗？"},
        {"speaker": 0, "english": "Sure. I will send you my feedback today.", "chinese": "当然。我今天会把反馈发给你。"},
    ],
    "u36": [
        {"speaker": 0, "english": "Are you free on Wednesday afternoon?", "chinese": "你周三下午有空吗？"},
        {"speaker": 1, "english": "Yes. Please send me an email with the details.", "chinese": "有。请把细节发邮件给我。"},
        {"speaker": 0, "english": "Done. Looking forward to your reply.", "chinese": "发好了。期待你的回复。"},
    ],
    "u37": [
        {"speaker": 0, "english": "Do you have a table for two?", "chinese": "请问有两人桌吗？"},
        {"speaker": 1, "english": "Yes. Are you ready to order?", "chinese": "有。你们准备好点餐了吗？"},
        {"speaker": 0, "english": "Not too spicy, please. And bring the bill later.", "chinese": "请不要太辣。稍后请把账单拿来。"},
    ],
    "u38": [
        {"speaker": 0, "english": "Is this apartment still for rent?", "chinese": "这套房子还在租吗？"},
        {"speaker": 1, "english": "Yes. The rent is eight thousand a month.", "chinese": "是的。房租一个月八千。"},
        {"speaker": 0, "english": "Great. When can I move in?", "chinese": "太好了。什么时候可以入住？"},
    ],
    "u39": [
        {"speaker": 0, "english": "Please help me connect to Wi-Fi.", "chinese": "请帮我连上无线网。"},
        {"speaker": 1, "english": "Sure. Do not share your password with strangers.", "chinese": "好。不要把密码告诉陌生人。"},
        {"speaker": 0, "english": "Got it. I will turn on two-factor authentication.", "chinese": "明白。我会开启两步验证。"},
    ],
    "u40": [
        {"speaker": 0, "english": "Shall we go to the gym today?", "chinese": "今天去健身房吗？"},
        {"speaker": 1, "english": "Yes. Warming up is important first.", "chinese": "好。先热身很重要。"},
        {"speaker": 0, "english": "Agreed. Do not push yourself too hard.", "chinese": "同意。不要勉强自己。"},
    ],
    "u41": [
        {"speaker": 0, "english": "Please knock before you enter.", "chinese": "进门前请先敲门。"},
        {"speaker": 1, "english": "Okay. Should I take off my shoes here?", "chinese": "好。这里要脱鞋吗？"},
        {"speaker": 0, "english": "Yes. Please respect local customs.", "chinese": "要的。请尊重当地习惯。"},
    ],
    "u42": [
        {"speaker": 0, "english": "Someone is hurt. Please call an ambulance.", "chinese": "有人受伤了。请叫救护车。"},
        {"speaker": 1, "english": "I will. Stay calm and tell me your location.", "chinese": "我会的。保持冷静，告诉我你的位置。"},
        {"speaker": 0, "english": "We are near the park gate.", "chinese": "我们在公园门口附近。"},
    ],
    "u43": [
        {"speaker": 0, "english": "Please sort the trash before you leave.", "chinese": "离开前请把垃圾分类。"},
        {"speaker": 1, "english": "Sure. Plastic bottles can be recycled.", "chinese": "好。塑料瓶可以回收。"},
        {"speaker": 0, "english": "And turn off the lights. Save energy.", "chinese": "还有，请关灯。节约能源。"},
    ],
    "u44": [
        {"speaker": 0, "english": "Are you free this weekend? Let us study English together.", "chinese": "这个周末你有空吗？我们一起学英语吧。"},
        {"speaker": 1, "english": "Sounds good. Could you explain a bit more slowly?", "chinese": "听起来不错。你能解释得慢一点吗？"},
        {"speaker": 0, "english": "Of course. Now you understand — great!", "chinese": "当然。现在你明白了——太好了！"},
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
