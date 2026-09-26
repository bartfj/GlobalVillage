# 英语学习 App（Android）MVP 实施计划

## 1. 概述（Summary）

参考"多邻国"App，使用 **Flutter** 开发一款 Android 英语学习应用。MVP 聚焦**闯关式课程学习**：多邻国风格的垂直学习路径 + 单元/关卡解锁机制 + 多种题型的答题流程。数据**纯本地存储**（课程内容内置为 JSON 资源，学习进度存本地数据库），无需服务器，可快速产出可运行 Demo。

## 2. 当前状态分析（Current State）

- 工作目录 `d:\workspace\github_code\地球村` 为空，属全新项目（greenfield）。
- 已确认决策：
  - 技术栈：**Flutter**（一套代码，未来可扩展 iOS）
  - 功能范围：**闯关式课程学习**（技能路径 + 题型答题），游戏化激励/单词 SRS/数据统计均**不在** MVP 范围内
  - 存储方案：**纯本地**（课程内容 assets JSON + 进度本地持久化）

## 3. 技术选型（Assumptions & Decisions）

| 决策项 | 选择 | 理由 |
|---|---|---|
| 语言/框架 | Flutter (Dart, stable 渠道) | 用户指定 |
| 状态管理 | `flutter_riverpod` | 官方推荐，编译期安全，便于测试 |
| 路由 | `go_router` | 声明式路由，页面少够用 |
| 课程内容 | `assets/courses/*.json` 内置种子数据 | 无需后端，打包即完整课程 |
| 进度存储 | `hive` + `hive_flutter` | 轻量 NoSQL，解锁/进度模型简单，无需 SQL schema 迁移 |
| 单词发音 | `flutter_tts` | 调用系统 TTS 读英文单词/句子，无需内置音频文件 |
| 答题音效 | `audioplayers` + 2 个本地短音效（正确/错误） | 多邻国式即时反馈 |
| UI 风格 | 多邻国风格：圆角卡片、粗描边按钮、高饱和配色（主色 #58CC02 绿、辅色 #1CB0F6 蓝、警示 #FF4B4B 红） | 参考目标 |

## 4. 数据模型设计

### 课程内容（assets JSON，只读）
```
Course
 └─ Unit（单元，如"问候与介绍"）
     └─ Lesson（关卡，路径上的一个节点）
         └─ Exercise（题目）
```

**Exercise 题型（MVP 4 种）**：
1. `translateChoice` — 翻译单选（中→英、英→中，4 选 1）
2. `wordBank` — 词块排序组句（点击乱序词块拼出正确句子）
3. `listeningChoice` — 听力选择（flutter_tts 播放英文，选正确译文）
4. `fillBlank` — 拼写填空（句子缺词，键盘输入）

### 用户进度（Hive，本地读写）
- `lessonId → LessonProgress { completed: bool, score: int, correctCount: int, totalCount: int, completedAt: DateTime }`
- 解锁规则：前一 Lesson 完成（正确率 ≥ 70%）→ 解锁下一 Lesson；单元最后一课完成 → 解锁下一单元首课。

## 5. 项目结构与改动清单（Proposed Changes）

项目名暂定为 `english_village`（与目录"地球村"呼应）。在 `d:\workspace\github_code\地球村` 下执行 `flutter create` 初始化后，改动如下：

### 5.1 项目初始化
- `flutter create --org com.example --project-name english_village .`
- `pubspec.yaml`：添加依赖 `flutter_riverpod, go_router, hive, hive_flutter, flutter_tts, audioplayers`；注册 `assets/courses/`、`assets/sounds/` 资源目录。

### 5.2 代码结构（全部新建文件）
```
lib/
├── main.dart                          # 入口：Hive 初始化、ProviderScope、路由
├── app/
│   ├── theme.dart                     # 多邻国风格主题：配色、圆角、3D 粗边按钮样式
│   └── router.dart                    # go_router 路由表
├── core/
│   └── constants.dart                 # 解锁正确率阈值等常量
├── data/
│   ├── models/
│   │   ├── course.dart                # Course/Unit/Lesson/Exercise 模型 + fromJson
│   │   └── progress.dart              # LessonProgress + Hive TypeAdapter
│   ├── sources/
│   │   ├── course_loader.dart         # 加载并解析 assets JSON
│   │   └── progress_store.dart        # Hive 读写封装
│   └── repositories/
│       ├── course_repository.dart     # 课程查询接口
│       └── progress_repository.dart   # 进度查询/更新 + 解锁判定逻辑
├── features/
│   ├── learning_path/
│   │   ├── learning_path_page.dart    # 首页：垂直滚动的关卡路径（多邻国风）
│   │   └── widgets/
│   │       ├── unit_header.dart       # 单元标题卡
│   │       └── lesson_node.dart       # 关卡圆形节点：锁定/进行中/已完成三种状态
│   └── lesson/
│       ├── lesson_page.dart           # 答题主流程：进度条、题目轮播、判定栏
│       ├── lesson_controller.dart     # Riverpod 状态机：当前题、判定、得分
│       ├── result_page.dart           # 结算页：得分、正确率、重学/返回
│       └── widgets/
│           ├── translate_choice_widget.dart
│           ├── word_bank_widget.dart
│           ├── listening_choice_widget.dart
│           ├── fill_blank_widget.dart
│           └── answer_feedback_bar.dart  # 底部对/错判定栏（绿/红 + 音效）
assets/
├── courses/course_beginner.json       # 内置课程：6 单元 × 4 课 × 8 题（入门话题）
└── sounds/correct.mp3, wrong.mp3      # 答题反馈音效
test/
├── progress_repository_test.dart      # 解锁逻辑单元测试
└── course_loader_test.dart            # 课程 JSON 解析测试
```

### 5.3 页面与交互细节

1. **学习路径页（首页）**
   - 垂直滚动路径，关卡为圆形节点，蛇形左右交错排列
   - 节点三态：已完成（金色 + 对勾）/ 当前可学（绿色高亮 + 弹跳动画）/ 锁定（灰色 + 锁图标）
   - 单元间有标题卡（单元名 + 简介）
   - 点击可学节点 → 进入答题页；点击锁定节点 → 抖动提示

2. **答题页**
   - 顶部进度条（第 n / N 题）+ 关闭按钮（弹确认退出）
   - 根据 Exercise 类型渲染对应题型组件
   - 底部判定栏：点击"检查"前为禁用态；答对显示绿色"太棒了！"+ 音效；答错显示红色 + 正确答案 + 音效
   - 答错的题目在末尾追加一次重做机会（多邻国机制）
   - 全部完成 → 结算页

3. **结算页**
   - 显示得分、正确率、用时
   - 正确率 ≥ 70% 标记完成并解锁下一课；否则提示重学

### 5.4 内置课程内容（course_beginner.json）

入门 6 个单元（每单元 4 课，每课约 8 题，共约 192 题）：
1. 问候与自我介绍（Hello / What's your name…）
2. 数字与时间
3. 家庭与人物
4. 食物与饮料
5. 颜色与物品
6. 日常动词（eat / go / like…）

每单元题型混合 4 种，词汇量循序渐进。

## 6. 实施步骤

1. `flutter create` 初始化项目，配置 `pubspec.yaml` 依赖与资源目录
2. 实现 `app/theme.dart` 多邻国风格主题与通用按钮组件
3. 实现数据层：模型 → JSON 解析 → Hive 存储 → 仓库层与解锁逻辑
4. 编写内置课程 JSON 种子数据
5. 实现学习路径页（节点布局 + 三态渲染）
6. 实现答题页控制器（状态机）+ 4 种题型组件 + 判定栏 + 音效/TTS
7. 实现结算页并接通关卡解锁回写
8. 编写单元测试（解锁逻辑、JSON 解析）
9. 运行 `flutter analyze` 修复问题，真机/模拟器验证完整流程

## 7. 验证步骤（Verification）

1. `flutter pub get` 无错误
2. `flutter analyze` 无 error/warning
3. `flutter test` 全部通过（解锁边界：69% 不解锁 / 70% 解锁；单元末课解锁下一单元）
4. `flutter run` 在 Android 模拟器/真机手动验证：
   - 首页路径正确显示三态节点
   - 完成第 1 课（≥70%）后第 2 课解锁
   - 4 种题型均可作答、判定栏与音效正常、TTS 可发声
   - 答错题在末尾重做
   - 杀进程重进后进度保留（Hive 持久化生效）

## 8. 明确的非目标（Out of Scope）

- 账号系统、云端同步、任何后端服务
- 红心/XP/排行榜/成就等完整游戏化体系（仅保留判定反馈，为后续扩展预留结构）
- 间隔重复单词本、学习统计图表
- 语音识别跟读评分（flutter_tts 仅用于发音输出）
- iOS 适配（Flutter 代码天然可移植，但本次只验证 Android）
