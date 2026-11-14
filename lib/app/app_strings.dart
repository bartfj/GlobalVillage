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

  String get comedyTitle => isEn ? 'After-lesson comedy' : '课后趣味短剧';
  String get comedySkip => isEn ? 'Skip comedy' : '跳过短剧';
  String get comedyContinue => isEn ? 'Continue' : '继续';
  String get comedyLoading => isEn ? 'Loading comedy…' : '正在准备短剧…';
  String get comedyLoadFailed =>
      isEn ? 'Could not play this comedy' : '短剧暂时无法播放';
  String get comedyRetry => isEn ? 'Try again' : '重试播放';
  String get comedyReplay => isEn ? 'Watch comedy again' : '重看趣味短剧';
  String get comedyPlay => isEn ? 'Play' : '播放';
  String get comedyPause => isEn ? 'Pause' : '暂停';
  String get comedySubtitles => isEn ? 'Chinese subtitles' : '中文字幕';
  String get comedyBackgroundPaused =>
      isEn ? 'Paused; tap Play to continue' : '已暂停，点击播放继续';
  String get comedyNextLine => isEn ? 'Next line' : '下一句';
  String get comedyPreviousLine => isEn ? 'Previous line' : '上一句';

  String get motherPatternTitle => isEn ? 'Mother Pattern English' : '母句型英语';
  String get motherPatternDialogue => isEn ? 'Dialogue' : '生活对话';
  String get motherPatternVocabulary => isEn ? 'Words and phrases' : '本课词汇与短语';
  String get motherPatternRules => isEn ? 'How to use the expression' : '用法与限制';
  String get motherPatternExamples => isEn ? 'Listen to the examples' : '听范句';
  String get motherPatternListening =>
      isEn ? 'Understand the expression' : '听懂表达';
  String get motherPatternChunks => isEn ? 'Build the expression' : '词块组句';
  String get motherPatternRepeat => isEn ? 'Repeat with the model' : '看句跟读';
  String get motherPatternIndependentTitle =>
      isEn ? 'Independent expression' : '独立表达';
  String get motherPatternRecord => isEn ? 'Record your expression' : '录下你的表达';
  String get motherPatternStop => isEn ? 'Finish recording' : '结束录音';
  String get motherPatternRecognizing =>
      isEn ? 'Recognizing locally…' : '正在离线识别…';
  String get motherPatternReady => isEn
      ? 'Speech recognized. Submit to see the transcript.'
      : '已识别，提交后查看转写。';
  String get motherPatternRecallHint => isEn ? 'Recall support' : '回忆提示';
  String get motherPatternSafeHint => isEn
      ? 'Think of the meaning first, then recall the expression you learned. Check the speaker, object and quantity.'
      : '先想清楚要表达的意思，再回忆学过的说法。检查说话者、对象和数量。';
  String get motherPatternPreparing =>
      isEn ? 'Preparing microphone…' : '正在准备麦克风…';
  String get motherPatternDenied => isEn
      ? 'Allow microphone access and retry, or use typed fallback.'
      : '请允许麦克风后重试，或使用键盘替代。';
  String get motherPatternEmpty =>
      isEn ? 'No clear speech heard. Please retry.' : '没有听到清晰语音，请重试。';
  String get motherPatternSpeechError =>
      isEn ? 'Speech recognition failed. Please retry.' : '语音识别失败，请重试。';
  String get motherPatternTypedFallback =>
      isEn ? 'Use typed fallback' : '使用键盘替代';
  String get motherPatternFallbackUsed =>
      isEn ? 'Typed fallback · not a spoken success' : '键盘替代 · 不计入口语成功';
  String get motherPatternRetrySpeech => isEn ? 'Record again' : '重新录音';
  String get motherPatternSaving => isEn ? 'Saving results…' : '正在保存结果…';
  String get motherPatternDueSaved => isEn ? 'Due review recorded' : '到期复习已记录';
  String get motherPatternPracticeSaved => isEn
      ? 'Extra practice recorded · review date unchanged'
      : '额外练习已记录 · 复习日期未推进';
  String get motherPatternStaleSaved => isEn
      ? 'Practice recorded · this review was no longer due'
      : '练习已记录 · 原复习计划已失效';
  String get motherPatternDialogueSaved =>
      isEn ? 'Dialogue practice recorded' : '对话综合练习已记录';
  String get motherPatternNoRecord => isEn
      ? 'Lesson completed · no expression training record'
      : '课程已完成 · 暂无表达训练记录';
  String get motherPatternLearned => isEn ? 'Learned expressions' : '已学表达';
  String get motherPatternNoLearned => isEn
      ? 'Complete a Mother Pattern lesson to see it here.'
      : '完成母句型课程后，可在这里查看已学表达。';
  String get motherPatternReview => isEn ? 'Two new situations' : '两个新场景';
  String get motherPatternRefresher =>
      isEn ? 'Full refresher · no course rewards' : '完整复训 · 不发课程奖励';
  String get motherPatternDueContext =>
      isEn ? 'Latest: due review' : '最近一次：到期复习';
  String get motherPatternPracticeContext =>
      isEn ? 'Latest: extra practice' : '最近一次：额外练习';
  String get motherPatternStaleContext =>
      isEn ? 'Latest: practice after review changed' : '最近一次：计划变更后的练习';
  String get motherPatternLearningContext =>
      isEn ? 'Latest: full training' : '最近一次：完整训练';
  String get motherPatternDialogueContext =>
      isEn ? 'Latest: dialogue practice' : '最近一次：对话综合练习';
  String motherPatternCorrection(int ordinal) =>
      isEn ? 'Correction · question $ordinal' : '订正练习 · 第 $ordinal 题';
  String motherPatternIndependent(int correct, int total) => isEn
      ? 'Independent first answers $correct / $total'
      : '独立首答 $correct / $total';
  String motherPatternSpoken(int correct) =>
      isEn ? 'Spoken first answers $correct' : '口语首答 $correct';
  String motherPatternTyped(int correct) =>
      isEn ? 'Typed recall first answers $correct' : '键盘脱稿首答 $correct';
  String motherPatternFallback(int correct) =>
      isEn ? 'Typed fallback first answers $correct' : '键盘替代首答 $correct';

  // ---- 母句型训练 ----
  String get patternStudy => isEn ? 'Learn a sentence frame' : '认识本课母句型';
  String get patternPractice =>
      isEn ? 'Practice this sentence frame' : '练习本课母句型';
  String get patternTitle => isEn ? 'Sentence frame practice' : '母句型练习';
  String get patternReviewTitle => isEn ? 'Sentence frame review' : '母句型复习';
  String get patternStartLesson => isEn ? 'Start lesson' : '开始闯关';
  String get patternSubstitution => isEn ? 'Change the content' : '替换内容';
  String get patternRecall => isEn ? 'Recall the expression' : '脱稿表达';
  String get patternTransfer => isEn ? 'Use it in a new situation' : '换场景表达';
  String get patternShowHint => isEn ? 'Show frame and example' : '看句型和范句';
  String get patternHintUsed =>
      isEn ? 'Hint used · keep practising recall' : '已使用提示 · 继续练习回忆';
  String get patternTryFrame =>
      isEn ? 'Try the target frame. One reference answer:' : '再试试本课句型。参考表达：';
  String get patternCompleted => isEn ? 'Practice recorded' : '本次训练已记录';
  String get patternToday => isEn ? 'Sentence frames due today' : '今日母句型';
  String get patternLearned =>
      isEn ? 'Sentence frames from completed lessons' : '已学课程的母句型';
  String get patternNoDue => isEn ? 'No sentence frames due today' : '暂无到期母句型';
  String get patternNoLessons => isEn
      ? 'Complete a pilot lesson to practise its frame'
      : '完成试点课后，可以在这里练习母句型';
  String get patternNotStarted => isEn ? 'Not yet practised' : '尚未练习';
  String get patternUnavailable => isEn
      ? 'This practice is unavailable in the current account or course.'
      : '当前账号或课程无法继续这次练习。';
  String get patternAnswerHint =>
      isEn ? 'Type your English expression' : '输入你的英文表达';
  String get clearLearningRecordsBody => isEn
      ? 'Wrong answers, sentence frame reviews and statistics will be cleared. Course results and rewards are kept.'
      : '错题、母句型复习与统计将被清除，课程成绩和奖励不受影响。';
  String patternCount(int current, int total) =>
      isEn ? '$current / $total questions' : '$current / $total 题';
  String patternHints(int count) =>
      isEn ? 'Questions with hints: $count' : '使用提示 $count 题';
  String patternNextReview(DateTime due) {
    final local = due.toLocal();
    final date =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    return isEn ? 'Next review: $date' : '下次复习：$date';
  }

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
  String get recordSaveFailed => isEn
      ? 'Failed to save learning record. Please try again later.'
      : '学习记录保存失败，请稍后重试。';
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
  String get navPath => isEn ? 'Path' : '路径';
  String get navPractice => isEn ? 'Practice' : '练习';
  String get navCompleted => isEn ? 'Done' : '已完成';
  String get navAccount => isEn ? 'Account' : '账号';
  String get navTree => isEn ? 'Tree' : '梭梭树';
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
    if (track == CourseTrack.motherPattern) {
      return isEn ? 'Mother Pattern English' : '母句型英语';
    }
    if (!isEn) return track.label;
    switch (track) {
      case CourseTrack.zero:
        return 'Starter';
      case CourseTrack.beginner:
        return 'Beginner';
      case CourseTrack.motherPattern:
        return 'Mother Pattern English';
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
  String get pinyinKeyboardHint => isEn
      ? 'Tone numbers work too: ma4 = mà, lv = lü'
      : '拼音可用数字声调：ma4 = mà，lv = lü';
  String get iastKeyboardHint => isEn
      ? 'Keyboard aliases work too: aa = ā, R = ṛ, T = ṭ, H = ḥ'
      : '也可用键盘打法：aa = ā，R = ṛ，T = ṭ，H = ḥ';

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
  String get speakingTip => isEn ? 'Tip: say it out loud' : '提示：尽量大声说出来';
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

  String get practiceChaptersTitle => isEn ? 'Chapters' : '章节';
  String get practiceChapterLocked => isEn
      ? 'Complete the previous chapter (≥80%) to unlock'
      : '完成上一章（正确率 ≥ 80%）后解锁';
  String get practiceChapterPassed => isEn ? 'Passed' : '已完成';
  String get practiceRetryChapter => isEn ? 'Retry chapter' : '再练本章';
  String get practiceNextChapter => isEn ? 'Next chapter' : '去下一章';
  String get practiceBackToChapters => isEn ? 'Back to chapters' : '返回章节';
  String practiceAccuracy(int percent) =>
      isEn ? 'Accuracy $percent%' : '正确率 $percent%';
  String practiceBestAccuracy(int percent) =>
      isEn ? 'Best $percent%' : '最高 $percent%';
  String practiceUnlockHint(bool passed) => passed
      ? (isEn ? 'Chapter passed. Next chapter unlocked.' : '本章达标，已解锁下一章。')
      : (isEn ? 'Need ≥80% to pass this chapter.' : '正确率需 ≥ 80% 才算完成本章。');

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
