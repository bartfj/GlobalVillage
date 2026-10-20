import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_strings.dart';
import '../../../app/providers.dart';
import '../../../data/models/learning_language.dart';

Future<void> showCourseSelector(BuildContext context, WidgetRef ref) async {
  var busy = false;
  String? error;
  var switchedToChinese = false;
  final s = ref.read(stringsProvider);

  Future<void> commit(
    LearningLanguage language,
    StateSetter setState,
    BuildContext sheetContext,
  ) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      // 切到该语言上次记忆的课程；无记忆时回退到该语言首条课程。
      final track = ref
          .read(selectedTrackProvider.notifier)
          .rememberedTrack(language);
      final courses = await ref.read(allCoursesProvider.future);
      if (!courses.any((c) => c.id == track.id)) {
        throw StateError('Missing course');
      }
      await ref.read(selectedTrackProvider.notifier).select(track);
      switchedToChinese = language == LearningLanguage.chinese;
      if (sheetContext.mounted) {
        Navigator.pop(sheetContext);
      }
    } catch (_) {
      if (sheetContext.mounted) {
        setState(() {
          busy = false;
          error = s.courseSwitchFailed;
        });
      }
    }
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setState) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  s.chooseLanguageTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                for (final value in LearningLanguage.values)
                  Builder(
                    builder: (context) {
                      final current =
                          ref.read(selectedTrackProvider).language == value;
                      return ListTile(
                        title: Text(s.languageLabel(value)),
                        selected: current,
                        leading: Icon(
                          current
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: busy
                            ? null
                            : () => commit(value, setState, sheetContext),
                      );
                    },
                  ),
                if (busy) const Center(child: CircularProgressIndicator()),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  // 面板关闭后再询问，避免弹窗与选择面板争抢同一个路由栈。
  if (switchedToChinese && context.mounted) {
    await _suggestEnglishUi(context, ref);
  }
}

/// 首次切到中文课程时说明界面已随解释语言切为英文，并允许切回（只问一次）。
Future<void> _suggestEnglishUi(BuildContext context, WidgetRef ref) async {
  if (ref.read(selectedTrackProvider).language != LearningLanguage.chinese) {
    return;
  }
  if (ref.read(uiLanguageOverrideProvider) != null) return;
  final controller = ref.read(uiLanguageOverrideProvider.notifier);
  if (controller.prompted) return;
  await controller.markPrompted();
  if (!context.mounted) return;
  const s = S(UiLanguage.english);
  final keepEnglish = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(s.uiLanguageSuggestionTitle),
      content: Text(s.uiLanguageSuggestionBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(s.uiLanguageSwitch),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(s.uiLanguageKeep),
        ),
      ],
    ),
  );
  if (keepEnglish == null) return;
  await controller.apply(
    keepEnglish ? UiLanguage.english : UiLanguage.chinese,
  );
}
