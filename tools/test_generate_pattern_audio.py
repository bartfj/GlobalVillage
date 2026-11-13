import importlib.util
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("pattern_audio", Path(__file__).with_name("generate_pattern_audio.py"))
audio = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audio)


class PatternAudioTest(unittest.TestCase):
    def test_rejects_unsafe_ids_before_constructing_paths(self):
        exercises = {phase: [] for phase in audio.PHASES}
        exercises["examples"] = [{"id": "mp_../escape", "sentence": "Hello."}]
        with self.assertRaises(ValueError):
            audio.collect_items({"units": [{"lessons": [{"patternTraining": exercises}]}]})

    def test_does_not_collect_regular_course_audio(self):
        self.assertEqual(audio.collect_items({"units": [{"lessons": [{
            "exercises": [{"id": "old", "sentence": "Hello."}]}]}]}), [])

    def test_short_or_empty_mp3_cannot_pass_offline_check(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "empty.mp3"
            path.write_bytes(b"ID3")
            self.assertFalse(audio.valid_mp3(path))
            path.write_bytes(b"broken" + b"0" * 300)
            self.assertFalse(audio.valid_mp3(path))

    def test_recording_fingerprint_changes_with_edited_sentence(self):
        self.assertNotEqual(audio.fingerprint('I want tea.'), audio.fingerprint('I want milk.'))
        self.assertEqual(audio.fingerprint(' I want tea. '), audio.fingerprint('I want tea.'))


if __name__ == "__main__":
    unittest.main()
