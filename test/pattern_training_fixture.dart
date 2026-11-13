Map<String, dynamic> patternJson({String id = 'mp_want', int version = 1}) {
  Map<String, dynamic> exercise(String phase, int n, String type) => {
    'id': '${id}_$phase$n',
    'type': type,
    'prompt': 'Say that you want tea.',
    'sentence': 'I want tea.',
    'answer': 'I want tea.',
    if (type == 'wordBank') 'tokens': ['I', 'want', 'tea.'],
    if (type == 'translateInput') 'acceptedAnswers': ['I would like tea.'],
  };
  return {
    'id': id,
    'version': version,
    'frame': 'I want + noun',
    'meaning': 'Express what you want.',
    'slotRule': 'Put a noun after want.',
    'prefix': 'I want ',
    'examples': [for (var n = 1; n <= 3; n++) exercise('ex', n, 'speaking')],
    'substitution': [
      for (var n = 1; n <= 2; n++) exercise('sub', n, 'wordBank'),
    ],
    'recall': [
      for (var n = 1; n <= 2; n++) exercise('rec', n, 'translateInput'),
    ],
    'transfer': [
      for (var n = 1; n <= 2; n++) exercise('tr', n, 'translateInput'),
    ],
    'review': [
      for (var n = 1; n <= 5; n++) exercise('rev', n, 'translateInput'),
    ],
  };
}
