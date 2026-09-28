import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../models/course.dart';
import '../models/course_track.dart';

/// 从 assets 加载并解析内置课程
class CourseLoader {
  final AssetBundle _assetBundle;

  CourseLoader({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  Future<Course> load(CourseTrack track) async {
    final jsonStr = await _assetBundle.loadString(track.assetPath);
    return Course.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
  }

  Future<List<Course>> loadAll() async {
    final courses = <Course>[];
    for (final track in CourseTrack.values) {
      courses.add(await load(track));
    }
    return courses;
  }
}
