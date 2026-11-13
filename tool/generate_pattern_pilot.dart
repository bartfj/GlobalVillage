import 'dart:convert';
import 'dart:io';

/// Compatibility entry point for callers of the retired beginner pilot tool.
/// It only returns a deep copy. The independent course has its own generator.
Map<String, dynamic> withPatternPilot(
  Map<String, dynamic> original, {
  bool refresh = false,
}) {
  if (original['id'] != 'beginner') {
    throw ArgumentError('Expected beginner course');
  }
  return jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
}

void main(List<String> args) {
  stdout.writeln(
    'Beginner pilot generator retired; use generate_mother_pattern_course.dart. No files changed.',
  );
}
