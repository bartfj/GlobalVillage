import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/constants.dart';

/// 欢迎页：游客可直接进入，登录/注册可选
class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.greenLight,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.school,
                  color: AppColors.green,
                  size: 56,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '地球村',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '每天 5 分钟，闯关学会实用英语',
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
              const Spacer(flex: 3),
              PushableButton(
                label: '开始学习',
                onPressed: () =>
                    ref.read(authProvider.notifier).loginAsGuest(),
              ),
              const SizedBox(height: 12),
              PushableButton(
                label: '登录 / 注册',
                color: AppColors.blue,
                shadowColor: AppColors.blueDark,
                onPressed: () => context.push('/login'),
              ),
              const SizedBox(height: 16),
              Text(
                'v$kAppVersion',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.lockedDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
