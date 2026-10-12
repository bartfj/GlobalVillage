import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/models/course_track.dart';
import '../../../data/models/learning_language.dart';

List<CourseTrack> _tracksOf(LearningLanguage language) =>
    CourseTrack.values.where((t) => t.language == language).toList();

Future<void> showCourseSelector(BuildContext context, WidgetRef ref) async {
  final initial = ref.read(selectedTrackProvider);
  var language = initial.language;
  var busy = false;
  String? error;

  Future<void> commit(
    CourseTrack track,
    StateSetter setState,
    BuildContext sheetContext,
  ) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
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
                  '学习语言与课程',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                for (final value in LearningLanguage.values)
                  Builder(
                    builder: (context) {
                      final tracks = _tracksOf(value);
                      final single = tracks.length == 1;
                      return ListTile(
                        title: Text(value.label),
                        subtitle: single ? Text(tracks.first.label) : null,
                        selected: language == value,
                        leading: Icon(
                          language == value
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                        ),
                        trailing: single
                            ? const Icon(Icons.chevron_right)
                            : null,
                        onTap: busy
                            ? null
                            : () {
                                if (single) {
                                  commit(tracks.first, setState, sheetContext);
                                } else {
                                  setState(() {
                                    language = value;
                                    error = null;
                                  });
                                }
                              },
                      );
                    },
                  ),
                if (_tracksOf(language).length > 1) ...[
                  const Divider(),
                  const Text(
                    '系统课程',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  for (final track in _tracksOf(language))
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
                          : () => commit(track, setState, sheetContext),
                    ),
                ],
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
