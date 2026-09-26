import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../models/course.dart';

/// 从 assets 加载并解析内置课程
class CourseLoader {
  static const courseAssetPath = 'assets/courses/course_beginner.json';

  final AssetBundle _assetBundle;

  CourseLoader({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  Future<Course> load() async {
    final jsonStr = await _assetBundle.loadString(courseAssetPath);
    return Course.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
  }
}
