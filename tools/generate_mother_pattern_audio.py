"""Encode/check the standalone motherPattern audio from offline 16-bit WAVs.

python tools/generate_mother_pattern_audio.py --wav-directory <directory>
python tools/generate_mother_pattern_audio.py --check --decode
WAVs can be prepared with tools/generate_mother_pattern_wav.ps1.
Requires lameenc for encoding and miniaudio for a real decode check.
Existing course and withdrawn pilot audio are never modified.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import wave
from pathlib import Path


def fingerprint(sentence: str) -> str:
    return hashlib.sha256(sentence.strip().encode('utf-8')).hexdigest()


def collect_items(course: dict) -> dict[str, str]:
    if course.get('id') != 'motherPattern':
        raise ValueError('Only the standalone motherPattern course is supported')
    items = {}

    def add(audio_id, sentence, lesson_id):
        if (not isinstance(audio_id, str)
                or not re.fullmatch(r'mp_u\d+l\d+_[a-z0-9_]+', audio_id)
                or not audio_id.startswith(lesson_id + '_')):
            raise ValueError(f'Unsafe audio ID: {audio_id}')
        if not isinstance(sentence, str) or not sentence.strip() or audio_id in items:
            raise ValueError(f'Empty text or duplicate audio ID: {audio_id}')
        items[audio_id] = sentence.strip()

    for unit in course['units']:
        for lesson in unit['lessons']:
            lesson_id = lesson['id']
            if not isinstance(lesson_id, str) or not re.fullmatch(r'mp_u\d+l\d+', lesson_id):
                raise ValueError(f'Invalid independent lesson ID: {lesson_id}')
            metadata = lesson['patternLesson']
            for item in metadata['dialogue'] + metadata['vocabulary']:
                add(item['audioId'], item['text'], lesson_id)
            for exercise in lesson['exercises'] + metadata['examples'] + metadata['review']:
                add(exercise.get('audioId') or exercise['id'], exercise['sentence'], lesson_id)
    return items


def recording_current(path: Path, sentence: str, entry: dict) -> bool:
    if not path.is_file() or path.stat().st_size < 256 or not entry.get('voice'):
        return False
    data = path.read_bytes()
    header = data[:3] == b'ID3' or (data[0] == 255 and data[1] & 224 == 224)
    return bool(header and entry.get('sentenceSha256') == fingerprint(sentence)
                and entry.get('audioSha256') == hashlib.sha256(data).hexdigest())


def decode_recording(path: Path) -> float:
    import miniaudio
    if not path.is_file():
        raise ValueError(f'Missing audio: {path.name}')
    try:
        recording = miniaudio.mp3_read_file_s16(str(path))
    except Exception as error:
        raise ValueError(f'Invalid MP3: {path.name}') from error
    duration = recording.num_frames / recording.sample_rate
    if duration < 0.3 or not recording.samples or max(abs(s) for s in recording.samples) < 100:
        raise ValueError(f'Empty or silent audio: {path.name}')
    return duration


def run(root: Path, *, wav_directory: Path | None = None, decode: bool = False) -> dict:
    course = json.loads((root / 'assets/courses/course_mother_pattern.json').read_text(encoding='utf-8'))
    items = collect_items(course)
    output = root / 'assets/audio/listening'
    manifest_path = output / 'mother_pattern_audio_manifest.json'
    if wav_directory is not None:
        import lameenc
        wav_manifest = json.loads((wav_directory / 'manifest.json').read_text(encoding='utf-8-sig'))
        # Validate every text/voice before installing any new assets.
        for audio_id, sentence in items.items():
            entry = wav_manifest.get(audio_id, {})
            path = wav_directory / f'{audio_id}.wav'
            if (entry.get('sentenceSha256') != fingerprint(sentence) or not entry.get('voice')
                    or not path.is_file()
                    or entry.get('wavSha256') != hashlib.sha256(path.read_bytes()).hexdigest()):
                raise ValueError(f'Stale WAV text/voice/bytes: {audio_id}; regenerate WAVs')
        output.mkdir(parents=True, exist_ok=True)
        manifest = {}
        for audio_id, sentence in items.items():
            with wave.open(str(wav_directory / f'{audio_id}.wav'), 'rb') as recording:
                if recording.getsampwidth() != 2 or recording.getnframes() == 0:
                    raise ValueError(f'Expected nonempty 16-bit PCM: {audio_id}')
                encoder = lameenc.Encoder()
                encoder.set_bit_rate(96)
                encoder.set_in_sample_rate(recording.getframerate())
                encoder.set_channels(recording.getnchannels())
                encoder.set_quality(2)
                encoded = encoder.encode(recording.readframes(recording.getnframes())) + encoder.flush()
            (output / f'{audio_id}.mp3').write_bytes(encoded)
            manifest[audio_id] = {
                'sentenceSha256': fingerprint(sentence),
                'audioSha256': hashlib.sha256(encoded).hexdigest(),
                'wavSha256': wav_manifest[audio_id]['wavSha256'],
                'voice': wav_manifest[audio_id]['voice'],
            }
        manifest_path.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    manifest = json.loads(manifest_path.read_text(encoding='utf-8')) if manifest_path.exists() else {}
    failures = [audio_id for audio_id, sentence in items.items()
                if not recording_current(output / f'{audio_id}.mp3', sentence, manifest.get(audio_id, {}))]
    if failures:
        raise ValueError(f'Missing, invalid or stale recordings: {", ".join(failures)}')
    durations = [decode_recording(output / f'{audio_id}.mp3') for audio_id in items] if decode else []
    result = {'count': len(items), 'totalBytes': sum((output / f'{key}.mp3').stat().st_size for key in items),
              'textAndAudioHashes': 'pass', 'decode': 'pass' if decode else 'not-run'}
    if durations:
        result.update(minSeconds=min(durations), maxSeconds=max(durations))
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--wav-directory', type=Path)
    parser.add_argument('--check', action='store_true', help='Check assets without generating audio')
    parser.add_argument('--decode', action='store_true', help='Decode every clip and reject empty/silent PCM')
    arguments = parser.parse_args()
    if arguments.check and arguments.wav_directory:
        parser.error('--check and --wav-directory are mutually exclusive')
    print(json.dumps(run(arguments.root.resolve(), wav_directory=arguments.wav_directory, decode=arguments.decode)))
