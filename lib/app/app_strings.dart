import '../data/models/course_track.dart';
import '../data/models/learning_language.dart';
import '../data/models/skill_practice.dart';

/// 界面语言。与学习语言、解释语言是三个不同概念（设计文档 12.1）。
enum UiLanguage { chinese, english }

/// 应用界面字符串表：中文为默认，英文面向中文课程的外国学习者。
///
/// 覆盖范围（第一阶段）：侧栏、学习路径页、课时流程、专项练习页、
/// 中文/梵文课程会用到的题型组件。复习、账号、备份、庆祝演出等
/// 边缘页面暂未本地化，仍以中文显示。
class S {
  const S(this.language);

  final UiLanguage language;

  bool get isEn => language == UiLanguage.english;

  // ---- 通用 ----
  String get check => isEn ? 'Check' : '检查';
  String get continueLabel => isEn ? 'Continue' : '继续';
  String get done => isEn ? 'Done' : '完成';
  String get back => isEn ? 'Back' : '返回';
  String get exit => isEn ? 'Quit' : '退出';
  String get retrySave => isEn ? 'Retry' : '重试保存';
  String get exitPracticeTitle => isEn ? 'Quit practice?' : '退出练习？';
  String get exitPracticeBody =>
      isEn ? 'Progress of this session will not be saved.' : '本次练习的进度将不会保存。';
  String get keepPracticing => isEn ? 'Keep practicing' : '继续练习';
  String get recordSaveFailed =>
      isEn ? 'Failed to save learning record. Please try again later.' : '学习记录保存失败，请稍后重试。';
  String get quitPractice => isEn ? 'Quit practice' : '退出练习';
  String get questionsDone => isEn ? 'Questions completed' : '已完成题数';
  String get lessonNotFound => isEn ? 'Lesson not found' : '课程不存在';

  // ---- 侧栏 ----
  String get guest => isEn ? 'Guest' : '游客';
  String get onlineUser => isEn ? 'Online user' : '在线用户';
  String get notLoggedIn => isEn ? 'Not signed in' : '未登录';
  String get chipGuest => isEn ? 'Guest mode' : '游客模式';
  String get chipOnline => isEn ? 'Online account' : '在线账号';
  String get chipLocal => isEn ? 'Local account' : '本地账号';
  String get registerLoginCta =>
      isEn ? 'Sign up / sign in to save progress' : '注册 / 登录保存进度';
  String get bindOnlineCta =>
      isEn ? 'Bind an online account to sync devices' : '绑定在线账号，多设备同步';
  String get statsCompleted => isEn ? 'Completed' : '已通关';
  String get statsTree => isEn ? 'Saxaul trees' : '梭梭树';
  String get statsBadges => isEn ? 'Badges' : '徽章';
  String get sectionCourses => isEn ? 'Courses' : '系统课程';
  String get sectionPractice => isEn ? 'Skill practice' : '专项练习';
  String get sanskritAudioTitle => isEn ? 'Sanskrit pronunciation' : '梵文发音';
  String get sanskritAudioSubtitle =>
      isEn ? 'Reference recordings · offline listening' : '参考录音 · 可离线听读';
  String get sectionMore => isEn ? 'More' : '更多';
  String get reviewRecords => isEn ? 'Review & records' : '复习与学习记录';
  String get backupRestore => isEn ? 'Backup / Restore' : '备份 / 恢复';
  String get about => isEn ? 'About' : '关于';
  String get logoutSwitch => isEn ? 'Sign out / Switch account' : '退出登录 / 切换账号';
  String get switchCourse => isEn ? 'Switch' : '切换';
  String get syncNow => isEn ? 'Syncing…' : '同步中…';
  String get syncFailed => isEn ? 'Sync failed, try again later' : '同步失败，稍后再试';
  String get syncWaiting => isEn ? 'Waiting for first sync' : '等待首次同步';
  String syncLastAt(String time) => isEn ? 'Synced $time' : '上次同步 $time';
  String completedCount(int done, int total) =>
      isEn ? '$done/$total completed' : '已通关 $done/$total';
  String get serverUrl => isEn ? 'Server' : '服务地址';
  String get feedbackRow => isEn ? 'Send feedback' : '反馈问题';

  // ---- 语言与课程选择 ----
  String get chooseLanguageTitle => isEn ? 'Learning language' : '学习语言';
  String get courseSwitchFailed =>
      isEn ? 'Failed to switch course. Please try again.' : '课程切换失败，请重试。';
  String languageLabel(LearningLanguage language) {
    if (!isEn) return language.label;
    switch (language) {
      case LearningLanguage.english:
        return 'English';
      case LearningLanguage.chinese:
        return 'Chinese 中文';
      case LearningLanguage.sanskrit:
        return 'Sanskrit';
    }
  }

  String trackLabel(CourseTrack track) {
    if (!isEn) return track.label;
    switch (track) {
      case CourseTrack.zero:
        return 'Starter';
      case CourseTrack.beginner:
        return 'Beginner';
      case CourseTrack.intermediate:
        return 'Intermediate';
      case CourseTrack.chineseZero:
        return 'Chinese Starter';
      case CourseTrack.chinese:
        return 'Mandarin Intro';
      case CourseTrack.sanskritZero:
        return 'Sanskrit Starter';
      case CourseTrack.sanskrit:
        return 'Sanskrit Intro';
    }
  }

  // ---- 学习路径页 ----
  String get unitDirectory => isEn ? 'Units' : '单元目录';
  String unitsProgress(int done, int total) =>
      isEn ? '$done / $total completed' : '$done / $total 已完成';
  String get continueLearning => isEn ? 'Continue' : '继续学习';
  String get backToCurrent => isEn ? 'Current lesson' : '回到当前课';
  String get allCompletedReview => isEn ? 'Review' : '复习';
  String get pathAllDone => isEn ? 'All done' : '全部完成';
  String starterDoneNext(String next) =>
      isEn ? 'Starter course complete · Next: $next' : '零基础课程已完成 · 接下来学$next';
  String startNextCourse(String next) => isEn ? 'Start $next' : '进入$next';
  String lessonOrdinal(int n, String title) =>
      isEn ? 'Lesson $n · $title' : '第$n节 · $title';
  String get guestBanner => isEn
      ? 'Learning as guest · sign up to save progress'
      : '以游客身份学习中 · 注册账号保存进度';

  // ---- 课时流程 ----
  String get practiceDone => isEn ? 'Practice complete' : '练习完成';
  String firstCorrect(int correct, int total) =>
      isEn ? 'First-try correct $correct / $total' : '首次答对 $correct / $total';
  String get correct => isEn ? 'Correct!' : '回答正确！';
  String get reviewThis => isEn ? 'Remember this one' : '再记一下这句话';
  String get skippedNoCredit => isEn ? 'Skipped (no credit)' : '已跳过（不计分）';

  // ---- 课前学习卡 ----
  String get studyCardHint =>
      isEn ? 'Read this first, then start' : '先看本课内容，再开始练习';
  String get startPractice => isEn ? 'Start' : '开始练习';
  String get playPronunciation => isEn ? 'Play pronunciation' : '播放发音';
  String audioPlaybackFailed(LearningLanguage language) {
    final name = language == LearningLanguage.chinese ? '中文' : '英文';
    return isEn
        ? 'Audio playback failed. Check the ${language == LearningLanguage.chinese ? 'Chinese' : 'English'} voice data and media volume, then try again.'
        : '语音播放失败，请检查系统$name语音包与媒体音量后重试。';
  }

  // ---- 题型组件 ----
  String get translatePractice => isEn ? 'Translation' : '翻译练习';
  String get chooseCorrectTranslation =>
      isEn ? 'Choose the correct translation' : '选择正确的翻译';
  String translationDirection(bool sourceIsEnglish) => isEn
      ? (sourceIsEnglish ? 'English → Chinese' : 'Chinese → English')
      : (sourceIsEnglish ? '英文 → 中文' : '中文 → 英文');
  String get arrangeBlocks =>
      isEn ? 'Arrange the blocks into a sentence' : '把词块排成句子';
  String get wordBankHint => isEn
      ? 'Long-press a block to drag and reorder'
      : '长按词块可拖动调整顺序；词库词块长按可查看音标';
  String get scriptLabelsHanzi => isEn ? 'Hanzi / Pinyin' : '汉字 / 拼音';
  String get scriptLabelsIast => isEn ? 'IAST / Devanagari' : 'IAST / 天城体';
  String get pinyinKeyboardHint =>
      isEn ? 'Tone numbers work too: ma4 = mà, lv = lü' : '拼音可用数字声调：ma4 = mà，lv = lü';
  String get iastKeyboardHint =>
      isEn ? 'Keyboard aliases work too: aa = ā, R = ṛ, T = ṭ, H = ḥ' : '也可用键盘打法：aa = ā，R = ṛ，T = ṭ，H = ḥ';

  // ---- 结果页 ----
  String get lessonPassed => isEn ? 'Lesson complete!' : '课程完成！';
  String get lessonFailed => isEn ? 'One more try!' : '再练一次吧！';
  String get nextUnlocked => isEn ? 'Next lesson unlocked' : '下一课已解锁';
  String get passThresholdHint =>
      isEn ? 'Reach 70% to unlock the next lesson' : '正确率达到 70% 即可解锁下一课';
  String get scoreLabel => isEn ? 'Score' : '得分';
  String get accuracyLabel => isEn ? 'Accuracy' : '正确率';
  String get timeLabel => isEn ? 'Time' : '用时';
  String minutesSeconds(int m, int s) => isEn ? '${m}m ${s}s' : '$m分$s秒';
  String get replayDialogue => isEn ? 'Replay dialogue' : '重播对话';
  String get relearn => isEn ? 'Learn again' : '重新学习';
  String get backToPath => isEn ? 'Back to path' : '返回学习路径';
  String get saveFailed => isEn ? 'Save failed, please retry' : '保存失败，请重试';
  String badgeEarned(String title, bool newly) => isEn
      ? '$title badge ${newly ? '+1' : 'collected'}'
      : '$title徽章 ${newly ? '+1' : '已领取'}';
  String badgeTotal(int count) =>
      isEn ? 'Total $count for this lesson' : '本关累计 $count 枚';
  String treePlusOne(int count) =>
      isEn ? 'Saxaul +1 · total $count' : '梭梭树 +1 · 累计 $count 棵';

  // ---- 专项练习 ----
  String get bankEmpty => isEn ? 'Practice bank is empty' : '题库为空';
  String get cannotStart => isEn ? 'Unable to start practice' : '无法开始练习';
  String get speakingTip =>
      isEn ? 'Tip: say it out loud' : '提示：尽量大声说出来';
  String get pronunciationTip => isEn
      ? 'Listen, then repeat; watch the similarity score'
      : '听原音后跟读，注意语音相似度';

  String skillTitle(SkillPracticeKind kind) {
    if (!isEn) return kind.title;
    switch (kind) {
      case SkillPracticeKind.pronunciation:
        return 'Pronunciation';
      case SkillPracticeKind.vocabulary:
        return 'Vocabulary';
      case SkillPracticeKind.speaking:
        return 'Speaking';
      case SkillPracticeKind.englishYoga:
        return 'Yoga English';
      case SkillPracticeKind.chineseTones:
        return 'Tones';
      case SkillPracticeKind.chineseCharacters:
        return 'Characters';
      case SkillPracticeKind.sanskritLetters:
        return 'Devanagari';
      case SkillPracticeKind.sanskritVowels:
        return 'Vowel length';
      case SkillPracticeKind.sanskritYoga:
        return 'Yoga Sanskrit';
    }
  }

  String skillSubtitle(SkillPracticeKind kind) {
    if (!isEn) return kind.subtitle;
    switch (kind) {
      case SkillPracticeKind.pronunciation:
        return 'Listen closely, then repeat';
      case SkillPracticeKind.vocabulary:
        return 'Meanings, spelling and usage';
      case SkillPracticeKind.speaking:
        return 'Say it out loud, controlled output';
      case SkillPracticeKind.englishYoga:
        return 'Understand class terms and cues';
      case SkillPracticeKind.chineseTones:
        return 'Four tones, pick the right mark';
      case SkillPracticeKind.chineseCharacters:
        return 'Read characters, know meanings';
      case SkillPracticeKind.sanskritLetters:
        return 'Read Devanagari letters and syllables';
      case SkillPracticeKind.sanskritVowels:
        return 'Tell short and long vowels apart';
      case SkillPracticeKind.sanskritYoga:
        return 'Read common yoga terms from class';
    }
  }

  String skillDoneTitle(SkillPracticeKind kind) =>
      isEn ? '${skillTitle(kind)} complete' : kind.doneTitle;

  // ---- 界面语言设置 ----
  String get uiLanguageSuggestionTitle =>
      isEn ? 'English interface on' : '界面已切换为英文';
  String get uiLanguageSuggestionBody => isEn
      ? 'Chinese courses are explained in English, so the app switched to English. You can keep it or switch back to Chinese; change this anytime under More → Interface language.'
      : '中文课程用英语讲解，界面已随之切换为英文。可以保留英文，或切回中文；之后可在“更多 → 界面语言”中修改。';
  String get uiLanguageSwitch => isEn ? 'Switch to Chinese' : '切回中文';
  String get uiLanguageKeep => isEn ? 'Keep English' : '保持英文';
  String get uiLanguageRowTitle => isEn ? 'Interface language' : '界面语言';
  String get uiLanguageAuto => isEn ? 'Auto (follow course)' : '自动（跟随课程）';
}
