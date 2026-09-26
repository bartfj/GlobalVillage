import 'package:hive/hive.dart';

/// 单课学习进度（Hive 本地持久化）
class LessonProgress {
  final String lessonId;
  final bool completed;
  final int score;
  final int correctCount;
  final int totalCount;
  final DateTime? completedAt;

  const LessonProgress({
    required this.lessonId,
    required this.completed,
    required this.score,
    required this.correctCount,
    required this.totalCount,
    this.completedAt,
  });
}

/// 手写 Hive TypeAdapter，避免 build_runner 代码生成
class LessonProgressAdapter extends TypeAdapter<LessonProgress> {
  @override
  final int typeId = 0;

  @override
  LessonProgress read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LessonProgress(
      lessonId: fields[0] as String,
      completed: fields[1] as bool,
      score: fields[2] as int,
      correctCount: fields[3] as int,
      totalCount: fields[4] as int,
      completedAt: fields[5] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(fields[5] as int),
    );
  }

  @override
  void write(BinaryWriter writer, LessonProgress obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.lessonId)
      ..writeByte(1)
      ..write(obj.completed)
      ..writeByte(2)
      ..write(obj.score)
      ..writeByte(3)
      ..write(obj.correctCount)
      ..writeByte(4)
      ..write(obj.totalCount)
      ..writeByte(5)
      ..write(obj.completedAt?.millisecondsSinceEpoch);
  }
}
