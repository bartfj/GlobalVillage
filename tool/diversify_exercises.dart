import 'dart:convert';
import 'dart:io';

void main() {
  for (final track in ['zero', 'beginner']) {
    final file = File('assets/courses/course_$track.json');
    final course = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    for (final unit in course['units'] as List) {
      final number = int.parse((unit['id'] as String).split('u').last);
      if (track == 'zero' && number <= 4) continue;
      final lessons = unit['lessons'] as List;
      for (var i = 0; i < lessons.length; i++) {
        final exercises = lessons[i]['exercises'] as List;
        final production = exercises[4] as Map<String, dynamic>;
        production['type'] = i.isEven ? 'wordBank' : 'translateInput';
        final listening = exercises[6] as Map<String, dynamic>;
        listening['type'] = i.isEven ? 'listeningWordBank' : 'dictation';
        listening['prompt'] = i.isEven ? '听音组句' : '听写句子';
        listening['options'] = <String>[];
        listening['answer'] = listening['sentence'];
      }
    }
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(course)}\n',
    );
  }
}
