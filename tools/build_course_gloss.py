#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""从课程 JSON 抽词，用 ECDICT 生成中文释义（assets/phonetics/en_zh.json）。

ECDICT 采用 MIT 许可：https://github.com/skywind3000/ECDICT
只在构建期读取原始 CSV，生成物仅含课程词。
"""
from __future__ import annotations

import csv
import json
import re
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COURSES = ROOT / "assets" / "courses"
OUT = ROOT / "assets" / "phonetics" / "en_zh.json"
CACHE = ROOT / "tools" / ".cache" / "ecdict.csv"
ECDICT_URL = (
    "https://raw.githubusercontent.com/skywind3000/ECDICT/master/ecdict.csv"
)

MAX_GLOSS_CHARS = 40
WEB_PREFIX = "[网络]"


def extract_course_words() -> set[str]:
    words: set[str] = set()
    for path in COURSES.glob("*.json"):
        data = json.loads(path.read_text(encoding="utf-8"))

        def walk(obj):
            if isinstance(obj, str):
                for token in re.findall(r"[A-Za-z']+", obj):
                    w = token.lower()
                    if w and (len(w) > 1 or w in {"a", "i"}):
                        words.add(w)
            elif isinstance(obj, list):
                for item in obj:
                    walk(item)
            elif isinstance(obj, dict):
                for value in obj.values():
                    walk(value)

        walk(data)
    return words


def ensure_ecdict() -> Path:
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    if CACHE.exists() and CACHE.stat().st_size > 1000:
        return CACHE
    print("downloading ecdict…")
    with urllib.request.urlopen(ECDICT_URL, timeout=180) as resp:
        CACHE.write_bytes(resp.read())
    return CACHE


def clean_gloss(translation: str) -> str:
    # ECDICT 用字面量 "\n" / "\r" 分隔义项（CSV 里是反斜杠加字母）
    lines = [line.strip() for line in re.split(r"\\[nr]", translation)]
    lines = [line for line in lines if line]
    if not lines:
        return ""
    standard = [line for line in lines if not line.startswith(WEB_PREFIX)]
    line = (standard or lines)[0]
    if line.startswith(WEB_PREFIX):
        line = line[len(WEB_PREFIX):].strip()
    line = re.sub(r"\s+", " ", line).strip()
    if len(line) > MAX_GLOSS_CHARS:
        line = line[:MAX_GLOSS_CHARS] + "…"
    return line


def main() -> None:
    words = extract_course_words()
    print(f"course words: {len(words)}")

    mapping: dict[str, str] = {}
    with ensure_ecdict().open(encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            word = (row.get("word") or "").strip().lower()
            if word not in words or word in mapping:
                continue
            gloss = clean_gloss(row.get("translation") or "")
            if gloss:
                mapping[word] = gloss

    missing = sorted(words - mapping.keys())
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(
        json.dumps(mapping, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {OUT} entries={len(mapping)} missing={len(missing)}")
    if missing[:30]:
        print("missing sample:", ", ".join(missing[:30]))


if __name__ == "__main__":
    main()
