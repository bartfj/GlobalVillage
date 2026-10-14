import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/models/learning_language.dart';

Future<void> showCourseSelector(BuildContext context, WidgetRef ref) async {
  var busy = false;
  String? error;

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
      if (sheetContext.mounted) {
        Navigator.pop(sheetContext);
      }
    } catch (_) {
      if (sheetContext.mounted) {
        setState(() {
          busy = false;
          error = '课程切换失败，请重试。';
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
                const Text(
                  '学习语言',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                for (final value in LearningLanguage.values)
                  Builder(
                    builder: (context) {
                      final current =
                          ref.read(selectedTrackProvider).language == value;
                      return ListTile(
                        title: Text(value.label),
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
}
