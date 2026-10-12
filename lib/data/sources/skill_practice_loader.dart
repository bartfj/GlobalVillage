import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../models/course.dart';
import '../models/skill_practice.dart';

/// 加载专项练习题库并抽取会话题目
class SkillPracticeLoader {
  SkillPracticeLoader({AssetBundle? assetBundle, Random? random})
    : _assetBundle = assetBundle ?? rootBundle,
      _random = random ?? Random();

  final AssetBundle _assetBundle;
  final Random _random;

  Future<SkillPracticeBank> load(SkillPracticeKind skill) async {
    final jsonStr = await _assetBundle.loadString(skill.assetPath);
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
}
