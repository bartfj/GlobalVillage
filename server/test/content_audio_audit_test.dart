import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../test/mother_pattern_validation_fixture.dart';

void main() {
  test('audio audit includes every independent scored supplemental and teaching clip', () async {
    final root = Directory.systemTemp.createTempSync('gv-content-audit-');
    addTearDown(() => root.deleteSync(recursive: true));
    for (final path in [
      'assets/courses',
      'assets/dialogues',
      'assets/audio/listening',
      'docs',
    ]) {
      Directory('${root.path}/$path').createSync(recursive: true);
    }
    for (final track in ['zero', 'beginner', 'intermediate']) {
      File('${root.path}/assets/courses/course_$track.json')
          .writeAsStringSync('{"units":[]}');
    }
    File('${root.path}/assets/dialogues/unit_dialogues.json')
        .writeAsStringSync('{}');
    final pack = independentPack(root: '..');
    File('${root.path}/assets/courses/course_mother_pattern.json')
        .writeAsStringSync(jsonEncode(pack));
    for (final unit in pack['units']) {
      for (final lesson in unit['lessons']) {
        final metadata = lesson['patternLesson'];
        for (final item in [
          ...lesson['exercises'],
          ...metadata['examples'],
          ...metadata['review'],
          ...metadata['dialogue'],
          ...metadata['vocabulary'],
        ]) {
          File('${root.path}/assets/audio/listening/${item['audioId']}.mp3')
              .writeAsBytesSync([255, 251, 144, 0]);
        }
      }
    }
    final script = File('../tool/audit_learning_audio.dart').absolute.path;
    final result = await Process.run(Platform.resolvedExecutable, [
      script,
    ], workingDirectory: root.path);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final report = jsonDecode(
      File('${root.path}/docs/音频资源验收清单.json').readAsStringSync(),
    ) as Map;
    final files = report['files'] as List;
    expect(files, hasLength(483));
    expect(files.map((f) => f['path']).toSet(), hasLength(483));
    expect(
      files.any(
        (f) =>
            f['path'] == 'assets/audio/listening/mp_u3l1_dialogue_2.mp3' &&
            f['text'] == 'Here you are.',
      ),
      isTrue,
    );
    expect(
      files.any(
        (f) => f['path'] == 'assets/audio/listening/mp_u1l1_vocab_1.mp3',
      ),
      isTrue,
    );
    expect(
      files.any((f) => f['path'] == 'assets/audio/listening/mp_u1l1_e7.mp3'),
      isTrue,
    );
    expect(
      files.any(
        (f) => f['path'] == 'assets/audio/listening/mp_u1l1_review_4.mp3',
      ),
      isTrue,
    );
  });
}
