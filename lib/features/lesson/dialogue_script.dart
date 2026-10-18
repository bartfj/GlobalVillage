import 'dart:convert';

import 'package:flutter/services.dart';

import '../../data/sources/content_documents.dart';

class DialogueLine {
  final int speaker;
  final String english;
  final String chinese;

  const DialogueLine({
    required this.speaker,
    required this.english,
    required this.chinese,
  });

  factory DialogueLine.fromJson(Map<String, dynamic> json) => DialogueLine(
    speaker: json['speaker'] as int,
    english: json['english'] as String,
    chinese: json['chinese'] as String,
  );
}

class DialogueScript {
  final String unitId;
  final List<DialogueLine> lines;

  const DialogueScript(this.unitId, this.lines);

  static Future<DialogueScript?> load(
    String unitId, {
    ContentDocuments? documents,
  }) async {
    final raw = await readOverlaidText(
      documents: documents,
      packId: 'dialogues/units',
      bundle: () =>
          rootBundle.loadString('assets/dialogues/unit_dialogues.json'),
    );
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final lines = data[unitId] as List<dynamic>?;
    if (lines == null || lines.isEmpty) return null;
    return DialogueScript(
      unitId,
      lines
          .map((line) => DialogueLine.fromJson(line as Map<String, dynamic>))
          .toList(),
    );
  }
}
