import 'package:english_village/app/providers.dart';
import 'package:english_village/core/services/phonetic_lookup_service.dart';
import 'package:english_village/features/lesson/widgets/tappable_phonetic_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('formatIpaLabel wraps IPA with LTR isolate', () {
    expect(formatIpaLabel(null, loading: true), '查询中…');
    expect(formatIpaLabel(null, loading: false), '暂无音标，可点喇叭');
    expect(formatIpaLabel('/rɪˈplaɪ/', loading: false), '\u2066/rɪˈplaɪ/\u2069');
  });

  testWidgets('bubble shows textbook IPA for reply and support', (tester) async {
    final service = PhoneticLookupService(
      client: MockClient((request) async => http.Response('nope', 500)),
      localIpa: {
        'reply': '/rɪˈplaɪ/',
        'support': '/səˈpɔːrt/',
      },
      localGloss: {
        'reply': '回答；回复',
        'support': '支持；支撑',
      },
    );
    addTearDown(service.dispose);

    Future<void> openWord(String word) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            phoneticLookupProvider.overrideWith((ref) => service),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return TextButton(
                    onPressed: () => showPhoneticBubble(
                      context,
                      word: word,
                      globalPosition: const Offset(40, 80),
                      anchorSize: const Size(48, 24),
                    ),
                    child: const Text('open'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump();
    }

    await openWord('reply');
    expect(find.text('\u2066/rɪˈplaɪ/\u2069'), findsOneWidget);
    expect(find.text('回答；回复'), findsOneWidget);

    dismissPhoneticBubble();
    await tester.pump();

    await openWord('support.');
    expect(find.text('\u2066/səˈpɔːrt/\u2069'), findsOneWidget);
    expect(find.text('支持；支撑'), findsOneWidget);

    dismissPhoneticBubble();
  });
}
