import 'package:hive/hive.dart';

class RewardStore {
  static const boxName = 'reward_attempts';

  final String userKey;

  const RewardStore({required this.userKey});

  Box<String> get _box => Hive.box<String>(boxName);

  String _key(String attemptId) => '$userKey|$attemptId';

  String? get(String attemptId) => _box.get(_key(attemptId));

  Future<void> save(String attemptId, String unitId) =>
      _box.put(_key(attemptId), unitId);

  Map<String, String> get attempts {
    final prefix = '$userKey|';
    return {
      for (final key in _box.keys.whereType<String>())
        if (key.startsWith(prefix))
          key.substring(prefix.length): _box.get(key)!,
    };
  }
}
