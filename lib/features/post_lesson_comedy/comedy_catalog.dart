import 'dart:convert';

import 'package:flutter/services.dart';

class ComedyLine {
  const ComedyLine({
    required this.speaker,
    required this.english,
    required this.chinese,
    required this.action,
    required this.duration,
  });

  final String speaker, english, chinese, action;
  final double duration;

  factory ComedyLine.fromJson(Map<String, dynamic> json) => ComedyLine(
    speaker: json['speaker'] as String,
    english: json['english'] as String,
    chinese: json['chinese'] as String,
    action: json['action'] as String,
    duration: (json['duration'] as num).toDouble(),
  );
}

class ComedyEpisode {
  const ComedyEpisode({
    required this.id,
    required this.courseId,
    required this.lessonId,
    required this.title,
    required this.titleEn,
    required this.lines,
  });

  final String id, courseId, lessonId, title, titleEn;
  final List<ComedyLine> lines;

  factory ComedyEpisode.fromJson(Map<String, dynamic> json) => ComedyEpisode(
    id: json['id'] as String,
    courseId: json['courseId'] as String,
    lessonId: json['lessonId'] as String,
    title: json['title'] as String,
    titleEn: json['titleEn'] as String,
    lines: List.unmodifiable(
      (json['lines'] as List).map(
        (line) => ComedyLine.fromJson(line as Map<String, dynamic>),
      ),
    ),
  );
}

/// Independent entertainment content. This never reads or writes rewards.
class ComedyCatalog {
  const ComedyCatalog(this.episodes);

  final List<ComedyEpisode> episodes;

  static Future<ComedyCatalog> load() async {
    final raw = await rootBundle.loadString(
      'assets/dialogues/post_lesson_comedy_catalog.json',
    );
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return ComedyCatalog(
      List.unmodifiable(
        (json['episodes'] as List).map(
          (episode) => ComedyEpisode.fromJson(episode as Map<String, dynamic>),
        ),
      ),
    );
  }

  ComedyEpisode? recommend(String courseId, String lessonId) {
    final candidates = episodes.where(
      (episode) => episode.courseId == courseId,
    );
    if (candidates.isEmpty) return null;
    for (final episode in candidates) {
      if (episode.lessonId == lessonId) return episode;
    }
    // Rotate within content already covered at this level. No persisted state
    // or reward mutation is needed, and exact lesson mappings always win.
    final lessonOrder = _order(lessonId);
    final eligible = candidates
        .where((episode) => _order(episode.lessonId) <= lessonOrder)
        .toList();
    return eligible.isEmpty
        ? candidates.first
        : eligible[lessonOrder % eligible.length];
  }

  int _order(String lessonId) {
    final match = RegExp(r'u(\d+)l(\d+)$').firstMatch(lessonId);
    return match == null
        ? -1
        : int.parse(match[1]!) * 100 + int.parse(match[2]!);
  }
}
