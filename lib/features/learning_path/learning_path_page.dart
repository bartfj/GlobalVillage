import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/auth_controller.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../app/widgets/app_version_label.dart';
import '../../core/constants.dart';
import '../../data/models/course_track.dart';
import '../../data/repositories/user_repository.dart';
import '../feedback/feedback_dialog.dart';
import 'widgets/lesson_node.dart';
import 'widgets/main_menu_drawer.dart';
import 'widgets/unit_header.dart';
import 'widgets/course_selector.dart';

/// 首页：垂直学习路径
class LearningPathPage extends ConsumerStatefulWidget {
  const LearningPathPage({super.key});

  @override
  ConsumerState<LearningPathPage> createState() => _LearningPathPageState();
}

class _LearningPathPageState extends ConsumerState<LearningPathPage> {
  final _scroll = ScrollController();
  final _lessonKeys = <String, GlobalKey>{};
  final _unitKeys = <String, GlobalKey>{};
  String? _identity;
  String? _targetId;
  bool _targetVisible = true;
  int _generation = 0;

  GlobalKey _lessonKey(String id) =>
      _lessonKeys.putIfAbsent(id, () => GlobalKey());
  GlobalKey _unitKey(String id) => _unitKeys.putIfAbsent(id, () => GlobalKey());

  bool _guestPrompted = false;
  bool _localImportPrompted = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateVisibility);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybePromptGuestImport(ref.read(authProvider));
    });
  }

  void _updateVisibility() {
    final box = _lessonKeys[_targetId]?.currentContext?.findRenderObject();
    final viewport = _scroll.hasClients
        ? _scroll.position.viewportDimension
        : 0.0;
    if (box is! RenderBox || !box.hasSize || viewport <= 0) return;
    final scrollBox = Scrollable.of(
      _lessonKeys[_targetId]!.currentContext!,
    ).context.findRenderObject();
    if (scrollBox is! RenderBox) return;
    final top = box.localToGlobal(Offset.zero, ancestor: scrollBox).dy;
    final visible = top >= 0 && top + box.size.height <= viewport;
    if (mounted && visible != _targetVisible) {
      setState(() => _targetVisible = visible);
    }
  }

  void _locate(GlobalKey? key, {bool animate = true}) {
    final generation = _generation;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          generation != _generation ||
          key?.currentContext == null) {
        return;
      }
      await Scrollable.ensureVisible(
        key!.currentContext!,
        alignment: 0.25,
        duration: animate ? const Duration(milliseconds: 300) : Duration.zero,
      );
      if (mounted && generation == _generation) _updateVisibility();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _showDirectory(BuildContext context, WidgetRef ref) {
    final course = ref.read(courseProvider);
    final progress = ref.read(progressRepositoryProvider)!;
    final current = progress.currentLesson;
    final s = ref.read(stringsProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  s.unitDirectory,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final unit in course.units)
                      ListTile(
                        title: Text(unit.title),
                        leading: Icon(
                          unit.lessons.any((l) => l.id == current?.id)
                              ? Icons.my_location
                              : Icons.menu_book_outlined,
                        ),
                        subtitle: Text(
                          s.unitsProgress(
                            unit.lessons
                                .where((l) => progress.isLessonCompleted(l.id))
                                .length,
                            unit.lessons.length,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _locate(_unitKeys[unit.id]);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // 蛇形路径的水平偏移系数（相对可用宽度）
  static const _offsetPattern = [
    0.0,
    -0.22,
    -0.34,
    -0.22,
    0.0,
    0.22,
    0.34,
    0.22,
  ];

  /// 关于弹窗：展示软件版本等信息
  void _showAbout(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.school, color: AppColors.green, size: 32),
            ),
            const SizedBox(height: 12),
            Text('地球村', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            GestureDetector(
              onLongPress: () {
                Navigator.of(dialogContext).pop();
                _confirmSkipLesson(context, ref);
              },
              child: Text(
                '版本 $kAppVersion',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '闯关学习实用英语',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了', style: TextStyle(color: AppColors.green)),
          ),
        ],
      ),
    );
  }

  void _confirmSkipLesson(BuildContext context, WidgetRef ref) {
    final lesson = ref.read(progressRepositoryProvider)?.currentLesson;
    if (lesson == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('没有可跳过的关卡')));
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('跳过当前关卡？'),
        content: Text('将跳过「${lesson.title}」并解锁下一关。该关得分记为 0，之后仍可重新学习。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final skipped = await ref
                  .read(progressRepositoryProvider)
                  ?.skipCurrentLesson();
              if (skipped == null) return;
              ref.read(progressRevisionProvider.notifier).state++;
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已跳过「${skipped.title}」')),
                );
              }
            },
            child: const Text('确认跳过', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }

  /// 备份 / 恢复：同一对话框内导出备份码或粘贴恢复
  Future<void> _showBackupRestore(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authProvider);
    String? exportCode;
    String? exportHint;
    if (auth.isGuest) {
      exportHint = '游客数据不支持导出备份，请先注册账号。仍可粘贴备份码恢复其他账号。';
    } else {
      exportCode = await ref.read(backupServiceProvider).exportBackup();
      if (!context.mounted) return;
      if (exportCode == null) {
        exportHint = '备份失败：未找到当前账号。仍可粘贴备份码尝试恢复。';
      }
    }
    if (!context.mounted) return;

    final controller = TextEditingController();
    String? error;
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('备份 / 恢复', style: TextStyle(fontSize: 17)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '导出备份',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 6),
                if (exportCode case final code?) ...[
                  const Text(
                    '复制保存以下备份码，换设备时可在下方粘贴恢复。',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        code,
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: code));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('备份码已复制到剪贴板')),
                          );
                        }
                      },
                      child: const Text(
                        '复制备份码',
                        style: TextStyle(color: AppColors.green),
                      ),
                    ),
                  ),
                ] else
                  Text(
                    exportHint ?? '',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                const Text(
                  '恢复数据',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 6),
                const Text(
                  '粘贴备份码，恢复对应账号与学习进度（同名账号将被覆盖）。',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: '粘贴备份码',
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      error!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.red,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                if (data?.text != null) {
                  setState(() => controller.text = data!.text!);
                }
              },
              child: const Text('粘贴', style: TextStyle(color: AppColors.blue)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                '关闭',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () async {
                final result = await ref
                    .read(backupServiceProvider)
                    .importBackup(controller.text);
                if (!context.mounted) return;
                if (result != null) {
                  setState(() => error = result);
                  return;
                }
                final nickname = ref.read(userStoreProvider).currentSession!;
                await ref.read(authProvider.notifier).restoreSession(nickname);
                ref.read(selectedTrackProvider.notifier).reload();
                ref.read(progressRevisionProvider.notifier).state++;
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已恢复账号 $nickname 的数据')),
                  );
                }
              },
              child: const Text('恢复', style: TextStyle(color: AppColors.green)),
            ),
          ],
        ),
      ),
    );
  }

  /// 退出登录确认框
  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('退出当前账号？', style: TextStyle(fontSize: 17)),
        content: const Text(
          '退出后可切换其他账号或以游客身份学习，各账号进度互相保留。',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              '取消',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(authProvider.notifier).logout();
            },
            child: const Text('退出', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }

  /// 在线会话下发现本机还有未合并的游客或本地账号进度时，确认一次再上传。
  Future<void> _maybePromptGuestImport(AuthState next) async {
    if (!mounted) return;
    if (next.pendingImportFrom == UserRepository.guestKey && !_guestPrompted) {
      _guestPrompted = true;
      await _confirmImport(
        title: '导入本机学习进度？',
        message: '当前设备上的游客学习进度将与云端账号合并，多设备可接力学习。',
        sources: const [UserRepository.guestKey],
      );
      if (!mounted) return;
    }
    if (!next.isOnline || _localImportPrompted) return;
    final sources = ref.read(authProvider.notifier).localAccountsToImport();
    if (sources.isEmpty) return;
    _localImportPrompted = true;
    final names = sources.join('、');
    await _confirmImport(
      title: '导入本地账号的学习进度？',
      message: '本机本地账号「$names」的学习进度将与当前在线账号合并，多设备可接力学习。',
      sources: sources,
    );
  }

  Future<void> _confirmImport({
    required String title,
    required String message,
    required List<String> sources,
  }) async {
    final sync = ref.read(syncServiceProvider);
    if (sync == null) return;
    final import = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('不导入'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (import == true) {
      final toUserKey = ref.read(authProvider).userKey;
      if (toUserKey != null) {
        for (final from in sources) {
          await sync.copySlot(from, toUserKey);
        }
      }
    }
    await ref
        .read(authProvider.notifier)
        .finishPendingImport(imported: import == true, nicknames: sources);
    await sync.pullMergePush();
  }

  Future<void> _startNextCourse(WidgetRef ref, CourseTrack next) async {
    try {
      // 学习路径已基于全部课程渲染，这里直接用已加载结果。
      final courses = ref.read(allCoursesProvider).requireValue;
      if (!courses.any((c) => c.id == next.id)) {
        throw StateError('Missing course');
      }
      await ref.read(selectedTrackProvider.notifier).select(next);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(stringsProvider).courseSwitchFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 进度变化时自动刷新路径
    ref.watch(progressRevisionProvider);
    // 游客升级为在线账号：单次确认是否导入本机游客进度（§7.3）
    ref.listen(authProvider, (_, next) => _maybePromptGuestImport(next));
    final auth = ref.watch(authProvider);
    final s = ref.watch(stringsProvider);
    // 登出瞬间会话已空，provider 为 null；等路由 redirect，避免空断言
    if (!auth.hasSession) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final course = ref.watch(courseProvider);
    final progress = ref.watch(progressRepositoryProvider);
    if (progress == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final total = course.orderedLessons.length;
    final completed = course.orderedLessons
        .where((l) => progress.isLessonCompleted(l.id))
        .length;
    final current = progress.currentLesson;
    // 零基础全部完成后直接引导进入同语言的入门课程。
    final nextTrack = current == null
        ? CourseTrack.fromId(course.id).nextTrack
        : null;
    final target =
        current ??
        (course.orderedLessons.isEmpty ? null : course.orderedLessons.last);
    final identity = '${auth.userKey}|${course.id}';
    if (_identity != identity || _targetId != target?.id) {
      if (_identity != identity) {
        _lessonKeys.clear();
        _unitKeys.clear();
      }
      _identity = identity;
      _targetId = target?.id;
      _generation++;
      if (target != null) _locate(_lessonKey(target.id), animate: false);
    }

    return Scaffold(
      drawer: MainMenuDrawer(
        onBackupRestore: () {
          Navigator.of(context).pop();
          _showBackupRestore(context, ref);
        },
        onFeedback: () {
          Navigator.of(context).pop();
          showFeedbackDialog(context, ref);
        },
        onAbout: () {
          Navigator.of(context).pop();
          _showAbout(context, ref);
        },
        onLogout: () {
          Navigator.of(context).pop();
          _confirmLogout(context, ref);
        },
        onLogin: () {
          Navigator.of(context).pop();
          context.push('/login');
        },
      ),
      appBar: AppBar(
        title: InkWell(
          key: const ValueKey('course-selector'),
          onTap: () => showCourseSelector(context, ref),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  s.courseTitle(
                    course.language.shortLabel,
                    s.trackLabel(CourseTrack.fromId(course.id)),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt_rounded),
            tooltip: s.unitDirectory,
            onPressed: () => _showDirectory(context, ref),
          ),
          IconButton(
            icon: const Icon(
              Icons.military_tech_rounded,
              color: AppColors.goldDark,
            ),
            tooltip: s.statsBadges,
            onPressed: () => context.push('/badges'),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '$completed / $total',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.gold,
                ),
              ),
            ),
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (auth.isGuest) _GuestBanner(),
                for (final unit in course.units) ...[
                  KeyedSubtree(
                    key: _unitKey(unit.id),
                    child: UnitHeader(
                      title: unit.title,
                      description: unit.description,
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (var i = 0; i < unit.lessons.length; i++)
                    Builder(
                      builder: (context) {
                        final lesson = unit.lessons[i];
                        final offset =
                            _offsetPattern[i % _offsetPattern.length] *
                            (constraints.maxWidth - 40 - 72);
                        final status = progress.isLessonCompleted(lesson.id)
                            ? LessonNodeStatus.completed
                            : progress.isLessonUnlocked(lesson.id)
                            ? LessonNodeStatus.current
                            : LessonNodeStatus.locked;
                        return Padding(
                          key: _lessonKey(lesson.id),
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Transform.translate(
                            offset: Offset(offset, 0),
                            child: Align(
                              alignment: Alignment.center,
                              child: LessonNode(
                                key: ValueKey(lesson.id),
                                status: status,
                                title: lesson.title,
                                onStart: () =>
                                    context.push('/lesson/${lesson.id}'),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 12),
                ],
                const Center(child: AppVersionLabel()),
              ],
            ),
          );
        },
      ),
      floatingActionButton: target == null || _targetVisible
          ? null
          : FloatingActionButton.small(
              tooltip: s.backToCurrent,
              onPressed: () => _locate(_lessonKeys[target.id]),
              child: const Icon(Icons.my_location),
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.locked)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  current != null
                      ? s.lessonOrdinal(
                          course.orderedLessons.indexWhere(
                                (l) => l.id == current.id,
                              ) +
                              1,
                          current.title,
                        )
                      : nextTrack != null
                      ? s.starterDoneNext(s.trackLabel(nextTrack))
                      : s.pathAllDone,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: current != null
                    ? () => context.push('/lesson/${current.id}')
                    : nextTrack != null
                    ? () => _startNextCourse(ref, nextTrack)
                    : () => context.push('/review'),
                icon: Icon(
                  current == null && nextTrack == null
                      ? Icons.refresh
                      : Icons.arrow_forward,
                ),
                label: Text(
                  current != null
                      ? s.continueLearning
                      : nextTrack != null
                      ? s.startNextCourse(s.trackLabel(nextTrack))
                      : s.allCompletedReview,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 游客横幅：引导游客注册账号保存进度，登录/注册后自动消失
class _GuestBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GestureDetector(
        onTap: () => context.push('/login'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.greenLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.person_outline, color: AppColors.greenDark),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.guestBanner,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.greenDark,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.greenDark),
            ],
          ),
        ),
      ),
    );
  }
}
