#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Replace each lesson's e3 translateChoice with a matchPairs exercise."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COURSES = ROOT / "assets" / "courses"
CJK = re.compile(r"[\u4e00-\u9fff]")


def _is_cjk(text: str) -> bool:
    return bool(CJK.search(text))


def _add(
    pairs: list[tuple[str, str]],
    seen_zh: set[str],
    seen_en: set[str],
    zh: str,
    en: str,
) -> None:
    zh = zh.strip()
    en = en.strip()
    if not zh or not en:
        return
    zh_key = zh.rstrip("。！？")
    en_key = en.rstrip(".!?").lower()
    if zh_key in seen_zh or en_key in seen_en:
        return
    seen_zh.add(zh_key)
    seen_en.add(en_key)
    pairs.append((zh, en))


def collect_pairs(exercises: list[dict]) -> list[tuple[str, str]]:
    pairs: list[tuple[str, str]] = []
    seen_zh: set[str] = set()
    seen_en: set[str] = set()
    for ex in exercises:
        kind = ex["type"]
        prompt = str(ex.get("prompt") or "")
        sentence = str(ex.get("sentence") or "")
        answer = str(ex.get("answer") or "")
        if kind == "matchPairs":
            for pair in ex.get("pairs") or []:
                _add(pairs, seen_zh, seen_en, pair["left"], pair["right"])
        elif kind == "translateChoice":
            if _is_cjk(prompt):
                _add(pairs, seen_zh, seen_en, prompt, sentence or answer)
            else:
                _add(pairs, seen_zh, seen_en, answer, sentence or prompt)
        elif kind in ("wordBank", "speaking"):
            _add(pairs, seen_zh, seen_en, prompt, sentence)
        elif kind == "listeningChoice":
            _add(pairs, seen_zh, seen_en, answer, sentence)
        elif kind == "fillBlank":
            zh = prompt.split("：", 1)[-1] if "：" in prompt else prompt
            _add(pairs, seen_zh, seen_en, zh, sentence)
    if len(pairs) < 4:
        raise ValueError(f"Need 4 pairs, got {len(pairs)}")
    return pairs[:4]


def match_answer(pairs: list[tuple[str, str]]) -> str:
    ordered = sorted(pairs, key=lambda item: item[0])
    return "|".join(f"{zh}={en}" for zh, en in ordered)


def convert_lesson(lesson: dict) -> None:
    exercises = lesson["exercises"]
    pairs = collect_pairs(exercises)
    target = None
    for ex in exercises:
        if str(ex.get("id", "")).endswith("e3"):
            target = ex
            break
    if target is None:
        raise ValueError(f"Missing e3 in {lesson['id']}")
    target.clear()
    target.update(
        {
            "id": f"{lesson['id']}e3",
            "type": "matchPairs",
            "prompt": "把中文和英文连起来",
            "sentence": pairs[0][1],
            "options": [],
            "answer": match_answer(pairs),
            "sentenceWithBlank": None,
            "pairs": [{"left": zh, "right": en} for zh, en in pairs],
        }
    )


def convert_file(path: Path) -> None:
    data = json.loads(path.read_text(encoding="utf-8"))
    lessons = [lesson for unit in data["units"] for lesson in unit["lessons"]]
    for lesson in lessons:
        convert_lesson(lesson)
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"{path.name}: converted {len(lessons)} lessons")


def main() -> None:
    convert_file(COURSES / "course_beginner.json")
    convert_file(COURSES / "course_zero.json")


if __name__ == "__main__":
    main()
