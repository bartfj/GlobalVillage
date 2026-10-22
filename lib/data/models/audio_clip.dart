/// 应用内置、可按校验值落盘的参考录音片段。
abstract interface class AudioClip {
  String get id;
  String get sha256;
  int get byteLength;
}
