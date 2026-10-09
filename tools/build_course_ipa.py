#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""从课程 JSON 抽词，用 CMUdict 生成教材式美式 IPA（assets/phonetics/en_ipa.json）。"""
from __future__ import annotations

import json
import re
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COURSES = ROOT / "assets" / "courses"
OUT = ROOT / "assets" / "phonetics" / "en_ipa.json"
CACHE = ROOT / "tools" / ".cache" / "cmudict.dict"
CMU_URL = (
    "https://raw.githubusercontent.com/cmusphinx/cmudict/master/cmudict.dict"
)

VOWELS = {
    "AA",
    "AE",
    "AH",
    "AO",
    "AW",
    "AY",
    "EH",
    "ER",
    "EY",
    "IH",
    "IY",
    "OW",
    "OY",
    "UH",
    "UW",
}

CONSONANT_IPA = {
    "B": "b",
    "CH": "tʃ",
    "D": "d",
    "DH": "ð",
    "F": "f",
    "G": "ɡ",
    "HH": "h",
    "JH": "dʒ",
    "K": "k",
    "L": "l",
    "M": "m",
    "N": "n",
    "NG": "ŋ",
    "P": "p",
    "R": "r",
    "S": "s",
    "SH": "ʃ",
    "T": "t",
    "TH": "θ",
    "V": "v",
    "W": "w",
    "Y": "j",
    "Z": "z",
    "ZH": "ʒ",
}

OVERRIDES = {
    "a": "/ə/",
    "the": "/ðə/",
    "i": "/aɪ/",
    "ok": "/ˌoʊˈkeɪ/",
    "okay": "/ˌoʊˈkeɪ/",
}


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


def ensure_cmudict() -> Path:
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    if CACHE.exists() and CACHE.stat().st_size > 1000:
        return CACHE
    print("downloading cmudict…")
    with urllib.request.urlopen(CMU_URL, timeout=60) as resp:
        CACHE.write_bytes(resp.read())
    return CACHE


def load_cmudict(path: Path) -> dict[str, list[str]]:
    """word -> first pronunciation, phones keep stress digits."""
    table: dict[str, list[str]] = {}
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = line.strip()
        if not line or line.startswith(";;;"):
            continue
        parts = line.split()
        if len(parts) < 2:
            continue
        raw = parts[0].lower()
        word = re.sub(r"\(\d+\)$", "", raw)
        if word in table:
            continue
        table[word] = parts[1:]
    return table


def _split_phone(token: str) -> tuple[str, int]:
    match = re.match(r"^([A-Z]+)([0-2])?$", token)
    if not match:
        return token, 0
    stress = int(match.group(2)) if match.group(2) is not None else 0
    return match.group(1), stress


def _vowel_ipa(base: str, stress: int) -> str | None:
    if base == "AH":
        return "ə" if stress == 0 else "ʌ"
    mapping = {
        "AA": "ɑː",
        "AE": "æ",
        "AO": "ɔː",
        "AW": "aʊ",
        "AY": "aɪ",
        "EH": "ɛ",
        "ER": "ɜr",
        "EY": "eɪ",
        "IH": "ɪ",
        "IY": "iː",
        "OW": "oʊ",
        "OY": "ɔɪ",
        "UH": "ʊ",
        "UW": "uː",
    }
    return mapping.get(base)


def phones_to_ipa(phones: list[str]) -> str:
    parsed: list[tuple[str, int, str]] = []
    for token in phones:
        base, stress = _split_phone(token)
        if base in VOWELS:
            ipa = _vowel_ipa(base, stress)
        else:
            ipa = CONSONANT_IPA.get(base)
        if not ipa:
            continue
        parsed.append((base, stress, ipa))

    if not parsed:
        return ""

    vowel_count = sum(1 for base, _, _ in parsed if base in VOWELS)
    marks: dict[int, str] = {}
    for i, (base, stress, _) in enumerate(parsed):
        if base not in VOWELS or stress not in (1, 2):
            continue
        # 单音节教材通常不标主重音
        if vowel_count <= 1 and stress == 1:
            continue
        start = i
        j = i - 1
        while j >= 0 and parsed[j][0] not in VOWELS:
            start = j
            j -= 1
        mark = "ˈ" if stress == 1 else "ˌ"
        # 同一起点先次后主时保留主重音
        if start not in marks or mark == "ˈ":
            marks[start] = mark

    out: list[str] = []
    for i, (_, _, ipa) in enumerate(parsed):
        if i in marks:
            out.append(marks[i])
        out.append(ipa)
    return "/" + "".join(out) + "/"


def main() -> None:
    words = extract_course_words()
    print(f"course words: {len(words)}")
    cmu = load_cmudict(ensure_cmudict())
    mapping: dict[str, str] = {}
    missing = []
    for word in sorted(words):
        phones = cmu.get(word)
        if not phones:
            missing.append(word)
            continue
        ipa = phones_to_ipa(phones)
        if ipa and ipa != "//":
            mapping[word] = ipa

    mapping.update(OVERRIDES)

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
