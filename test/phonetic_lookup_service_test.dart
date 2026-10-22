import 'dart:convert';
import 'dart:io';

import 'package:english_village/core/services/phonetic_lookup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('PhoneticLookupService.normalize', () {
    test('strips punctuation and lowercases', () {
      expect(PhoneticLookupService.normalize("Hello,"), 'hello');
      expect(PhoneticLookupService.normalize('"World!"'), 'world');
      expect(PhoneticLookupService.normalize("  OK.  "), 'ok');
      expect(PhoneticLookupService.normalize("don't"), "don't");
    });

    test('looksEnglish detects latin letters', () {
      expect(PhoneticLookupService.looksEnglish('Hello'), isTrue);
      expect(PhoneticLookupService.looksEnglish('你好'), isFalse);
      expect(PhoneticLookupService.looksEnglish('A.'), isTrue);
    });
  });

  group('PhoneticLookupService.lookup', () {
    test('hits local IPA and gloss without calling network', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response('nope', 500);
      });
      final service = PhoneticLookupService(
        client: client,
        localIpa: {'hello': 'həˈloʊ'},
        localGloss: {'hello': 'int. 你好；喂'},
      );
      final result = await service.lookup('Hello!');
      expect(result?.ipa, '/həˈloʊ/');
      expect(result?.meaning, 'int. 你好；喂');
      expect(calls, 0);
      // cache
      await service.lookup('hello');
      expect(calls, 0);
      service.dispose();
    });

    test('local IPA only fills meaning from Youdao', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response(
          jsonEncode({
            'ec': {
              'word': [
                {
                  'usphone': 'rɪˈplaɪ',
                  'trs': [
                    {
                      'tr': [
                        {
                          'l': {
                            'i': ['v. 回答；回复'],
                          },
                        },
                      ],
                    },
                  ],
                },
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = PhoneticLookupService(
        client: client,
        localIpa: {'reply': 'rɪˈplaɪ'},
        localGloss: const {},
      );
      final result = await service.lookup('reply');
      expect(result?.ipa, '/rɪˈplaɪ/');
      expect(result?.meaning, 'v. 回答；回复');
      expect(calls, 1);
      await service.lookup('reply');
      expect(calls, 1);
      service.dispose();
    });

    test('Youdao meaning without phone still counts as a hit', () async {
      final service = PhoneticLookupService(
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'ec': {
                'word': [
                  {
                    'trs': [
                      {
                        'tr': [
                          {
                            'l': {'i': 'int. 你好'},
                          },
                        ],
                      },
                    ],
                  },
                ],
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        localIpa: const {},
        localGloss: const {},
      );
      final result = await service.lookup('hello');
      expect(result?.ipa, isNull);
      expect(result?.meaning, 'int. 你好');
      service.dispose();
    });

    test('falls back to Youdao usphone and caches', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(request.url.host, 'dict.youdao.com');
        expect(request.url.queryParameters['q'], 'morning');
        return http.Response(
          jsonEncode({
            'ec': {
              'word': [
                {'usphone': 'ˈmɔːrnɪŋ', 'ukphone': 'ˈmɔːnɪŋ'},
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = PhoneticLookupService(
        client: client,
        localIpa: const {},
        localGloss: const {},
      );
      final first = await service.lookup('Morning');
      expect(first?.ipa, '/ˈmɔːrnɪŋ/');
      await service.lookup('morning');
      expect(calls, 1);
      service.dispose();
    });

    test('network error is not cached and can retry', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        if (calls == 1) {
          throw Exception('timeout');
        }
        return http.Response(
          jsonEncode({
            'ec': {
              'word': [
                {'usphone': 'kæt'},
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = PhoneticLookupService(
        client: client,
        localIpa: const {},
        localGloss: const {},
      );
      expect(await service.lookup('cat'), isNull);
      final second = await service.lookup('cat');
      expect(second?.ipa, '/kæt/');
      expect(calls, 2);
      service.dispose();
    });

    test('network error keeps local IPA and retries for meaning', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        throw Exception('timeout');
      });
      final service = PhoneticLookupService(
        client: client,
        localIpa: {'cat': 'kæt'},
        localGloss: const {},
      );
      final first = await service.lookup('cat');
      expect(first?.ipa, '/kæt/');
      expect(first?.meaning, isNull);
      expect(calls, 1);
      final second = await service.lookup('cat');
      expect(second?.ipa, '/kæt/');
      expect(calls, 2);
      service.dispose();
    });

    test('confirmed miss from Youdao is cached as null', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response(
          jsonEncode({'ec': {}}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = PhoneticLookupService(
        client: client,
        localIpa: const {},
        localGloss: const {},
      );
      expect(await service.lookup('xyzzyxyz'), isNull);
      expect(await service.lookup('xyzzyxyz'), isNull);
      expect(calls, 1);
      service.dispose();
    });

    test('merges concurrent lookups for same word', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return http.Response(
          jsonEncode({
            'ec': {
              'word': [
                {'ukphone': 'kæt'},
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = PhoneticLookupService(
        client: client,
        localIpa: const {},
        localGloss: const {},
      );
      final results = await Future.wait([
        service.lookup('cat'),
        service.lookup('Cat'),
        service.lookup('cat.'),
      ]);
      expect(results.every((r) => r?.ipa == '/kæt/'), isTrue);
      expect(calls, 1);
      service.dispose();
    });
  });

  group('course IPA lexicon', () {
    Map<String, dynamic> loadLexicon() {
      final raw = File('assets/phonetics/en_ipa.json').readAsStringSync();
      return jsonDecode(raw) as Map<String, dynamic>;
    }

    test('textbook IPA for common words', () {
      final lexicon = loadLexicon();
      expect(lexicon['reply'], '/rɪˈplaɪ/');
      expect(lexicon['support'], '/səˈpɔːrt/');
      expect(lexicon['hello'], '/həˈloʊ/');
      expect(lexicon['about'], '/əˈbaʊt/');
      expect(lexicon['please'], '/pliːz/');
      expect(lexicon['the'], '/ðə/');
      expect(lexicon['a'], '/ə/');
      expect(lexicon['pharmacist'], '/ˈfɑːrməsɪst/');
    });

    test('lookup wraps local textbook IPA', () async {
      final lexicon = loadLexicon().map((k, v) => MapEntry(k, v as String));
      final service = PhoneticLookupService(
        client: MockClient((request) async => http.Response('nope', 500)),
        localIpa: lexicon,
        localGloss: const {},
      );
      expect((await service.lookup('Reply'))?.ipa, '/rɪˈplaɪ/');
      expect((await service.lookup('support.'))?.ipa, '/səˈpɔːrt/');
      service.dispose();
    });
  });

  group('course glossary', () {
    test('local glosses cover common course words', () {
      final raw = File('assets/phonetics/en_zh.json').readAsStringSync();
      final glossary = jsonDecode(raw) as Map<String, dynamic>;
      final hanzi = RegExp(r'[\u4e00-\u9fff]');
      for (final word in ['reply', 'support', 'hello', 'pharmacist']) {
        final gloss = glossary[word];
        expect(gloss, isA<String>(), reason: word);
        expect(hanzi.hasMatch(gloss as String), isTrue, reason: word);
      }
    });
  });
}
