import 'dart:convert';
import 'dart:io';

void main() {
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

  for (final track in ['zero', 'beginner', 'intermediate']) {
    final data = jsonDecode(
      File('assets/courses/course_$track.json').readAsStringSync(),
    );
    for (final unit in data['units']) {
      for (final lesson in unit['lessons']) {
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
  File('docs/音频资源验收清单.json').writeAsStringSync(
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
