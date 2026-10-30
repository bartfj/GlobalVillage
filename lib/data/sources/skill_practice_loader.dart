import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../models/course.dart';
import '../models/skill_practice.dart';
import 'content_documents.dart';

/// 加载专项练习题库并抽取会话题目
class SkillPracticeLoader {
  SkillPracticeLoader({
    AssetBundle? assetBundle,
    Random? random,
    this.documents,
  }) : _assetBundle = assetBundle ?? rootBundle,
       _random = random ?? Random();

  final AssetBundle _assetBundle;
  final Random _random;
  final ContentDocuments? documents;

  Future<SkillPracticeBank> load(SkillPracticeKind skill) async {
    final jsonStr = await readOverlaidText(
      documents: documents,
      packId: 'practice/${skill.name}',
      bundle: () => _assetBundle.loadString(skill.assetPath),
      accept: (raw) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is! Map) return false;
          SkillPracticeBank.fromJson(Map<String, dynamic>.from(decoded));
          return true;
        } catch (_) {
          return false;
        }
      },
    );
    return SkillPracticeBank.fromJson(
      jsonDecode(jsonStr) as Map<String, dynamic>,
    );
  }

  List<Exercise> pickSession(List<Exercise> exercises, {int limit = 10}) {
    if (exercises.isEmpty) return const [];
    final shuffled = List<Exercise>.of(exercises)..shuffle(_random);
    if (shuffled.length <= limit) return shuffled;
    return shuffled.take(limit).toList();
  }

  /// 从指定章节抽题；章不存在或空题返回空列表
  List<Exercise> pickChapterSession(
    SkillPracticeBank bank,
    String chapterId, {
    int limit = 10,
  }) {
    final chapter = bank.chapterById(chapterId);
    if (chapter == null) return const [];
    return pickSession(chapter.exercises, limit: limit);
  }
}
