import 'package:flutter/material.dart';

/// 应用配色
class AppColors {
  static const green = Color(0xFF58CC02);
  static const greenDark = Color(0xFF58A700);
  static const greenLight = Color(0xFFD7FFB8);
  static const blue = Color(0xFF1CB0F6);
  static const blueDark = Color(0xFF1899D6);
  static const red = Color(0xFFFF4B4B);
  static const redDark = Color(0xFFEA2B2B);
  static const redLight = Color(0xFFFFDFE0);
  static const gold = Color(0xFFFFC800);
  static const goldDark = Color(0xFFE0A800);
  static const locked = Color(0xFFE5E5E5);
  static const lockedDark = Color(0xFFAFAFAF);
  static const textPrimary = Color(0xFF4B4B4B);
  static const textSecondary = Color(0xFF777777);
  static const background = Color(0xFFFFFFFF);
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.green,
      primary: AppColors.green,
      secondary: AppColors.blue,
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: AppColors.textPrimary),
      bodyMedium: TextStyle(fontSize: 14, color: AppColors.textSecondary),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.green,
      linearTrackColor: AppColors.locked,
      borderRadius: BorderRadius.all(Radius.circular(8)),
      linearMinHeight: 12,
    ),
  );
}

/// 3D 粗边按钮：底部深色描边，按下时下移
class PushableButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color shadowColor;
  final Color textColor;

  const PushableButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.green,
    this.shadowColor = AppColors.greenDark,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final bg = enabled ? color : AppColors.locked;
    final shadow = enabled ? shadowColor : AppColors.lockedDark;
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border(bottom: BorderSide(color: shadow, width: 4)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: enabled ? textColor : AppColors.lockedDark,
          ),
        ),
      ),
    );
  }
}
