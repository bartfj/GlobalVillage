import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'package:mother_pattern_schema/mother_pattern_schema.dart';

import '../models/course.dart';
import '../models/course_track.dart';
import 'content_documents.dart';

/// 从 assets 加载并解析内置课程。已发布覆盖优先，失败则用内置文件。
class CourseLoader {
  CourseLoader({AssetBundle? assetBundle, this.documents})
    : _assetBundle = assetBundle ?? rootBundle;

  final AssetBundle _assetBundle;
  final ContentDocuments? documents;

  Future<Course> load(CourseTrack track) async {
    final jsonStr = await readOverlaidText(
      documents: documents,
      packId: 'course/${track.id}',
      bundle: () => _assetBundle.loadString(track.assetPath),
      accept: (raw) => _acceptCourse(raw, track.id),
    );
    return Course.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
  }

  Future<List<Course>> loadAll() async {
    final courses = <Course>[];
    for (final track in CourseTrack.values) {
      courses.add(await load(track));
    }
    return courses;
  }

  static bool _acceptCourse(String raw, String courseId) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;
      final json = Map<String, dynamic>.from(decoded);
      if (validateCourseIdentityAndPatterns(json, courseId) != null) {
        return false;
      }
      Course.fromJson(json);
      return true;
    } catch (_) {
      return false;
    }
  }
}
