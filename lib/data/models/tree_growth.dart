/// 梭梭树成长阶段（蚂蚁森林式）：按累计梭梭树数升阶
enum TreeStage {
  seed('种子', 0),
  sprout('幼苗', 1),
  smallTree('小树', 5),
  bigTree('梭梭大树', 15);

  const TreeStage(this.label, this.minTrees);

  /// 阶段名称（如「种子」「梭梭大树」）
  final String label;

  /// 达到该阶段所需的最低累计梭梭树数
  final int minTrees;
}

/// 由累计梭梭树数推导当前阶段（取满足 minTrees <= count 的最高阶段）
TreeStage stageFor(int count) {
  var stage = TreeStage.seed;
  for (final s in TreeStage.values) {
    if (count >= s.minTrees) stage = s;
  }
  return stage;
}

/// 累计数为 [count] 时是否刚升阶（阶段与 count-1 不同即为升阶，阈值可调不出错）
bool hasStageUp(int count) =>
    count > 0 && stageFor(count) != stageFor(count - 1);
