#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""CMU → 教材式 IPA 转写断言。"""
import unittest

from build_course_ipa import load_cmudict, ensure_cmudict, phones_to_ipa, OVERRIDES


class PhonesToIpaTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cmu = load_cmudict(ensure_cmudict())

    def _ipa(self, word: str) -> str:
        return phones_to_ipa(self.cmu[word])

    def test_reply(self):
        self.assertEqual(self._ipa("reply"), "/rɪˈplaɪ/")

    def test_support(self):
        self.assertEqual(self._ipa("support"), "/səˈpɔːrt/")

    def test_hello(self):
        self.assertEqual(self._ipa("hello"), "/həˈloʊ/")

    def test_about(self):
        self.assertEqual(self._ipa("about"), "/əˈbaʊt/")

    def test_please_monosyllable_no_stress(self):
        self.assertEqual(self._ipa("please"), "/pliːz/")

    def test_overrides(self):
        self.assertEqual(OVERRIDES["a"], "/ə/")
        self.assertEqual(OVERRIDES["the"], "/ðə/")


if __name__ == "__main__":
    unittest.main()
