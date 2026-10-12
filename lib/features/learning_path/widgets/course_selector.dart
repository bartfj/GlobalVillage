import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/models/course_track.dart';
import '../../../data/models/learning_language.dart';

Future<void> showCourseSelector(BuildContext context, WidgetRef ref) async {
  final initial = ref.read(selectedTrackProvider);
  var language = initial.language;
  var busy = false;
  String? error;
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
                  ListTile(
                    title: Text(value.label),
                    selected: language == value,
                    leading: Icon(
                      language == value
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    onTap: busy
                        ? null
                        : () => setState(() {
                            language = value;
                            error = null;
                          }),
                  ),
                const Divider(),
                const Text(
                  '系统课程',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                for (final track in CourseTrack.values.where(
                  (t) => t.language == language,
                ))
                  ListTile(
                    title: Text(track.label),
                    selected:
                        track ==
                        ref
                            .read(selectedTrackProvider.notifier)
                            .rememberedTrack(language),
                    leading: Icon(
                      track ==
                              ref
                                  .read(selectedTrackProvider.notifier)
                                  .rememberedTrack(language)
                          ? Icons.check_circle_outline
                          : Icons.circle_outlined,
                    ),
                    onTap: busy
                        ? null
                        : () async {
                            setState(() {
                              busy = true;
                              error = null;
                            });
                            try {
                              final courses = await ref.read(
                                allCoursesProvider.future,
                              );
                              if (!courses.any((c) => c.id == track.id)) {
                                throw StateError('Missing course');
                              }
                              await ref
                                  .read(selectedTrackProvider.notifier)
                                  .select(track);
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
