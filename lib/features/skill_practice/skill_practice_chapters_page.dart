import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/models/skill_practice.dart';
import '../../data/models/skill_practice_progress.dart';
import '../../data/sources/skill_practice_loader.dart';
import '../lesson/widgets/lesson_style.dart';
import 'skill_practice_style.dart';

/// 专项练习章节地图：软解锁 + 跳练已解锁章
class SkillPracticeChaptersPage extends ConsumerStatefulWidget {
  const SkillPracticeChaptersPage({
    super.key,
    required this.skill,
    this.loader,
  });

  final SkillPracticeKind skill;
  final SkillPracticeLoader? loader;

  @override
  ConsumerState<SkillPracticeChaptersPage> createState() =>
      _SkillPracticeChaptersPageState();
}

class _SkillPracticeChaptersPageState
    extends ConsumerState<SkillPracticeChaptersPage> {
  SkillPracticeBank? _bank;
  Object? _loadError;
  bool _loading = true;

  Color get _accent => widget.skill.accent;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBank());
  }

  Future<void> _loadBank() async {
    final loader =
        widget.loader ??
        SkillPracticeLoader(
          documents: await ref.read(contentCacheProvider.future),
        );
    try {
      final bank = await loader.load(widget.skill);
      if (!mounted) return;
      setState(() {
        _bank = bank;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(skillPracticeProgressRevisionProvider);
    final s = ref.watch(stringsProvider);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_loadError != null || _bank == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.skillTitle(widget.skill))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _loadError?.toString() ?? s.cannotStart,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.pop(),
                  child: Text(s.back),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bank = _bank!;
    final progressStore = ref.watch(skillPracticeProgressStoreProvider);
    final progressMap =
        progressStore?.forSkill(widget.skill.name) ??
        const <String, SkillPracticeChapterProgress>{};
    final completedFlags = [
      for (final chapter in bank.chapters)
        progressMap[chapter.id]?.completed ?? false,
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.pop(),
                  ),
                  Icon(widget.skill.icon, color: _accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.skillTitle(widget.skill),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          s.skillSubtitle(widget.skill),
                          style: const TextStyle(
                            fontSize: 13,
                            color: LessonColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                s.practiceChaptersTitle,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _accent,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: bank.chapters.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final chapter = bank.chapters[index];
                  final status = skillPracticeChapterStatus(
                    index: index,
                    chapterCompletedFlags: completedFlags,
                  );
                  final progress = progressMap[chapter.id];
                  return _ChapterTile(
                    accent: _accent,
                    index: index,
                    chapter: chapter,
                    status: status,
                    lockedHint: s.practiceChapterLocked,
                    passedLabel: s.practiceChapterPassed,
                    bestLabel: progress == null
                        ? null
                        : s.practiceBestAccuracy(
                            (progress.bestAccuracy * 100).round(),
                          ),
                    onTap: status == SkillPracticeChapterStatus.locked
                        ? null
                        : () => context.push(
                              '/practice/${widget.skill.name}/${chapter.id}',
                            ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({
    required this.accent,
    required this.index,
    required this.chapter,
    required this.status,
    required this.lockedHint,
    required this.passedLabel,
    required this.bestLabel,
    required this.onTap,
  });

  final Color accent;
  final int index;
  final SkillPracticeChapter chapter;
  final SkillPracticeChapterStatus status;
  final String lockedHint;
  final String passedLabel;
  final String? bestLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final locked = status == SkillPracticeChapterStatus.locked;
    final completed = status == SkillPracticeChapterStatus.completed;
    final borderColor = locked
        ? LessonColors.track
        : completed
        ? AppColors.green
        : accent;

    return Material(
      color: locked ? LessonColors.track.withValues(alpha: 0.35) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: locked
                      ? LessonColors.muted.withValues(alpha: 0.15)
                      : accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: locked
                    ? const Icon(
                        Icons.lock_rounded,
                        size: 20,
                        color: LessonColors.muted,
                      )
                    : completed
                    ? const Icon(
                        Icons.check_rounded,
                        size: 22,
                        color: AppColors.green,
                      )
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chapter.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: locked
                            ? LessonColors.muted
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (chapter.subtitle != null &&
                        chapter.subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        chapter.subtitle!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: LessonColors.muted,
                        ),
                      ),
                    ],
                    if (locked) ...[
                      const SizedBox(height: 6),
                      Text(
                        lockedHint,
                        style: const TextStyle(
                          fontSize: 12,
                          color: LessonColors.muted,
                        ),
                      ),
                    ] else if (completed && bestLabel != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '$passedLabel · $bestLabel',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.greenDark,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!locked)
                Icon(
                  Icons.chevron_right_rounded,
                  color: accent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
