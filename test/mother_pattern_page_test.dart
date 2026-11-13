import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:english_village/app/providers.dart';
import 'package:english_village/app/selected_track_controller.dart';
import 'package:english_village/core/services/tts_service.dart';
import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/models/course_track.dart';
import 'package:english_village/data/sources/learning_store.dart';
import 'package:english_village/data/sources/mother_pattern_store.dart';
import 'package:english_village/features/mother_pattern/mother_pattern_page.dart';
import 'package:english_village/features/mother_pattern/mother_pattern_providers.dart';
import 'package:english_village/features/mother_pattern/mother_pattern_speech.dart';
import 'package:english_village/features/mother_pattern/mother_pattern_question.dart';
import 'package:english_village/features/lesson/widgets/award_celebration.dart';
import 'mother_pattern_completion_test.dart'
    show PatternProgress, PatternRewards, FailingPatternStore, finishPattern;
import 'mother_pattern_speech_test.dart'
    show FakePatternRecorder, FakePatternRecognizer;
import 'ui_test_overrides.dart';
import 'tts_cancellation_test.dart'
    show
        ControlledAudioPlayer,
        ControlledSpeechEngine,
        ControlledAssets,
        ControlledDocuments;

class PatternVoice implements TtsService {
  final played = <String>[];
  int stopped = 0;
  @override
  Future<bool> speakExercise(Exercise exercise) async {
    played.add(exercise.id);
    return true;
  }

  @override
  Future<void> stop() async {
    stopped++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PatternTrack extends StateNotifier<CourseTrack>
    implements SelectedTrackController {
  PatternTrack() : super(CourseTrack.motherPattern);
  void change(CourseTrack track) {
    state = track;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final testPatternAccount = StateProvider<MotherPatternStore?>((ref) => null);

void main() {
  late Directory temp;
  late Course course;
  late Lesson lesson;
  late FailingPatternStore store;
  late FakePatternRecorder recorder;
  late FakePatternRecognizer recognizer;
  late MotherPatternSpeech speech;
  late PatternVoice voice;
  late PatternProgress progress;
  late PatternRewards rewards;
  late PatternTrack track;
  ProviderContainer? container;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('mp-page');
    Hive.init(temp.path);
    await Hive.openBox<String>(LearningStore.boxName);
    course = Course.fromJson(
      jsonDecode(
        File('assets/courses/course_mother_pattern.json').readAsStringSync(),
      ),
    );
    lesson = course.orderedLessons.first;
    store = FailingPatternStore(
      userKey: 'alice',
      learningStore: LearningStore(userKey: 'alice'),
    );
    recorder = FakePatternRecorder();
    recognizer = FakePatternRecognizer();
    speech = MotherPatternSpeech(recorder: recorder, recognizer: recognizer);
    voice = PatternVoice();
    progress = PatternProgress();
    rewards = PatternRewards(course);
    track = PatternTrack();
  });
  tearDown(() async {
    container?.dispose();
    container = null;
    await Hive.close();
    await temp.delete(recursive: true);
  });
  Future<void> app(
    WidgetTester tester, {
    MotherPatternReviewSnapshot? snapshot,
    bool practice = false,
    TtsService? playback,
  }) async {
    container = ProviderContainer(
      overrides: [
        uiStringsOverride,
        courseProvider.overrideWithValue(course),
        motherPatternStoreProvider.overrideWith(
          (ref) => ref.watch(testPatternAccount),
        ),
        progressRepositoryProvider.overrideWithValue(progress),
        rewardRepositoryProvider.overrideWithValue(rewards),
        ttsServiceProvider.overrideWithValue(playback ?? voice),
        selectedTrackProvider.overrideWith((ref) => track),
        motherPatternSpeechFactoryProvider.overrideWithValue(() => speech),
      ],
    );
    container!.read(testPatternAccount.notifier).state = store;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container!,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: MotherPatternPage(
            lessonId: lesson.id,
            lesson: lesson,
            reviewSnapshot: snapshot,
            practice: practice,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
  }

  Future<void> spoken(WidgetTester tester, String answer) async {
    recognizer.text = answer;
    await tap(tester, 'speech-start');
    await tester.runAsync(() async {
      recorder.emit();
      await Future<void>.delayed(Duration.zero);
    });
    await tap(tester, 'speech-stop');
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const ValueKey('pattern-next')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('pattern-next')));
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pumpAndSettle();
  }

  Future<void> guided(WidgetTester tester, Exercise e) async {
    if (e.type == ExerciseType.listeningChoice) {
      await tap(tester, 'option-${e.id}-${e.options.indexOf(e.answer)}');
    } else if (e.type == ExerciseType.wordBank) {
      for (var i = 0; i < e.tokens.length; i++) {
        await tap(tester, 'token-${e.id}-$i');
      }
    } else if (e.type == ExerciseType.speaking) {
      await spoken(tester, e.answer);
    } else {
      await tester.enterText(
        find.byKey(const ValueKey('pattern-input')),
        e.answer,
      );
    }
    await tap(tester, 'pattern-check');
    await finish(tester);
  }

  Future<void> toRecall(WidgetTester tester) async {
    await tap(tester, 'pattern-start');
    for (final e in lesson.exercises.take(6)) {
      await guided(tester, e);
    }
  }

  for (final transition in [
    'next item',
    'microphone',
    'account',
    'departure',
    'teaching start',
    'TTS volume',
  ]) {
    testWidgets('pending native reference cannot start after $transition', (
      tester,
    ) async {
      final blocked = Completer<void>();
      final player = ControlledAudioPlayer();
      final tts = ControlledSpeechEngine();
      final assets = ControlledAssets();
      final documents = ControlledDocuments();
      switch (transition) {
        case 'next item':
          assets.waiting = blocked;
        case 'microphone':
          player.sourceWait = blocked;
        case 'account':
          documents.waiting = blocked;
          documents.path = 'cached.mp3';
        case 'departure':
          assets.exists = false;
          tts.languageWait = blocked;
        case 'teaching start':
          player.contextWait = blocked;
        case 'TTS volume':
          assets.exists = false;
          tts.volumeWait = blocked;
      }
      final service = TtsService(
        player: player,
        tts: tts,
        assets: assets,
        documents: documents,
      );
      addTearDown(service.dispose);
      await app(tester, playback: service);
      if (transition == 'next item' || transition == 'TTS volume') {
        await toRecall(tester);
        await tester.enterText(
          find.byKey(const ValueKey('pattern-input')),
          lesson.exercises[6].answer,
        );
        await tap(tester, 'pattern-check');
        await tap(tester, 'reference-audio');
        await tap(tester, 'pattern-next');
        expect(find.text('8 / 10 题'), findsOneWidget);
      } else if (transition == 'microphone') {
        await tap(tester, 'pattern-start');
        for (final e in lesson.exercises.take(4)) {
          await guided(tester, e);
        }
        await tap(tester, 'reference-audio');
        await tap(tester, 'speech-start');
        expect(recorder.recording, true);
      } else {
        await tap(tester, 'dialogue-audio-0');
        if (transition == 'teaching start') {
          await tap(tester, 'pattern-start');
        } else if (transition == 'account') {
          await tester.runAsync(() async {
            container!.read(testPatternAccount.notifier).state =
                MotherPatternStore(userKey: 'bob');
            await Future<void>.delayed(const Duration(milliseconds: 20));
          });
          await tester.pumpAndSettle();
        } else {
          await tester.pumpWidget(const SizedBox());
        }
      }
      await tester.runAsync(() async {
        blocked.complete();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      expect(player.starts, isEmpty);
      expect(tts.spoken, isEmpty);
    });
  }
  for (final initialTrees in [2, 4]) {
    testWidgets(
      'rewarded result and tree ${initialTrees + 1} collection fit 320x560 with 1.8 fonts',
      (tester) async {
        tester.view.physicalSize = const Size(320, 560);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.8;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        rewards.attempts.addAll(List.generate(initialTrees, (i) => 'prior-$i'));
        await app(tester);
        await tap(tester, 'pattern-start');
        for (final e in lesson.exercises) {
          await guided(tester, e);
        }
        expect(find.byType(AwardCelebration), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('收下徽章'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('收下徽章'));
        await tester.pumpAndSettle();
        expect(find.byType(AwardCelebration), findsNothing);
        expect(find.text('本次训练已记录'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'stale reference completion does not stop a newer permitted answer playback',
    (tester) async {
      final player = ControlledAudioPlayer()..sourceWait = Completer<void>();
      final service = TtsService(
        player: player,
        tts: ControlledSpeechEngine(),
        assets: ControlledAssets(),
      );
      addTearDown(service.dispose);
      await app(tester, playback: service);
      await toRecall(tester);
      await tester.enterText(
        find.byKey(const ValueKey('pattern-input')),
        lesson.exercises[6].answer,
      );
      await tap(tester, 'pattern-check');
      await tap(tester, 'reference-audio');
      await tap(tester, 'pattern-next');
      await tester.enterText(
        find.byKey(const ValueKey('pattern-input')),
        lesson.exercises[7].answer,
      );
      await tap(tester, 'pattern-check');
      await tap(tester, 'reference-audio');
      await tester.runAsync(() async {
        player.sourceWait!.complete();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      expect(player.starts.length, 1);
      expect(
        (player.starts.single as AssetSource).path,
        'audio/listening/${lesson.exercises[7].id}.mp3',
      );
    },
  );
  for (final modality in ['recall', 'typed fallback']) {
    testWidgets(
      '$modality input and submit scroll above 220px keyboard at 320x560 and 1.8 fonts',
      (tester) async {
        tester.view.physicalSize = const Size(320, 560);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.8;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final snapshot = modality == 'typed fallback'
            ? store.reviewSnapshot(course.id, lesson)
            : null;
        await app(tester, snapshot: snapshot);
        if (snapshot == null) {
          await toRecall(tester);
        } else {
          await tap(tester, 'typed-fallback');
        }
        tester.view.viewInsets = const FakeViewPadding(bottom: 220);
        await tester.pump();
        await tester.ensureVisible(find.byKey(const ValueKey('pattern-input')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('pattern-input')).hitTestable(),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const ValueKey('pattern-input')),
          snapshot?.exercises.first.answer ?? lesson.exercises[6].answer,
        );
        await tap(tester, 'pattern-check');
        await tester.ensureVisible(find.byKey(const ValueKey('pattern-next')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('pattern-next')).hitTestable(),
          findsOneWidget,
        );
        await finish(tester);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'teaching includes dialogue vocabulary rules and offline-id audio before ten stages',
    (tester) async {
      await app(tester);
      expect(find.text('母句型英语'), findsOneWidget);
      expect(find.text(lesson.patternLesson!.slotRule), findsOneWidget);
      expect(
        find.text(lesson.patternLesson!.dialogue.first.text),
        findsOneWidget,
      );
      await tap(tester, 'dialogue-audio-0');
      expect(voice.played.single, lesson.patternLesson!.dialogue.first.audioId);
      await tap(tester, 'vocabulary-audio-0');
      expect(voice.played.last, lesson.patternLesson!.vocabulary.first.audioId);
      await tap(tester, 'pattern-start');
      expect(find.text('1 / 10 题'), findsOneWidget);
      expect(find.text('听懂表达'), findsOneWidget);
      expect(find.text(lesson.title), findsNothing);
      expect(voice.stopped, greaterThan(0));
    },
  );
  testWidgets(
    'independent hints reveal only frame support and keep answer audio hidden until submit',
    (tester) async {
      await app(tester);
      await toRecall(tester);
      final e = lesson.exercises[6];
      expect(find.text('7 / 10 题'), findsOneWidget);
      expect(find.text('脱稿表达'), findsOneWidget);
      expect(find.text(lesson.title), findsNothing);
      expect(find.text(lesson.patternLesson!.frame), findsNothing);
      expect(find.text(e.answer), findsNothing);
      expect(find.byKey(const ValueKey('reference-audio')), findsNothing);
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const ValueKey('pattern-input')),
                matching: find.byType(TextField),
              ),
            )
            .controller!
            .text,
        '',
      );
      await tap(tester, 'pattern-hint');
      expect(find.text(lesson.patternLesson!.frame), findsNothing);
      expect(find.text(lesson.patternLesson!.slotRule), findsNothing);
      expect(find.byKey(const ValueKey('reference-audio')), findsNothing);
      expect(find.text(e.answer), findsNothing);
      await tester
          .widget<MotherPatternQuestion>(find.byType(MotherPatternQuestion))
          .onPlay(e);
      expect(voice.played, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('pattern-input')),
        e.answer,
      );
      await tap(tester, 'pattern-check');
      expect(find.text(e.answer), findsNWidgets(2));
      expect(find.byKey(const ValueKey('reference-audio')), findsOneWidget);
      await finish(tester);
      expect(find.text(lesson.patternLesson!.frame), findsNothing);
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const ValueKey('pattern-input')),
                matching: find.byType(TextField),
              ),
            )
            .controller!
            .text,
        '',
      );
    },
  );
  testWidgets(
    'raw scenario transcript rejects wrong object and accepts authored contractions',
    (tester) async {
      final snapshot = store.reviewSnapshot(course.id, lesson);
      await app(tester, snapshot: snapshot);
      expect(find.text(snapshot.exercises.first.answer), findsNothing);
      expect(voice.played, isEmpty);
      await spoken(tester, 'I am a teacher.');
      expect(find.text('I am a teacher.'), findsNothing);
      expect(find.text('已识别，提交后查看转写。'), findsOneWidget);
      await tap(tester, 'pattern-check');
      expect(find.text('I am a teacher.'), findsOneWidget);
      expect(find.text(snapshot.exercises.first.answer), findsOneWidget);
      await finish(tester);
      await spoken(tester, snapshot.exercises[1].answer);
      await tap(tester, 'pattern-check');
      await finish(tester);
      expect(find.text('订正练习 · 第 1 题'), findsOneWidget);
      await spoken(tester, 'I’m Tom.');
      await tap(tester, 'pattern-check');
      await finish(tester);
      expect(find.text('本次训练已记录'), findsOneWidget);
      expect(
        store
            .latestSummary(course.id, lesson.patternLesson!)!
            .independentSpokenCorrect,
        1,
      );
      expect(rewards.treeCount, 0);
      expect(progress.saves, 0);
    },
  );
  testWidgets(
    'denied empty and failed recognition offer retry and explicit typed fallback',
    (tester) async {
      final snapshot = store.reviewSnapshot(course.id, lesson);
      await app(tester, snapshot: snapshot);
      recorder.permitted = false;
      await tap(tester, 'speech-start');
      expect(find.text('请允许麦克风后重试，或使用键盘替代。'), findsOneWidget);
      recorder.permitted = true;
      await spoken(tester, '');
      expect(find.text('没有听到清晰语音，请重试。'), findsOneWidget);
      recognizer.fail = true;
      await spoken(tester, '');
      expect(find.text('语音识别失败，请重试。'), findsOneWidget);
      await tap(tester, 'typed-fallback');
      expect(find.text('键盘替代 · 不计入口语成功'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('pattern-input')),
        snapshot.exercises.first.answer,
      );
      await tap(tester, 'pattern-check');
      await finish(tester);
      expect(find.byKey(const ValueKey('pattern-input')), findsNothing);
      recognizer.fail = false;
      await spoken(tester, snapshot.exercises[1].answer);
      await tap(tester, 'pattern-check');
      await finish(tester);
      final summary = store.latestSummary(course.id, lesson.patternLesson!)!;
      expect(summary.independentTypedFallbackCorrect, 1);
      expect(summary.independentSpokenCorrect, 1);
      expect(find.text('键盘替代首答 1'), findsOneWidget);
    },
  );
  testWidgets('account change cancels microphone and ignores late transcript', (
    tester,
  ) async {
    await app(tester, snapshot: store.reviewSnapshot(course.id, lesson));
    await tap(tester, 'speech-start');
    expect(recorder.recording, true);
    await tester.runAsync(() async {
      container!.read(testPatternAccount.notifier).state = MotherPatternStore(
        userKey: 'bob',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
    expect(recorder.recording, false);
    expect(find.text('当前账号或课程无法继续这次练习。'), findsOneWidget);
    recorder.emit();
    await tester.pump();
    expect(find.byKey(const ValueKey('pattern-check')), findsNothing);
  });
  testWidgets('account interruption discards a pending offline transcript', (
    tester,
  ) async {
    await app(tester, snapshot: store.reviewSnapshot(course.id, lesson));
    recognizer.result = Completer<String>();
    await tap(tester, 'speech-start');
    await tester.runAsync(() async {
      recorder.emit();
      await Future<void>.delayed(Duration.zero);
    });
    await tap(tester, 'speech-stop');
    expect(find.text('正在离线识别…'), findsOneWidget);
    await tester.runAsync(() async {
      container!.read(testPatternAccount.notifier).state = MotherPatternStore(
        userKey: 'bob',
      );
      recognizer.result!.complete('I am Tom.');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
    expect(find.text('I am Tom.'), findsNothing);
    expect(speech.transcript, '');
    expect(store.latestSummary(course.id, lesson.patternLesson!), isNull);
  });
  testWidgets(
    'silent recording stays unsubmitted with retry and typed fallback',
    (tester) async {
      await app(tester, snapshot: store.reviewSnapshot(course.id, lesson));
      recognizer.text = 'I am Tom.';
      await tap(tester, 'speech-start');
      await tester.runAsync(() async {
        recorder.emit(0, 1000);
        await Future<void>.delayed(Duration.zero);
      });
      await tap(tester, 'speech-stop');
      expect(find.text('没有听到清晰语音，请重试。'), findsOneWidget);
      expect(recognizer.received, isEmpty);
      final check = tester.widget<FilledButton>(
        find.byKey(const ValueKey('pattern-check')),
      );
      expect(check.onPressed, isNull);
      expect(find.byKey(const ValueKey('speech-start')), findsOneWidget);
      await tap(tester, 'typed-fallback');
      expect(find.byKey(const ValueKey('pattern-input')), findsOneWidget);
      expect(store.latestSummary(course.id, lesson.patternLesson!), isNull);
    },
  );
  testWidgets(
    'double check and continue callbacks keep one attempt and reset the next input',
    (tester) async {
      final snapshot = store.reviewSnapshot(course.id, lesson);
      await app(tester, snapshot: snapshot);
      await tap(tester, 'typed-fallback');
      await tester.enterText(
        find.byKey(const ValueKey('pattern-input')),
        snapshot.exercises.first.answer,
      );
      var question = tester.widget<MotherPatternQuestion>(
        find.byType(MotherPatternQuestion),
      );
      question.onCheck();
      question.onCheck();
      await tester.pump();
      question = tester.widget<MotherPatternQuestion>(
        find.byType(MotherPatternQuestion),
      );
      expect(question.state.attempts.length, 1);
      await tester.runAsync(() async {
        question.onNext();
        question.onNext();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpAndSettle();
      question = tester.widget<MotherPatternQuestion>(
        find.byType(MotherPatternQuestion),
      );
      expect(question.state.current.id, snapshot.exercises[1].id);
      expect(question.answer, '');
      expect(question.state.currentTypedFallback, false);
    },
  );
  for (final order in ['fallback then next', 'next then fallback']) {
    testWidgets('mixed delayed $order keeps fallback on the originating item', (
      tester,
    ) async {
      final snapshot = store.reviewSnapshot(course.id, lesson);
      await app(tester, snapshot: snapshot);
      await spoken(tester, 'I am a teacher.');
      await tap(tester, 'pattern-check');
      final question = tester.widget<MotherPatternQuestion>(
        find.byType(MotherPatternQuestion),
      );
      final blocked = Completer<void>();
      recorder.cancelWaiters.add(blocked);
      await tester.runAsync(() async {
        if (order == 'fallback then next') {
          question.onFallback();
          await Future<void>.delayed(Duration.zero);
          question.onNext();
        } else {
          question.onNext();
          await Future<void>.delayed(Duration.zero);
          question.onFallback();
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
        blocked.complete();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpAndSettle();
      final next = tester.widget<MotherPatternQuestion>(
        find.byType(MotherPatternQuestion),
      );
      expect(next.state.current.id, snapshot.exercises[1].id);
      expect(next.state.currentTypedFallback, false);
      expect(
        next.state.typedFallbackIds.contains(snapshot.exercises[1].id),
        false,
      );
      expect(next.answer, '');
    });
  }
  testWidgets(
    'a changed opening review snapshot saves as stale practice without formal advancement',
    (tester) async {
      var now = DateTime(2026, 11, 13);
      store = FailingPatternStore(
        userKey: 'alice',
        learningStore: LearningStore(userKey: 'alice'),
        clock: () => now,
      );
      await tester.runAsync(() async {
        await store.recordSession(
          courseId: course.id,
          lesson: lesson,
          sessionId: 'training',
          state: finishPattern(lesson),
        );
      });
      now = DateTime(2026, 11, 14);
      final snapshot = store.reviewSnapshot(course.id, lesson);
      expect(snapshot.dueEligible, true);
      await app(tester, snapshot: snapshot);
      await tester.runAsync(() async {
        await store.recordSession(
          courseId: course.id,
          lesson: lesson,
          sessionId: 'other-review',
          state: finishPattern(lesson, snapshot: snapshot),
          reviewSnapshot: snapshot,
        );
      });
      final before = store.reviewEntry(course.id, lesson.patternLesson!)!;
      for (final e in snapshot.exercises) {
        await spoken(tester, e.answer);
        await tap(tester, 'pattern-check');
        await finish(tester);
      }
      expect(find.text('练习已记录 · 原复习计划已失效'), findsOneWidget);
      expect(find.text('到期复习已记录'), findsNothing);
      expect(
        store.reviewEntry(course.id, lesson.patternLesson!)!.revision,
        before.revision,
      );
      expect(progress.saves, 0);
      expect(rewards.treeCount, 0);
    },
  );
  testWidgets(
    'course change and page disposal release recording and reference audio',
    (tester) async {
      await app(tester, snapshot: store.reviewSnapshot(course.id, lesson));
      await tap(tester, 'speech-start');
      await tester.runAsync(() async {
        track.change(CourseTrack.beginner);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpAndSettle();
      expect(recorder.recording, false);
      expect(find.byKey(const ValueKey('pattern-check')), findsNothing);
      expect(voice.stopped, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      expect(recorder.disposals, 1);
    },
  );
  testWidgets(
    'failed final save has no saved label or celebration and retry saves once',
    (tester) async {
      store.fail = true;
      await app(tester);
      await tap(tester, 'pattern-start');
      for (final e in lesson.exercises) {
        await guided(tester, e);
      }
      expect(find.text('本次训练已记录'), findsNothing);
      expect(find.byType(AwardCelebration), findsNothing);
      expect(find.text('学习记录保存失败，请稍后重试。'), findsOneWidget);
      expect(rewards.treeCount, 1);
      store.fail = false;
      await tester.ensureVisible(find.byKey(const ValueKey('pattern-save')));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('pattern-save')));
        await Future<void>.delayed(const Duration(milliseconds: 60));
      });
      await tester.pumpAndSettle();
      expect(find.text('本次训练已记录'), findsOneWidget);
      expect(rewards.treeCount, 1);
      expect(
        store
            .latestSummary(course.id, lesson.patternLesson!)!
            .independentSpokenCorrect,
        2,
      );
      expect(find.text('独立首答 4 / 4'), findsOneWidget);
    },
  );
  testWidgets(
    '320x560 and 1.8 text scaling keep teaching and scenario actions reachable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 560);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await app(tester);
      await tap(tester, 'pattern-start');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container!.dispose();
      container = null;
      track = PatternTrack();
      speech = MotherPatternSpeech(
        recorder: FakePatternRecorder(),
        recognizer: recognizer,
      );
      await app(tester, snapshot: store.reviewSnapshot(course.id, lesson));
      await tap(tester, 'typed-fallback');
      await tester.enterText(
        find.byKey(const ValueKey('pattern-input')),
        'I am Tom.',
      );
      await tap(tester, 'pattern-check');
      expect(tester.takeException(), isNull);
    },
  );
}
