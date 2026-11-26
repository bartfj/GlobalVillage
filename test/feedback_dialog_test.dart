import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:english_village/app/providers.dart';
import 'package:english_village/core/services/diagnostic_uploader.dart';
import 'package:english_village/features/feedback/feedback_dialog.dart';
import 'package:english_village/features/feedback/feedback_screenshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'ui_test_overrides.dart';

class _Uploader implements DiagnosticUploader {
  bool fail = false;
  Completer<bool>? pending;
  String? note;
  Uint8List? screenshot;

  @override
  Future<bool> submitFeedback({
    required String note,
    Uint8List? screenshot,
  }) async {
    if (fail) throw StateError('Disk unavailable');
    this.note = note;
    this.screenshot = screenshot;
    final response = pending;
    if (response != null) return response.future;
    return false;
  }

  @override
  Future<bool> submitNote(String note) => submitFeedback(note: note);

  @override
  Future<bool> flush() async => true;
}

void main() {
  final picture = img.encodeJpg(img.Image(width: 8, height: 6));

  Future<void> open(
    WidgetTester tester,
    _Uploader uploader,
    Future<Uint8List?> Function() pick,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          uiStringsOverride,
          diagnosticUploaderProvider.overrideWithValue(uploader),
          feedbackScreenshotPickerProvider.overrideWithValue(pick),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showFeedbackDialog(context, ref),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows submission progress until server confirmation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pending = Completer<bool>();
    final uploader = _Uploader()..pending = pending;
    await open(tester, uploader, () async => null);
    await tester.enterText(find.byType(TextField), '题目显示不完整');
    await tester.tap(find.text('发送'));
    await tester.pump();

    expect(find.text('正在提交反馈…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.widgetWithText(TextButton, '发送'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('正在提交反馈…'), findsOneWidget);

    pending.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('反馈提交成功'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(uploader.note, '题目显示不完整');
  });

  testWidgets('canceling replacement preserves the screenshot and note', (
    tester,
  ) async {
    final uploader = _Uploader();
    var picks = 0;
    await open(tester, uploader, () async => picks++ == 0 ? picture : null);
    await tester.enterText(find.byType(TextField), '题目显示不完整');
    await tester.tap(find.text('从相册添加截图'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('替换截图'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.text('发送'));
    await tester.pumpAndSettle();
    expect(uploader.screenshot, picture);
    expect(uploader.note, '题目显示不完整');
    expect(find.text('反馈未确认送达'), findsOneWidget);
    expect(find.text('已保存在手机上，下次打开或返回应用时会重试'), findsOneWidget);
  });

  testWidgets('screenshot alone can be retried after a local save failure', (
    tester,
  ) async {
    final uploader = _Uploader()..fail = true;
    await open(tester, uploader, () async => picture);
    await tester.tap(find.text('从相册添加截图'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('发送'));
    await tester.pumpAndSettle();
    expect(find.text('反馈提交失败，请重试。'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    uploader.fail = false;
    await tester.tap(find.text('发送'));
    await tester.pumpAndSettle();
    expect(uploader.note, isEmpty);
    expect(uploader.screenshot, picture);
  });

  testWidgets(
    'a selected screenshot can be enlarged and removed before sending',
    (tester) async {
      final uploader = _Uploader();
      await open(tester, uploader, () async => picture);
      await tester.tap(find.text('从相册添加截图'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('放大截图'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);

      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('移除截图'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '只发说明');
      await tester.tap(find.text('发送'));
      await tester.pumpAndSettle();
      expect(uploader.note, '只发说明');
      expect(uploader.screenshot, isNull);
    },
  );

  test('normalizes a PNG to a bounded JPEG and rejects invalid data', () {
    final source = img.encodePng(img.Image(width: 2000, height: 32));
    final jpeg = normalizeFeedbackScreenshot(source);
    expect(jpeg.lengthInBytes, lessThanOrEqualTo(512 * 1024));
    final decoded = img.decodeJpg(jpeg);
    expect(decoded?.width, 1920);
    expect(decoded?.height, 31);
    expect(
      () => normalizeFeedbackScreenshot(Uint8List(12)),
      throwsFormatException,
    );
  });

  test(
    'resizes a detailed image when lowering JPEG quality is insufficient',
    () {
      const size = 1920;
      final random = Random(7);
      final rgb = Uint8List(size * size * 3);
      for (var i = 0; i < rgb.length; i++) {
        rgb[i] = random.nextInt(256);
      }
      final source = img.encodeJpg(
        img.Image.fromBytes(
          width: size,
          height: size,
          bytes: rgb.buffer,
          numChannels: 3,
        ),
      );
      final jpeg = normalizeFeedbackScreenshot(source);
      expect(jpeg.lengthInBytes, lessThanOrEqualTo(512 * 1024));
      expect(img.decodeJpg(jpeg)?.width, lessThan(size));
    },
  );
}
