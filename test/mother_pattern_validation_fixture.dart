import 'dart:convert';
import 'dart:io';

Map<String, dynamic> independentPack({String root = '.'}) =>
    jsonDecode(
          File(
            '$root/assets/courses/course_mother_pattern.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

Map<String, dynamic> firstPattern(Map<String, dynamic> pack) =>
    pack['units'][0]['lessons'][0]['patternLesson'] as Map<String, dynamic>;

Map<String, dynamic> firstLesson(Map<String, dynamic> pack) =>
    pack['units'][0]['lessons'][0] as Map<String, dynamic>;

// Each change breaks a separate published-content contract. Shared by the real
// server publication validator and client overlay loader regression tests.
final independentPackMutations = <String, void Function(Map<String, dynamic>)>{
  'wrong identity': (p) => p['id'] = 'beginner',
  'wrong language': (p) => p['language'] = 'chinese',
  'missing unit': (p) => (p['units'] as List).removeLast(),
  'missing lesson': (p) => (p['units'][0]['lessons'] as List).removeLast(),
  'legacy metadata': (p) => firstLesson(p)['patternTraining'] = {},
  'missing metadata': (p) => firstLesson(p).remove('patternLesson'),
  'bad metadata version': (p) => firstPattern(p)['version'] = 0,
  'bad metadata kind': (p) => firstPattern(p)['kind'] = 'unknown',
  'missing Chinese rule': (p) => firstPattern(p)['slotRule'] = ' ',
  'missing limitations': (p) => firstPattern(p)['limitations'] = [],
  'missing examples': (p) => firstPattern(p)['examples'] = [],
  'missing review': (p) => firstPattern(p)['review'] = [],
  'missing vocabulary': (p) => firstPattern(p)['vocabulary'] = [],
  'missing dialogue': (p) => firstPattern(p)['dialogue'] = [],
  'non English dialogue': (p) => firstPattern(p)['dialogue'][0]['text'] = '你好',
  'unit namespace': (p) => p['units'][0]['id'] = 'u1',
  'lesson namespace': (p) => firstLesson(p)['id'] = 'u1l1',
  'duplicate unit': (p) => p['units'][1]['id'] = p['units'][0]['id'],
  'duplicate lesson': (p) =>
      p['units'][1]['lessons'][0]['id'] = firstLesson(p)['id'],
  'duplicate metadata': (p) =>
      p['units'][1]['lessons'][0]['patternLesson']['id'] = firstPattern(
        p,
      )['id'],
  'duplicate scored entity': (p) =>
      firstLesson(p)['exercises'][0]['id'] = p['units'][0]['id'],
  'duplicate supplemental entity': (p) =>
      firstPattern(p)['examples'][0]['id'] = firstLesson(p)['id'],
  'duplicate dialogue audio': (p) => firstPattern(p)['dialogue'][0]['audioId'] =
      firstLesson(p)['exercises'][0]['id'],
  'duplicate vocabulary audio': (p) =>
      firstPattern(p)['vocabulary'][0]['audioId'] = firstPattern(
        p,
      )['dialogue'][0]['audioId'],
  'wrong reference audio': (p) =>
      firstLesson(p)['exercises'][0]['audioId'] = 'mp_elsewhere',
  'unsafe audio': (p) =>
      firstPattern(p)['vocabulary'][0]['audioId'] = 'mp_../escape',
  'wrong pattern order': (p) {
    final l = p['units'][0]['lessons'] as List;
    final t = l[0];
    l[0] = l[1];
    l[1] = t;
  },
  'future dialogue pattern': (p) =>
      p['units'][0]['lessons'][3]['patternLesson']['patternIds'][0] = 'mp_like',
  'wrong taught pattern': (p) => firstPattern(p)['patternIds'] = ['mp_name'],
  'unknown phase reference': (p) =>
      firstPattern(p)['phases'][0]['exerciseIds'][0] = 'mp_missing',
  'duplicate phase reference': (p) =>
      firstPattern(p)['phases'][0]['exerciseIds'][1] = firstPattern(
        p,
      )['phases'][0]['exerciseIds'][0],
  'wrong phase order': (p) => firstPattern(p)['phases'][0]['type'] = 'scenario',
  'wrong phase type': (p) =>
      firstLesson(p)['exercises'][0]['type'] = 'speaking',
  'wrong speaking mode': (p) =>
      firstLesson(p)['exercises'][8]['speakingMode'] = 'repeat',
  'wrong chunks': (p) =>
      firstLesson(p)['exercises'][2]['tokens'] = ['I am', 'Amy.'],
  'missing target': (p) => firstLesson(p)['exercises'][8]['answer'] = '',
  'wrong input audio text': (p) =>
      firstLesson(p)['exercises'][6]['sentence'] = 'I want tea.',
  'wrong scenario audio text': (p) =>
      firstLesson(p)['exercises'][8]['sentence'] = 'I want tea.',
  'wrong example audio text': (p) =>
      firstPattern(p)['examples'][0]['sentence'] = 'I want tea.',
  'wrong review audio text': (p) =>
      firstPattern(p)['review'][0]['sentence'] = 'I want tea.',
  'wrong listening audio text': (p) =>
      firstLesson(p)['exercises'][0]['sentence'] = 'I want tea.',
  'duplicate listening choices': (p) =>
      firstLesson(p)['exercises'][0]['options'] = List.filled(4, 'I am Tom.'),
  'non English alternative': (p) =>
      firstLesson(p)['exercises'][8]['acceptedAnswers'] = ['我叫汤姆'],
  'non string alternative': (p) =>
      firstLesson(p)['exercises'][8]['acceptedAnswers'] = [12],
};
