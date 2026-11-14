# 课后趣味短剧接入实施计划

**Goal:** 将已完成的十二段动画短剧实际内置于 Android 应用，覆盖零基础、初级、中级和母句型课程的通关入口，交付可安装、已校验和已共享的 0.8.53+70。

**Architecture:** 保留现有计分内容和奖励服务。新增独立短剧内容与播放器，Android 通过受控本地 WebView 播放已经制作的角色、道具、分镜和内嵌音频；Flutter 负责进入、退出、错误恢复和结果页衔接。其他平台提供字幕播放的可操作兜底。

**Spec:** 本轮用户“完整交付”以及已经选定的全年龄短喜剧、剧情反转、人物动作与表情；已有研究稿 `docs/research/2026-11-14-post-lesson-comedy-samples.md` 提供十二段对白与分镜。

## Global Constraints

- 四类英语课程每次成功通关并保存结果和奖励后均可观看短剧；重复闯关及结果页重播也可观看。
- 十二段按课程等级推荐，有准确课时对应时优先选择对应段落；未逐课创作新剧本，界面称“课后趣味短剧”，不称“本课专属短剧”。
- 不改课程 JSON、题目、成绩、70% 门槛、奖励算法和已保存进度；不重写用于计分练习的 `unit_dialogues.json`。
- 母句型正式课接入，复习、教学练习、未通关和保存失败不触发；中文与梵文课程保持现有流程。
- 对话、人物动作、表情、道具和音频离线内置；暂停、切换、退出、后台、销毁须取消旧音频和计时器。
- 无网络加载、无任意脚本注入、无开放外部导航；只运行应用自带内容。
- 支持 320px、小屏、大字体、深色、减少动画；英文界面字符串接入 `S`。
- 使用现有隔离工作区；不修改主工作区用户已有 Gradle wrapper 等文件。不主动 push 或 merge。
- 实际版本 0.8.53+70；若主仓库版本更高，按既有规则递增。使用既有正式升级签名；文件名含版本及构建号；保留历史安装包。

### Task 1: 独立内置内容与播放器

**Files:**
- Create: `lib/features/post_lesson_comedy/comedy_catalog.dart`
- Create: `lib/features/post_lesson_comedy/post_lesson_comedy.dart`
- Create: `assets/dialogues/post_lesson_comedy.html`
- Create: `assets/dialogues/post_lesson_comedy_catalog.json`
- Create: `android/app/src/main/kotlin/com/example/english_village/ComedyViewFactory.kt`
- Modify: `android/app/src/main/kotlin/com/example/english_village/MainActivity.kt`
- Test: `test/post_lesson_comedy_test.dart`
- Create: `tools/validate_post_lesson_comedy.py`

**Interfaces:**
```dart
class ComedyEpisode {
  final String id, courseId, lessonId, title;
}
class ComedyCatalog {
  final List<ComedyEpisode> episodes;
  static Future<ComedyCatalog> load();
  ComedyEpisode? recommend(String courseId, String lessonId);
}
class PostLessonComedy extends StatefulWidget {
  const PostLessonComedy({super.key, required this.courseId,
    required this.lessonId, required this.strings, required this.onFinished});
  final String courseId, lessonId;
  final S strings;
  final VoidCallback onFinished;
}
```

- [ ] 写行为测试，首次运行应因接口缺失失败。测试精确课时推荐、四类英语课均可推荐、非英语无推荐；播放器能跳过、重播和停止，不操作奖励服务。
- [ ] 将既有试播（外部研究源路径见任务简报）中的十二段动画与内嵌音频转成应用独立离线 HTML，去掉 Codex host API。保留 71 句字幕、62 条录音和修订后的分镜。
- [ ] HTML 对接明确的本地控制接口。只接收目录中有效场景 ID、布尔语言/减少动画状态；发送 ready/completed/error 状态。进入默认推荐场景，可切换其他短剧，手动播放；正常进入自动播放。中文字幕可开关。
- [ ] Native WebView 仅加载打包资源，禁止网络请求和外部导航，销毁时停止音频、清空桥接、destroy；页面隐藏时暂停，恢复后由用户继续。
- [ ] Flutter 外壳显示加载、播放错误和跳过； Android 平台视图有初始化超时，后台暂停，退出幂等。其他平台保留字幕和手动逐句控制；测试不依赖真实 WebView。
- [ ] 校验工具读取实际 HTML/catalog，验证课程/课时引用、十二段及 71 句、内嵌音频存在且解码非静音、无 host API 或远程依赖。
- [ ] 运行该任务测试与内容校验，提交只属于本任务的文件并写报告。

### Task 2: 结果页接入与回归

**Files:**
- Modify: `lib/features/lesson/result_page.dart`
- Modify: `lib/features/mother_pattern/mother_pattern_page.dart`
- Modify: `lib/app/app_strings.dart`
- Test: `test/post_lesson_comedy_entry_test.dart`
- Modify relevant existing result/page tests only where changed behavior requires it.

**Interfaces:** 消费任务 1 的 `PostLessonComedy`，传入实际课程 ID、课时 ID、当前字符串和继续奖励的回调。

- [ ] 测试普通英语结果页在两次保存成功后才显示短剧，保存失败/未通过不显示，重播可见且不再次调用奖励服务。
- [ ] 测试母句型正式课成功显示短剧，关闭后进入原奖励；复习、练习及保存失败不显示；账号切换能销毁当前播放。
- [ ] 普通课结果页用独立短剧替换旧观看挂接，保留旧计分对话和资源；重播按钮对每次已保存英语通关开放。
- [ ] 母句型页正式课奖项产生时先显示短剧，再显示原奖励；结果页增加重播入口，调用同一播放器，不再次保存。
- [ ] 新增 `S` 的短剧标题、观看/重播、跳过/继续、加载失败、重试、背景暂停、播放/暂停、字幕相关中英文文案。
- [ ] 运行客户端分析、完整测试和服务端既有内容测试，修复相关回归；检查课程 JSON 无变更。

### Task 3: 版本与安装包完整交付

**Files:**
- Modify: `pubspec.yaml`, `lib/core/constants.dart`, appropriate version record.
- Create: `docs/releases/2026-11-14-post-lesson-comedy-0.8.53.md`
- Update existing local ignored release/share helpers and QR assets after verification.

- [ ] 更新实际版本并核对主工作区版本基线；构建当前工作区代码，使用已验证离线 Gradle 工具和低并行配置。
- [ ] 核对 APK manifest、v2 签名和升级证书、CRC、母句型原资源、十二段短剧 HTML/catalog 实际入包哈希；记录 SHA256。
- [ ] 用独立 Playwright 对打包 HTML 验证逐句播放/暂停/切换/重播、后台暂停、退出停止、离线音频、小屏/大字体与错误状态；有连接设备时执行 Android 安装和实际 WebView 检查。
- [ ] 仅在验证成功后以 `earthvillage-0.8.53+70.apk` 发布到既有局域网共享，原子更新 latest，两条 IP 完整 GET 哈希验证，更新二维码。
- [ ] 清楚列出实体设备未完成验证，给出安装链接和应用内验证路线；报告内容覆盖为已接入十二段短剧，不宣称 584 段独有对白。
