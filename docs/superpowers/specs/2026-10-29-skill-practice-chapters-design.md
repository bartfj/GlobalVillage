# 专项练习章节化设计

日期：2026-10-29  
状态：已确认

## 目标

专项练习从「选技能 → 随机 10 题」改为「选技能 → 章节地图 → 章内随机练习」，消除开盲盒感；保留专项随机练习感，不并入系统课程路径。

## 决策摘要

| 项 | 选择 |
|----|------|
| 结构方案 | 专项自有 `chapters[]`（不复用 Course→Unit→Lesson） |
| 交互 | 章节地图 + 进度；已解锁章可跳练 |
| 解锁 | 软解锁：第 1 章默认开，完成一章开下一章 |
| 完成 | 一轮正确率 ≥ 80%；已完成不降级 |
| 范围 | 全部 9 个 `SkillPracticeKind` |
| 内容 | 只重组现有题，不新写题 |
| 奖励 | 不写入系统课程进度 / 不发课程奖励 |
| 云同步 | 默认仅本地 Hive；不做专项章节云同步 |

## 数据模型

```json
{
  "skill": "englishYoga",
  "title": "瑜伽英文",
  "chapters": [
    {
      "id": "eyg-core",
      "title": "核心术语",
      "subtitle": "合十到调息",
      "exercises": []
    }
  ]
}
```

- `SkillPracticeChapter`：`id` / `title` / `subtitle?` / `exercises`
- `SkillPracticeBank` 持有有序 `chapters[]`（顺序 = 解锁顺序）
- 兼容旧扁平 JSON：仅有顶层 `exercises` 时包成单章 `default`
- 章内 `pickSession`：最多 10 题；不足则全抽

## 进度与解锁

按 `skill + chapterId` 本地存储：

- `completed` / `bestAccuracy` / `lastAccuracy` / `lastPlayedAt`
- 门槛常量 `passAccuracy = 0.8`
- 达标 → `completed = true` 并解锁下一章；未达标不降级已完成状态
- 学习日志 `mode`：`skill-<name>/<chapterId>`

## 路由与 UI

- `/practice/:skill` → 章节地图
- `/practice/:skill/:chapterId` → 练习会话
- 地图状态：已完成 / 可练 / 锁定
- 结束弹窗：回地图；未达标「再练本章」；达标且有下一章「去下一章」

## 分章（重组现有题）

| 技能 | 章数 | 思路 |
|------|------|------|
| pronunciation / speaking | 5 | 入门课单元带 |
| vocabulary | 5 | 主题带 + 中级拆分 |
| englishYoga | 5 | terms / cues 分组 |
| chineseTones | 3 | 约 9 题/章 |
| chineseCharacters | 3 | 问候 / 数字 / 请求 |
| sanskritLetters | 3 | 元音 / 辅音 / 拼读 |
| sanskritVowels | 2 | a/ā 与 i/ī |
| sanskritYoga | 4 | 主题术语组 |

## 明确不做

- 不把专项并进系统课程路径
- 不新写练习题
- 不做专项章节跨设备云同步
