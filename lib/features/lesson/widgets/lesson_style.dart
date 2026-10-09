import 'package:flutter/material.dart';

class LessonColors {
  static const ink = Color(0xFF25352E);
  static const muted = Color(0xFF72837A);
  static const border = Color(0xFFDCE5DF);
  static const track = Color(0xFFEDF1EF);
  static const green = Color(0xFF31AB71);
  static const greenDark = Color(0xFF22754F);
  static const greenLight = Color(0xFFEDF9F1);
  static const blue = Color(0xFF399BD4);
  static const blueDark = Color(0xFF176597);
  static const blueLight = Color(0xFFEDF7FF);
  static const red = Color(0xFFD96363);
  static const redDark = Color(0xFFAE4548);
  static const redLight = Color(0xFFFFF1F0);
}

class LessonActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool error;

  const LessonActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.error = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Container(
      decoration: BoxDecoration(
        color: enabled
            ? error
                  ? LessonColors.red
                  : LessonColors.green
            : const Color(0xFFE7EEE9),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          bottom: BorderSide(
            color: enabled
                ? error
                      ? LessonColors.redDark
                      : LessonColors.greenDark
                : const Color(0xFFD9E3DC),
            width: 4,
          ),
        ),
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: const Color(0xFFA3B1A8),
          minimumSize: const Size(double.infinity, 50),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}
