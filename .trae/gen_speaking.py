# 为每课追加 e9 跟读题（speaking）：目标句取该课 e2（句对 1）的英文句子。
# 幂等：已有 e9 的课跳过。写回 ensure_ascii=True, indent=2。
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COURSE_FILES = (
    ROOT / "assets" / "courses" / "course_beginner.json",
    ROOT / "assets" / "courses" / "course_zero.json",
)

for src in COURSE_FILES:
    if not src.exists():
        print(f"skip missing {src}")
        continue
    with open(src, encoding="utf-8") as f:
        data = json.load(f)

    added = 0
    for u in data["units"]:
        for l in u["lessons"]:
            exercises = l["exercises"]
            if any(e["id"] == f"{l['id']}e9" for e in exercises):
                continue
            e2 = next(e for e in exercises if e["id"] == f"{l['id']}e2")
            exercises.append(
                {
                    "id": f"{l['id']}e9",
                    "type": "speaking",
                    "prompt": e2["answer"],
                    "sentence": e2["sentence"],
                    "options": [],
                    "answer": e2["sentence"],
                }
            )
            added += 1

    with open(src, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=True, indent=2)

    total = sum(len(l["exercises"]) for u in data["units"] for l in u["lessons"])
    print(f"{src.name}: added {added} speaking exercises, total = {total}")
