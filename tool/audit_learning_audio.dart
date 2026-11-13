import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final output = args.length == 2 && args.first == '--output'
      ? args.last
      : 'docs/音频资源验收清单.json';
  final rows = <Map<String, dynamic>>[];
  void check(String path, String text) {
    final file = File(path);
    final exists = file.existsSync();
    final bytes = exists ? file.readAsBytesSync() : <int>[];
    final mp3 =
        bytes.length > 3 &&
        ((bytes[0] == 73 && bytes[1] == 68 && bytes[2] == 51) ||
            (bytes[0] == 255 && bytes[1] & 224 == 224));
    rows.add({
      'path': path,
      'text': text,
      'bytes': bytes.length,
      'status': mp3 ? 'header-ok-listening-pending' : 'missing-or-invalid',
    });
  }

  for (final track in ['zero', 'beginner', 'intermediate', 'mother_pattern']) {
    final data = jsonDecode(
      File('assets/courses/course_$track.json').readAsStringSync(),
    );
    for (final unit in data['units']) {
      for (final lesson in unit['lessons']) {
        final metadata = lesson['patternLesson'] as Map?;
        if (metadata != null) {
          for (final item in [
            ...metadata['dialogue'],
            ...metadata['vocabulary'],
          ]) {
            check(
              'assets/audio/listening/${item['audioId']}.mp3',
              item['text'],
            );
          }
          for (final exercise in [
            ...lesson['exercises'],
            ...metadata['examples'],
            ...metadata['review'],
          ]) {
            check(
              'assets/audio/listening/${exercise['audioId'] ?? exercise['id']}.mp3',
              exercise['sentence'],
            );
          }
          continue;
        }
        final pattern = lesson['patternTraining'] as Map?;
        if (pattern != null) {
          for (final phase in [
            'examples',
            'substitution',
            'recall',
            'transfer',
            'review',
          ]) {
            for (final ex in pattern[phase]) {
              check('assets/audio/listening/${ex['id']}.mp3', ex['sentence']);
            }
          }
        }
        for (final ex in lesson['exercises']) {
          if ([
            'listeningChoice',
            'listeningWordBank',
            'dictation',
            'speaking',
          ].contains(ex['type'])) {
            check('assets/audio/listening/${ex['id']}.mp3', ex['sentence']);
          }
        }
      }
    }
  }
  final dialogues =
      jsonDecode(
            File('assets/dialogues/unit_dialogues.json').readAsStringSync(),
          )
          as Map;
  for (final entry in dialogues.entries) {
    final lines = entry.value as List;
    for (var i = 0; i < lines.length; i++) {
      check(
        'assets/audio/dialogues/${entry.key}_${i + 1}.mp3',
        lines[i]['english'],
      );
    }
  }
  File(output).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({'automatedCheck': 'existence-size-mp3-header', 'manualListening': 'pending', 'devicePlayback': 'pending', 'files': rows})}\n',
  );
  final failures = rows
      .where((r) => r['status'] == 'missing-or-invalid')
      .length;
  stdout.writeln(
    '${rows.length} audio files checked; $failures missing or invalid',
  );
  if (failures != 0) exitCode = 1;
}
