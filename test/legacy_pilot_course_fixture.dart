import 'dart:convert';
import 'dart:io';

import 'package:english_village/data/models/course.dart';
import 'package:flutter_test/flutter_test.dart';

// Retained pre-withdrawal pack models an old cached beginner course. Never load
// the shipped asset here: that asset deliberately contains no pilot metadata.
Course loadLegacyPilotCourse() {
  final baseline = Process.runSync('git', [
    'show',
    'd691041fa2a90e037f0733eb1d7c550585e27dc1:assets/courses/course_beginner.json',
  ], stdoutEncoding: utf8);
  expect(
    baseline.exitCode,
    0,
    reason: 'Retained legacy pack must be available',
  );
  return Course.fromJson(
    jsonDecode(baseline.stdout as String) as Map<String, dynamic>,
  );
}
