import 'package:english_village/core/utils/similarity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('全同句子相似度为 1', () {
    expect(sentenceSimilarity('Nice to meet you', 'Nice to meet you'), 1.0);
  });

  test('标点与大小写不影响评分', () {
    expect(
      sentenceSimilarity('Nice to meet you, Leo!', 'nice to meet you leo'),
      1.0,
    );
  });

  test('一词之差相似度 >= 0.6', () {
    final score = sentenceSimilarity(
      'I like reading books',
      'I like reading',
    );
    expect(score, greaterThanOrEqualTo(0.6));
  });

  test('完全不同的句子相似度 < 0.6', () {
    final score = sentenceSimilarity(
      'What is your name',
      'banana apple orange grape',
    );
    expect(score, lessThan(0.6));
  });

  test('空识别结果相似度为 0', () {
    expect(sentenceSimilarity('Hello world', ''), 0);
    expect(sentenceSimilarity('Hello world', '!!!'), 0);
  });
}
