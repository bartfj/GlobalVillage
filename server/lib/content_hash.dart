import 'package:cryptography/cryptography.dart';

Future<String> contentSha256(List<int> bytes) async {
  final hash = await Sha256().hash(bytes);
  final buffer = StringBuffer();
  for (final byte in hash.bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}
