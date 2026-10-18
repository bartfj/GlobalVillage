/// 可下发的学习内容包。服务器只保存管理员发布过的覆盖。
class ContentPackSpec {
  const ContentPackSpec({
    required this.id,
    required this.label,
    required this.kind,
    this.courseId,
    this.skill,
  });

  final String id;
  final String label;

  /// course、dialogues、practice、phonetics
  final String kind;
  final String? courseId;
  final String? skill;
}

const contentPackSpecs = <ContentPackSpec>[
  ContentPackSpec(
    id: 'course/zero',
    label: '零基础',
    kind: 'course',
    courseId: 'zero',
  ),
  ContentPackSpec(
    id: 'course/beginner',
    label: '初级',
    kind: 'course',
    courseId: 'beginner',
  ),
  ContentPackSpec(
    id: 'course/intermediate',
    label: '中级',
    kind: 'course',
    courseId: 'intermediate',
  ),
  ContentPackSpec(
    id: 'course/chinese',
    label: '普通话入门',
    kind: 'course',
    courseId: 'chinese',
  ),
  ContentPackSpec(
    id: 'course/sanskrit',
    label: '梵文入门',
    kind: 'course',
    courseId: 'sanskrit',
  ),
  ContentPackSpec(id: 'dialogues/units', label: '单元对话', kind: 'dialogues'),
  ContentPackSpec(
    id: 'dialogues/application_tasks',
    label: '对话应用题',
    kind: 'dialogues',
  ),
  ContentPackSpec(
    id: 'practice/pronunciation',
    label: '发音练习',
    kind: 'practice',
    skill: 'pronunciation',
  ),
  ContentPackSpec(
    id: 'practice/vocabulary',
    label: '单词练习',
    kind: 'practice',
    skill: 'vocabulary',
  ),
  ContentPackSpec(
    id: 'practice/speaking',
    label: '口语练习',
    kind: 'practice',
    skill: 'speaking',
  ),
  ContentPackSpec(id: 'phonetics/en_ipa', label: '英语音标', kind: 'phonetics'),
];

ContentPackSpec? contentPackById(String id) {
  for (final spec in contentPackSpecs) {
    if (spec.id == id) return spec;
  }
  return null;
}

/// `audio/listening/{id}.mp3` 或 `audio/dialogues/{unit}_{line}.mp3`
final contentAudioPath = RegExp(
  r'^audio/(listening|dialogues)/[A-Za-z0-9_-]+\.mp3$',
);

const maxContentJsonBytes = 8 * 1024 * 1024;
const maxContentAudioBytes = 2 * 1024 * 1024;
