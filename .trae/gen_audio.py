"""为课程 listeningChoice / speaking 题幂等生成内置 mp3（edge-tts Jenny）。"""

from __future__ import annotations

import asyncio
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / ".trae" / "sdk" / "pylibs"))

import edge_tts  # noqa: E402

COURSE_FILES = (
    ROOT / "assets" / "courses" / "course_beginner.json",
    ROOT / "assets" / "courses" / "course_zero.json",
)
OUTPUT = ROOT / "assets" / "audio" / "listening"
VOICE = "en-US-JennyNeural"
RATE = "-20%"


def collect_items() -> list[tuple[str, str]]:
    items: list[tuple[str, str]] = []
    seen: set[str] = set()
    for course_path in COURSE_FILES:
        if not course_path.exists():
            print(f"skip missing course: {course_path}", flush=True)
            continue
        data = json.loads(course_path.read_text(encoding="utf-8"))
        for unit in data["units"]:
            for lesson in unit["lessons"]:
                for exercise in lesson["exercises"]:
                    if exercise.get("type") not in ("listeningChoice", "speaking"):
                        continue
                    eid = exercise["id"]
                    if eid in seen:
                        continue
                    seen.add(eid)
                    items.append((eid, exercise["sentence"]))
    return items


async def generate_one(eid: str, text: str) -> bool:
    path = OUTPUT / f"{eid}.mp3"
    if path.exists() and path.stat().st_size > 0:
        return True
    for attempt in range(3):
        try:
            await edge_tts.Communicate(text, VOICE, rate=RATE).save(str(path))
            if path.exists() and path.stat().st_size > 0:
                return True
        except Exception as error:
            path.unlink(missing_ok=True)
            if attempt == 2:
                print(f"fail {eid}: {error}", flush=True)
            else:
                await asyncio.sleep(2)
    return False


async def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    items = collect_items()
    ok = 0
    for eid, text in items:
        if await generate_one(eid, text):
            ok += 1
            print(f"ok {eid}", flush=True)
    print(f"DONE {ok}/{len(items)}", flush=True)
    if ok != len(items):
        raise SystemExit(1)


if __name__ == "__main__":
    asyncio.run(main())
