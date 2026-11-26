import 'dart:async';

import 'package:hive/hive.dart';

import '../models/check_in.dart';

class CheckInStore {
  const CheckInStore({required this.userKey});

  static const boxName = 'check_in_days';
  static final _pendingWrites = <String, Future<void>>{};

  final String userKey;

  String get _prefix => '$userKey|';
  Box<String>? get _openBox =>
      Hive.isBoxOpen(boxName) ? Hive.box<String>(boxName) : null;

  static Set<String> parseDays(Object? value) => value is List
      ? {
          for (final day in value.whereType<String>())
            if (parseCheckInDay(day) != null) day,
        }
      : {};

  Set<String> get days {
    final box = _openBox;
    if (box == null) return {};
    return {
      for (final key in box.keys.whereType<String>())
        if (key.startsWith(_prefix) && key.length == _prefix.length + 10)
          key.substring(_prefix.length),
    };
  }

  Stream<BoxEvent> watch() =>
      _openBox?.watch().where(
        (event) =>
            event.key is String &&
            (event.key as String).startsWith(_prefix) &&
            (event.key as String).length == _prefix.length + 10,
      ) ??
      const Stream.empty();

  Future<void> mergeDays(Iterable<String> days) {
    if (days.isEmpty) return Future.value();
    return _writeInOrder(() => _saveNewDays(days));
  }

  /// Returns the committed dates before recording [day], or null for a duplicate.
  Future<Set<String>?> recordDay(String day) => _writeInOrder(() async {
    if (parseCheckInDay(day) == null) throw ArgumentError.value(day, 'day');
    final previous = days;
    if (previous.contains(day)) return null;
    await _saveNewDays([day]);
    return previous;
  });

  // Hive updates its keys before the write reaches disk. Local results and
  // merges from other store instances must wait for that write to settle.
  Future<T> _writeInOrder<T>(Future<T> Function() action) async {
    final previous = _pendingWrites[userKey];
    final finished = Completer<void>();
    _pendingWrites[userKey] = finished.future;
    try {
      if (previous != null) await previous;
      return await action();
    } finally {
      finished.complete();
      if (identical(_pendingWrites[userKey], finished.future)) {
        _pendingWrites.remove(userKey);
      }
    }
  }

  Future<void> _saveNewDays(Iterable<String> days) async {
    final box = Hive.box<String>(boxName);
    final writes = <String, String>{};
    for (final day in days) {
      final key = '$_prefix$day';
      if (parseCheckInDay(day) != null && !box.containsKey(key)) {
        writes[key] = day;
      }
    }
    if (writes.isNotEmpty) await box.putAll(writes);
  }
}
