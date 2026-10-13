import 'package:hive/hive.dart';

/// 本地账号（无后端，Hive 持久化）。
/// 可选 onlineAccountId/onlineBoundAt 记录已绑定的在线账号（绑定升级后填写）。
class User {
  final String nickname;
  final String passwordHash;
  final String salt;
  final DateTime createdAt;

  /// 绑定的在线账号 ID；未绑定为 null（旧数据兼容缺省）
  final String? onlineAccountId;

  /// 绑定时间（毫秒时间戳）；未绑定为 null
  final int? onlineBoundAt;

  const User({
    required this.nickname,
    required this.passwordHash,
    required this.salt,
    required this.createdAt,
    this.onlineAccountId,
    this.onlineBoundAt,
  });
}

/// 手写 Hive TypeAdapter，避免 build_runner 代码生成
class UserAdapter extends TypeAdapter<User> {
  @override
  final int typeId = 1;

  @override
  User read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return User(
      nickname: fields[0] as String,
      passwordHash: fields[1] as String,
      salt: fields[2] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(fields[3] as int),
      onlineAccountId: fields[4] as String?,
      onlineBoundAt: fields[5] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, User obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.nickname)
      ..writeByte(1)
      ..write(obj.passwordHash)
      ..writeByte(2)
      ..write(obj.salt)
      ..writeByte(3)
      ..write(obj.createdAt.millisecondsSinceEpoch)
      ..writeByte(4)
      ..write(obj.onlineAccountId)
      ..writeByte(5)
      ..write(obj.onlineBoundAt);
  }
}
