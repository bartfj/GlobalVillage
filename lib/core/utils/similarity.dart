/// 词级相似度：归一化后按词做 Levenshtein 距离，
/// score = 1 - dist / max(词数1, 词数2)。空文本返回 0。
double sentenceSimilarity(String target, String spoken) {
  final a = _normalizeWords(target);
  final b = _normalizeWords(spoken);
  if (a.isEmpty || b.isEmpty) return 0;
  // Levenshtein（滚动数组）
  var prev = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final curr = List<int>.filled(b.length + 1, 0);
    curr[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      curr[j] = [
        prev[j] + 1,
        curr[j - 1] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    prev = curr;
  }
  final dist = prev[b.length];
  final maxLen = a.length > b.length ? a.length : b.length;
  return 1 - dist / maxLen;
}

/// 归一化：小写、去掉所有非字母数字字符（标点不影响评分）、压缩空白、按词切分
List<String> _normalizeWords(String text) {
  final s = text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return s.isEmpty ? const [] : s.split(' ');
}
