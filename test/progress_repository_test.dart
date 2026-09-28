import 'dart:io';

import 'package:english_village/data/models/course.dart';
import 'package:english_village/data/models/progress.dart';
import 'package:english_village/data/repositories/progress_repository.dart';
import 'package:english_village/data/sources/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// 构造 2 个单元（u1: l1, l2；u2: l3）的测试课程
Course _testCourse() {
  Lesson lesson(String id) => Lesson(id: id, title: id, exercises: const []);
  return Course(
    id: 'test',
    title: 'test',
    units: [
      Unit(
        id: 'u1',
        title: 'u1',
        description: '',
        lessons: [lesson('l1'), lesson('l2')],
      ),
      Unit(id: 'u2', title: 'u2', description: '', lessons: [lesson('l3')]),
    ],
  );
}

void main() {
  late ProgressRepository repo;

  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('hive_test');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(LessonProgressAdapter());
    }
    await Hive.openBox<LessonProgress>(ProgressStore.boxName);
    repo = ProgressRepository(
      store: const ProgressStore(userKey: 'guest'),
      course: _testCourse(),
    );
  });

  tearDown(() async {
    await Hive.box<LessonProgress>(ProgressStore.boxName).deleteFromDisk();
    await Hive.close();
  });

  test('第一课始终解锁，其余初始锁定', () {
    expect(repo.isLessonUnlocked('l1'), isTrue);
    expect(repo.isLessonUnlocked('l2'), isFalse);
    expect(repo.isLessonUnlocked('l3'), isFalse);
  });

  test('正确率 69% 不解锁下一课', () async {
    final passed = await repo.recordResult(
      lessonId: 'l1',
      correctCount: 69,
      totalCount: 100,
    );
    expect(passed, isFalse);
    expect(repo.isLessonCompleted('l1'), isFalse);
    expect(repo.isLessonUnlocked('l2'), isFalse);
  });

  test('正确率 70% 解锁下一课', () async {
    final passed = await repo.recordResult(
      lessonId: 'l1',
      correctCount: 7,
      totalCount: 10,
    );
    expect(passed, isTrue);
    expect(repo.isLessonCompleted('l1'), isTrue);
    expect(repo.isLessonUnlocked('l2'), isTrue);
    expect(repo.isLessonUnlocked('l3'), isFalse);
  });

  test('单元最后一课完成后解锁下一单元首课', () async {
    await repo.recordResult(lessonId: 'l1', correctCount: 8, totalCount: 10);
    await repo.recordResult(lessonId: 'l2', correctCount: 10, totalCount: 10);
    expect(repo.isLessonUnlocked('l3'), isTrue);
  });

  test('未知课程 id 不解锁', () {
    expect(repo.isLessonUnlocked('unknown'), isFalse);
  });

  test('仅跳过当前可学习关卡，保留零分并解锁下一课', () async {
    expect(repo.currentLesson?.id, 'l1');
    expect((await repo.skipCurrentLesson())?.id, 'l1');
    final skipped = repo.store.get('l1')!;
    expect(skipped.completed, isTrue);
    expect(skipped.score, 0);
    expect(skipped.correctCount, 0);
    expect(skipped.totalCount, 0);
    expect(repo.isLessonUnlocked('l2'), isTrue);
    expect(repo.currentLesson?.id, 'l2');
    expect(repo.isLessonUnlocked('l3'), isFalse);
  });

  test('最后一课跳过后不能继续跳；重学通过可替换零分', () async {
    await repo.skipCurrentLesson();
    await repo.skipCurrentLesson();
    expect((await repo.skipCurrentLesson())?.id, 'l3');
    expect(await repo.skipCurrentLesson(), isNull);
    await repo.recordResult(lessonId: 'l1', correctCount: 8, totalCount: 10);
    expect(repo.store.get('l1')!.score, 80);
  });

  test('跳关只影响当前账号进度', () async {
    await repo.skipCurrentLesson();
    final other = ProgressRepository(
      store: const ProgressStore(userKey: 'other'),
      course: _testCourse(),
    );
    expect(other.isLessonCompleted('l1'), isFalse);
    expect(other.isLessonUnlocked('l2'), isFalse);
  });

  test('已通关后重学更低分不覆盖最好成绩，仍保持完成', () async {
    await repo.recordResult(lessonId: 'l1', correctCount: 10, totalCount: 10);
    expect(repo.store.get('l1')!.score, 100);

    final passed = await repo.recordResult(
      lessonId: 'l1',
      correctCount: 7,
      totalCount: 10,
    );
    expect(passed, isTrue);
    final kept = repo.store.get('l1')!;
    expect(kept.completed, isTrue);
    expect(kept.correctCount, 10);
    expect(kept.totalCount, 10);
    expect(kept.score, 100);
  });

  test('已通关后重学更高分会更新最好成绩', () async {
    await repo.recordResult(lessonId: 'l1', correctCount: 7, totalCount: 10);
    await repo.recordResult(lessonId: 'l1', correctCount: 9, totalCount: 10);
    final best = repo.store.get('l1')!;
    expect(best.correctCount, 9);
    expect(best.totalCount, 10);
    expect(best.score, 90);
  });
}
