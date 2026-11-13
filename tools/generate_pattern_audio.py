"""Generate only the mother-pattern pilot audio; never overwrite course audio.

Run with edge-tts available on PYTHONPATH. --check is an offline asset check.
Same-text existing course recordings are reused before generating new speech.
"""
from __future__ import annotations

import argparse
import asyncio
import hashlib
import json
import shutil
import wave
from pathlib import Path

PHASES = ("examples", "substitution", "recall", "transfer", "review")


def fingerprint(sentence: str) -> str:
    return hashlib.sha256(sentence.strip().encode('utf-8')).hexdigest()


def collect_items(course: dict) -> list[tuple[str, str]]:
    items = []
    seen = set()
    for unit in course["units"]:
        for lesson in unit["lessons"]:
            pattern = lesson.get("patternTraining")
            if not pattern:
                continue
            for phase in PHASES:
                for exercise in pattern[phase]:
                    eid, sentence = exercise["id"], exercise["sentence"].strip()
                    if not eid.startswith("mp_") or not eid.replace("_", "").isalnum():
                        raise ValueError(f"Unsafe pilot audio id: {eid}")
                    if not sentence or eid in seen:
                        raise ValueError(f"Empty or duplicate pilot audio: {eid}")
                    seen.add(eid)
                    items.append((eid, sentence))
    return items


def valid_mp3(path: Path) -> bool:
    if not path.is_file() or path.stat().st_size < 256:
        return False
    with path.open("rb") as source:
        header = source.read(3)
    return header == b"ID3" or (header[0] == 255 and header[1] & 224 == 224)


async def generate(root: Path, check: bool, wav_directory: Path | None = None, decode: bool = False) -> None:
    course = json.loads((root / "assets/courses/course_beginner.json").read_text(encoding="utf-8"))
    items = collect_items(course)
    if len(items) != 78:
        raise ValueError(f"Expected 78 pilot audio references, got {len(items)}")
    output = root / "assets/audio/listening"
    manifest_path = output / "pattern_audio_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding='utf-8')) if manifest_path.exists() else {}
    def current(eid: str, sentence: str) -> bool:
        return manifest.get(eid, {}).get('sentenceSha256') == fingerprint(sentence) and valid_mp3(output / f'{eid}.mp3')
    def write_manifest(voice: str) -> None:
        manifest_path.write_text(json.dumps({eid: {'sentenceSha256': fingerprint(sentence), 'voice': voice}
            for eid, sentence in items}, indent=2) + '\n', encoding='utf-8')
    if check:
        missing = [eid for eid, sentence in items if not current(eid, sentence)]
        if missing:
            raise SystemExit(f"Missing/invalid/stale pilot recordings: {', '.join(missing)}")
        print(f"PASS: {len(items)} pilot MP3 files match current sentences and have nonempty audio headers.")
        if decode:
            import miniaudio
            durations = []
            for eid, _ in items:
                recording = miniaudio.mp3_read_file_s16(str(output / f'{eid}.mp3'))
                duration = recording.num_frames / recording.sample_rate
                if duration < 0.3 or not recording.samples or max(abs(s) for s in recording.samples) < 100:
                    raise ValueError(f'Empty, silent or invalid decoded recording: {eid}')
                durations.append(duration)
            print(f'PASS: decoded {len(items)} MP3 files to non-silent PCM; durations {min(durations):.2f}-{max(durations):.2f} seconds.')
        return

    if wav_directory is not None:
        import lameenc
        wav_manifest = json.loads((wav_directory / 'manifest.json').read_text(encoding='utf-8-sig'))
        output.mkdir(parents=True, exist_ok=True)
        for eid, sentence in items:
            if wav_manifest.get(eid, {}).get('sentenceSha256') != fingerprint(sentence):
                raise ValueError(f'Stale WAV recording: {eid}; rerun generate_pattern_wav.ps1')
            with wave.open(str(wav_directory / f"{eid}.wav"), "rb") as recording:
                if recording.getsampwidth() != 2 or recording.getnframes() == 0:
                    raise ValueError(f"Expected nonempty 16-bit PCM: {eid}")
                encoder = lameenc.Encoder()
                encoder.set_bit_rate(96)
                encoder.set_in_sample_rate(recording.getframerate())
                encoder.set_channels(recording.getnchannels())
                encoder.set_quality(2)
                encoded = encoder.encode(recording.readframes(recording.getnframes())) + encoder.flush()
            (output / f"{eid}.mp3").write_bytes(encoded)
        manifest_path.write_text(json.dumps(wav_manifest, indent=2) + '\n', encoding='utf-8')
        await generate(root, True)
        return

    import edge_tts

    output.mkdir(parents=True, exist_ok=True)
    sources = {}
    for unit in course["units"]:
        for lesson in unit["lessons"]:
            for exercise in lesson["exercises"]:
                path = output / f"{exercise['id']}.mp3"
                if valid_mp3(path):
                    sources.setdefault(exercise["sentence"].strip(), path)
    groups: dict[str, list[Path]] = {}
    for eid, sentence in items:
        path = output / f"{eid}.mp3"
        groups.setdefault(sentence, []).append(path)
        if current(eid, sentence):
            sources.setdefault(sentence, path)
    semaphore = asyncio.Semaphore(3)

    async def one(sentence: str, targets: list[Path]) -> None:
        async with semaphore:
            source = sources.get(sentence)
            if source is None:
                source = targets[0]
                temporary = source.with_suffix(".mp3.part")
                for attempt in range(3):
                    try:
                        await asyncio.wait_for(
                            edge_tts.Communicate(sentence, "en-US-JennyNeural", rate="-20%").save(str(temporary)),
                            timeout=45,
                        )
                        if not valid_mp3(temporary):
                            raise ValueError("Empty or invalid speech response")
                        temporary.replace(source)
                        break
                    except Exception:
                        temporary.unlink(missing_ok=True)
                        if attempt == 2:
                            raise
                        await asyncio.sleep(2)
            for target in targets:
                if target != source:
                    shutil.copyfile(source, target)
            print(f"ok {targets[0].stem} ({len(targets)} references)", flush=True)

    await asyncio.gather(*(one(sentence, targets) for sentence, targets in groups.items()))
    write_manifest('en-US-JennyNeural or same-text course recording')
    await generate(root, True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--decode", action="store_true", help="Check and decode all MP3s to non-silent PCM (requires miniaudio)")
    parser.add_argument("--wav-directory", type=Path, help="Encode offline 16-bit PCM recordings using lameenc")
    arguments = parser.parse_args()
    asyncio.run(generate(arguments.root.resolve(), arguments.check or arguments.decode, arguments.wav_directory, arguments.decode))
