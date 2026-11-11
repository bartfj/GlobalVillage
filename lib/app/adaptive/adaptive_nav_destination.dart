import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/learning_language.dart';
import '../../data/models/skill_practice.dart';
import '../app_strings.dart';
import '../providers.dart';

class AdaptiveNavDestination {
  const AdaptiveNavDestination({
    required this.id,
    required this.location,
    required this.icon,
    required this.label,
    required this.visible,
  });

  final String id;
  final String location;
  final IconData icon;
  final String Function(S s) label;
  final bool Function(WidgetRef ref) visible;

  bool matches(String matchedLocation) {
    if (id == 'path') {
      return matchedLocation == '/';
    }
    if (id == 'practice') {
      return matchedLocation.startsWith('/practice/');
    }
    return matchedLocation == location ||
        matchedLocation.startsWith('$location/');
  }
}

List<AdaptiveNavDestination> buildAdaptiveNavDestinations() {
  return [
    AdaptiveNavDestination(
      id: 'path',
      location: '/',
      icon: Icons.route_rounded,
      label: (s) => s.navPath,
      visible: (_) => true,
    ),
    AdaptiveNavDestination(
      id: 'practice',
      location: '/practice/pronunciation',
      icon: Icons.fitness_center_rounded,
      label: (s) => s.navPractice,
      visible: (ref) => SkillPracticeKind.forLanguage(
        ref.read(selectedTrackProvider).language,
      ).isNotEmpty,
    ),
    AdaptiveNavDestination(
      id: 'sanskrit-audio',
      location: '/sanskrit-audio',
      icon: Icons.record_voice_over_rounded,
      label: (s) => s.sanskritAudioTitle,
      visible: (ref) =>
          ref.read(selectedTrackProvider).language == LearningLanguage.sanskrit,
    ),
    AdaptiveNavDestination(
      id: 'completed',
      location: '/completed',
      icon: Icons.flag_rounded,
      label: (s) => s.navCompleted,
      visible: (_) => true,
    ),
    AdaptiveNavDestination(
      id: 'review',
      location: '/review',
      icon: Icons.history_rounded,
      label: (s) => s.reviewRecords,
      visible: (_) => true,
    ),
    AdaptiveNavDestination(
      id: 'badges',
      location: '/badges',
      icon: Icons.emoji_events_rounded,
      label: (s) => s.statsBadges,
      visible: (_) => true,
    ),
    AdaptiveNavDestination(
      id: 'tree',
      location: '/tree',
      icon: Icons.park_rounded,
      label: (s) => s.navTree,
      visible: (_) => true,
    ),
    AdaptiveNavDestination(
      id: 'account',
      location: '/account',
      icon: Icons.person_rounded,
      label: (s) => s.navAccount,
      visible: (_) => true,
    ),
  ];
}
