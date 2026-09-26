import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// 认证页统一圆角输入框，支持密码遮罩切换与内联错误提示
class AuthTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final String? errorText;

  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    this.obscure = false,
    this.errorText,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasError ? AppColors.red : AppColors.locked,
              width: 2,
            ),
          ),
          child: TextField(
            controller: widget.controller,
            obscureText: widget.obscure && _hidden,
            decoration: InputDecoration(
              labelText: widget.label,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              suffixIcon: widget.obscure
                  ? IconButton(
                      icon: Icon(
                        _hidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => setState(() => _hidden = !_hidden),
                    )
                  : null,
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              widget.errorText!,
              style: const TextStyle(fontSize: 13, color: AppColors.red),
            ),
          ),
      ],
    );
  }
}
