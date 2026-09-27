import 'package:english_village/data/models/tree_growth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stageFor maps tree counts to correct stages', () {
    expect(stageFor(0), TreeStage.seed);
    expect(stageFor(1), TreeStage.sprout);
    expect(stageFor(4), TreeStage.sprout);
    expect(stageFor(5), TreeStage.smallTree);
    expect(stageFor(14), TreeStage.smallTree);
    expect(stageFor(15), TreeStage.bigTree);
    expect(stageFor(1000), TreeStage.bigTree);
  });

  test('hasStageUp is true only at stage boundaries', () {
    expect(hasStageUp(0), isFalse);
    expect(hasStageUp(1), isTrue); // 种子 → 幼苗
    expect(hasStageUp(2), isFalse);
    expect(hasStageUp(5), isTrue); // 幼苗 → 小树
    expect(hasStageUp(6), isFalse);
    expect(hasStageUp(15), isTrue); // 小树 → 梭梭大树
    expect(hasStageUp(16), isFalse);
  });
}
