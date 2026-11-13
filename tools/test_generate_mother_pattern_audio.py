import hashlib
import importlib.util
import json
import tempfile
import unittest
import wave
from pathlib import Path


class MotherPatternAudioTest(unittest.TestCase):
    def audio(self):
        source = Path(__file__).with_name('generate_mother_pattern_audio.py')
        self.assertTrue(source.exists(), 'Independent-course audio tool is missing')
        spec = importlib.util.spec_from_file_location('mother_pattern_audio', source)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def course(self):
        return {
            'id': 'motherPattern',
            'units': [{'lessons': [{
                'id': 'mp_u1l1',
                'exercises': [{'id': 'mp_u1l1_e1', 'audioId': 'mp_u1l1_e1', 'sentence': 'I am Tom.'}],
                'patternLesson': {
                    'dialogue': [{'audioId': 'mp_u1l1_dialogue_1', 'text': 'Hello.'}],
                    'vocabulary': [{'audioId': 'mp_u1l1_vocab_1', 'text': 'Tom'}],
                    'examples': [], 'review': [],
                },
            }]}],
        }

    def test_collects_real_pack_all_instruction_and_answer_audio(self):
        audio = self.audio()
        root = Path(__file__).resolve().parents[1]
        course = json.loads((root / 'assets/courses/course_mother_pattern.json').read_text(encoding='utf-8'))
        items = audio.collect_items(course)
        self.assertEqual(len(items), 483)
        self.assertEqual(items['mp_u3l1_dialogue_2'], 'Here you are.')

    def test_rejects_old_course(self):
        audio = self.audio()
        course = self.course()
        course['id'] = 'beginner'
        with self.assertRaises(ValueError):
            audio.collect_items(course)

    def test_rejects_duplicate_audio_id_across_metadata_and_exercises(self):
        audio = self.audio()
        course = self.course()
        course['units'][0]['lessons'][0]['patternLesson']['vocabulary'][0]['audioId'] = 'mp_u1l1_e1'
        with self.assertRaises(ValueError):
            audio.collect_items(course)

    def test_rejects_path_traversal_audio_id(self):
        audio = self.audio()
        course = self.course()
        course['units'][0]['lessons'][0]['exercises'][0]['audioId'] = 'mp_../escape'
        with self.assertRaises(ValueError):
            audio.collect_items(course)

    def test_legacy_pilot_ids_cannot_be_used_by_independent_audio(self):
        audio = self.audio()
        course = self.course()
        course['units'][0]['lessons'][0]['exercises'][0]['audioId'] = 'mp_name_example_1'
        with self.assertRaises(ValueError):
            audio.collect_items(course)

    def test_another_lesson_cannot_overwrite_an_owned_audio_id(self):
        audio = self.audio()
        course = self.course()
        course['units'][0]['lessons'][0]['exercises'][0]['audioId'] = 'mp_u2l1_e1'
        with self.assertRaises(ValueError):
            audio.collect_items(course)

    def test_swapped_wav_bytes_cannot_be_certified_as_current_sentence(self):
        audio = self.audio()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'assets/courses').mkdir(parents=True)
            (root / 'assets/courses/course_mother_pattern.json').write_text(json.dumps(self.course()), encoding='utf-8')
            wav_directory = root / 'wav'
            wav_directory.mkdir()
            manifest = {}
            for audio_id, sentence in audio.collect_items(self.course()).items():
                path = wav_directory / f'{audio_id}.wav'
                with wave.open(str(path), 'wb') as recording:
                    recording.setparams((1, 2, 22050, 0, 'NONE', 'not compressed'))
                    recording.writeframes(b'\x00\x10' * 22050)
                manifest[audio_id] = {'sentenceSha256': audio.fingerprint(sentence), 'voice': 'test',
                                     'wavSha256': hashlib.sha256(path.read_bytes()).hexdigest()}
            changed = wav_directory / 'mp_u1l1_e1.wav'
            with wave.open(str(changed), 'wb') as recording:
                recording.setparams((1, 2, 22050, 0, 'NONE', 'not compressed'))
                recording.writeframes(b'\x00\x20' * 22050)
            (wav_directory / 'manifest.json').write_text(json.dumps(manifest), encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'WAV'):
                audio.run(root, wav_directory=wav_directory)
            self.assertFalse((root / 'assets/audio/listening/mp_u1l1_e1.mp3').exists())

    def test_edited_sentence_cannot_reuse_previous_recording(self):
        audio = self.audio()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            clip = root / 'mp_test.mp3'
            clip.write_bytes(b'ID3' + b'0' * 300)
            entry = {'sentenceSha256': audio.fingerprint('I want tea.'),
                     'audioSha256': hashlib.sha256(clip.read_bytes()).hexdigest(), 'voice': 'test'}
            self.assertTrue(audio.recording_current(clip, 'I want tea.', entry))
            self.assertFalse(audio.recording_current(clip, 'I want milk.', entry))

    def test_changed_bytes_and_empty_voice_cannot_pass_check(self):
        audio = self.audio()
        with tempfile.TemporaryDirectory() as directory:
            clip = Path(directory) / 'mp_test.mp3'
            clip.write_bytes(b'ID3' + b'0' * 300)
            entry = {'sentenceSha256': audio.fingerprint('Hello.'),
                     'audioSha256': hashlib.sha256(clip.read_bytes()).hexdigest(), 'voice': 'test'}
            clip.write_bytes(b'ID3' + b'1' * 300)
            self.assertFalse(audio.recording_current(clip, 'Hello.', entry))
            entry['audioSha256'] = hashlib.sha256(clip.read_bytes()).hexdigest()
            entry['voice'] = ''
            self.assertFalse(audio.recording_current(clip, 'Hello.', entry))

    def test_missing_or_silent_audio_cannot_pass_decode(self):
        audio = self.audio()
        with tempfile.TemporaryDirectory() as directory:
            clip = Path(directory) / 'missing.mp3'
            self.assertFalse(audio.recording_current(clip, 'Hello.', {}))
            with self.assertRaises((ValueError, OSError)):
                audio.decode_recording(clip)


if __name__ == '__main__':
    unittest.main()
