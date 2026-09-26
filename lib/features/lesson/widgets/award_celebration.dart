import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../../../data/repositories/reward_repository.dart';

/// 闯关庆祝页：循环彩纸雨 + 徽章光环星星 + 角色欢呼 + 音效震动
/// [award] 为空时（理论上不发生，兜底）不显示徽章计数信息
class AwardCelebration extends StatefulWidget {
  final RewardAward? award;
  final bool isPerfect;
  final VoidCallback onCollect;

  const AwardCelebration({
    super.key,
    required this.award,
    this.isPerfect = false,
    required this.onCollect,
  });

  @override
  State<AwardCelebration> createState() => _AwardCelebrationState();
}

class _AwardCelebrationState extends State<AwardCelebration>
    with TickerProviderStateMixin {
  /// 入场动画：徽章弹性缩放、角色弹入
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  /// 循环动画：彩纸雨、光环旋转、星星脉动、角色跳动
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4000),
  );

  final AudioPlayer _player = AudioPlayer();

  /// 本次的趣味对白（米娅、里奥各一句，随机挑选）
  late final ({String mia, String leo}) _dialogue = _pickDialogue();

  static final _rand = math.Random();

  static const _dialogues = [
    (mia: '太厉害了吧！', leo: '完美通关，我服！'),
    (mia: '这波操作满分！', leo: '不愧是你！'),
    (mia: '口语越来越溜啦！', leo: '英语高手认证！'),
    (mia: '星星都为你闪烁！', leo: '鼓掌鼓掌！'),
    (mia: '保持这个节奏！', leo: '离学霸又近一步！'),
    (mia: '你的进步我看在眼里！', leo: '徽章拿到手软！'),
    (mia: '今天也是最棒的练习！', leo: '一起冲下一关吧！'),
    (mia: '厉害厉害！', leo: '膜拜大佬！'),
  ];

  static ({String mia, String leo}) _pickDialogue() =>
      _dialogues[_rand.nextInt(_dialogues.length)];

  @override
  void initState() {
    super.initState();
    unawaited(_playCelebrate());
  }

  Future<void> _playCelebrate() async {
    try {
      await _player.play(AssetSource('sounds/celebrate.wav'));
      await HapticFeedback.lightImpact();
    } catch (_) {
      // 音效/震动失败不影响庆祝流程
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else {
      if (!_intro.isAnimating && _intro.value == 0) _intro.forward();
      if (!_loop.isAnimating) _loop.repeat();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.award?.unit.title;
    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        child: Stack(
          children: [
            // 入场烟花（一次性）
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _intro,
                  builder: (context, _) =>
                      CustomPaint(painter: _FireworksPainter(_intro.value)),
                ),
              ),
            ),
            // 循环彩纸雨
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _loop,
                  builder: (context, _) =>
                      CustomPaint(painter: _ConfettiRainPainter(_loop.value)),
                ),
              ),
            ),
            Positioned.fill(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 18,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          MediaQuery.sizeOf(context).height -
                          MediaQuery.paddingOf(context).vertical -
                          36,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(height: 24),
                        Column(
                          children: [
                            _buildBadgeWithHalo(),
                            const SizedBox(height: 16),
                            _buildCharacters(),
                            const SizedBox(height: 20),
                            _buildTitle(),
                            const SizedBox(height: 12),
                            if (title != null) ...[
                              Text(
                                '$title徽章 +1',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '累计 ${widget.award!.count} 枚',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ],
                        ),
                        PushableButton(
                          label: '收下徽章',
                          onPressed: widget.onCollect,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 徽章 + 旋转金色光环 + 环绕星星
  Widget _buildBadgeWithHalo() {
    return SizedBox(
      width: 220,
      height: 220,
      child: AnimatedBuilder(
        animation: Listenable.merge([_intro, _loop]),
        builder: (context, _) {
          final scale = Curves.elasticOut.transform(
            (_intro.value * 2).clamp(0.0, 1.0),
          );
          return Stack(
            alignment: Alignment.center,
            children: [
              // 放射光芒（反向慢转）
              Transform.rotate(
                angle: -_loop.value * math.pi,
                child: CustomPaint(
                  size: const Size(250, 250),
                  painter: _RaysPainter(badgeScale: scale),
                ),
              ),
              // 旋转光环
              Transform.rotate(
                angle: _loop.value * math.pi * 2,
                child: CustomPaint(
                  size: const Size(210, 210),
                  painter: _HaloPainter(),
                ),
              ),
              // 环绕星星
              for (var i = 0; i < 8; i++)
                _buildStar(i, scale),
              // 徽章本体
              Transform.scale(
                scale: scale,
                child: Container(
                  width: 156,
                  height: 156,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.greenLight,
                  ),
                  child: const Icon(
                    Icons.military_tech_rounded,
                    size: 112,
                    color: AppColors.goldDark,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 标题弹性弹出：入场越过 delay 后 elasticOut 弹出
  Widget _buildTitle() {
    return AnimatedBuilder(
      animation: _intro,
      builder: (context, _) {
        final t = ((_intro.value - 0.8) / 0.2).clamp(0.0, 1.0);
        final scale = Curves.elasticOut.transform(t);
        return Transform.scale(
          scale: scale,
          child: Text(
            widget.isPerfect ? '完美通关！' : '闯关成功！',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        );
      },
    );
  }

  Widget _buildStar(int index, double badgeScale) {
    final angle = index * math.pi / 4;
    final pulse =
        0.55 + 0.45 * math.sin(_loop.value * math.pi * 4 + index * 1.3);
    final radius = 98.0;
    return Transform.translate(
      offset: Offset(
        math.cos(angle) * radius,
        math.sin(angle) * radius,
      ),
      child: Opacity(
        opacity: (badgeScale * pulse).clamp(0.0, 1.0),
        child: Icon(
          Icons.star_rounded,
          size: 14 + 10 * pulse,
          color: index.isEven ? AppColors.gold : AppColors.blue,
        ),
      ),
    );
  }

  /// 米娅 / 里奥 两侧弹入欢呼，随循环轻微跳动，头顶星星闪亮；
  /// 入场完成后两人轮流弹出趣味对白气泡（各 2 秒）
  Widget _buildCharacters() {
    return AnimatedBuilder(
      animation: Listenable.merge([_intro, _loop]),
      builder: (context, _) {
        final introDone = _intro.value >= 1;
        // 0~0.5 米娅说话，0.5~1 里奥说话
        final miaSpeaking = _loop.value < 0.5;
        final local = miaSpeaking
            ? (_loop.value / 0.5)
            : ((_loop.value - 0.5) / 0.5);
        // 切换瞬间快速弹出
        final pop = (local * 5).clamp(0.0, 1.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _CheeringCharacter(
              name: '米娅',
              icon: Icons.face_3,
              color: AppColors.blue,
              introScale: _popScale(0.45),
              bobOffset: math.sin(_loop.value * math.pi * 4) * 5,
              starOpacity:
                  _popScale(0.9).clamp(0.0, 1.0) *
                  (0.6 + 0.4 * math.sin(_loop.value * math.pi * 6)),
              speech: introDone && miaSpeaking ? _dialogue.mia : null,
              speechScale: Curves.easeOutBack.transform(pop),
            ),
            const SizedBox(width: 32),
            _CheeringCharacter(
              name: '里奥',
              icon: Icons.face_6,
              color: AppColors.green,
              introScale: _popScale(0.6),
              bobOffset: math.sin(_loop.value * math.pi * 4 + math.pi) * 5,
              starOpacity:
                  _popScale(1.05).clamp(0.0, 1.0) *
                  (0.6 + 0.4 * math.sin(_loop.value * math.pi * 6 + math.pi)),
              speech: introDone && !miaSpeaking ? _dialogue.leo : null,
              speechScale: Curves.easeOutBack.transform(pop),
            ),
          ],
        );
      },
    );
  }

  /// 角色弹入缩放：intro 越过 delay 后 elasticOut 弹出
  double _popScale(double delay) {
    final t = ((_intro.value - delay) / 0.4).clamp(0.0, 1.0);
    if (t <= 0) return 0;
    return Curves.elasticOut.transform(t);
  }
}

class _CheeringCharacter extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final double introScale;
  final double bobOffset;
  final double starOpacity;

  /// 对白气泡文本（null 不显示）
  final String? speech;

  /// 气泡弹出缩放（easeOutBack）
  final double speechScale;

  const _CheeringCharacter({
    required this.name,
    required this.icon,
    required this.color,
    required this.introScale,
    required this.bobOffset,
    this.starOpacity = 0,
    this.speech,
    this.speechScale = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, bobOffset),
      child: Transform.scale(
        scale: introScale,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.15),
                    border: Border.all(color: color, width: 3),
                  ),
                  child: Icon(icon, size: 44, color: color),
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  style: TextStyle(fontWeight: FontWeight.w700, color: color),
                ),
              ],
            ),
            // 头顶闪亮星星
            if (starOpacity > 0)
              Positioned(
                top: -14,
                right: -10,
                child: Opacity(
                  opacity: starOpacity.clamp(0.0, 1.0),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 22,
                    color: AppColors.gold,
                  ),
                ),
              ),
            // 对白气泡
            if (speech != null)
              Positioned(
                top: -46,
                left: -28,
                child: Transform.scale(
                  scale: speechScale.clamp(0.0, 1.15),
                  child: _SpeechBubble(text: speech!, color: color),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 对白气泡：圆角矩形 + 小三角尾巴
class _SpeechBubble extends StatelessWidget {
  final String text;
  final Color color;

  const _SpeechBubble({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        // 小三角尾巴
        CustomPaint(
          size: const Size(14, 8),
          painter: _BubbleTailPainter(color),
        ),
      ],
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  final Color color;

  const _BubbleTailPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()
      ..moveTo(1, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width - 1, 0)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawPath(path, border);
    // 遮住顶边线，让三角与气泡融合
    canvas.drawLine(
      const Offset(1, 0),
      Offset(size.width - 1, 0),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 循环彩纸雨：index 派生伪随机参数，从顶部持续下落 + 左右摆动
class _ConfettiRainPainter extends CustomPainter {
  /// 循环进度 0..1（由 repeat() 控制器驱动）
  final double t;

  const _ConfettiRainPainter(this.t);

  static const _colors = [
    AppColors.green,
    AppColors.blue,
    AppColors.gold,
    AppColors.red,
  ];
  static const _count = 80;

  static double _rand(int i, int salt) =>
      ((i * 9301 + salt * 49297) % 233280) / 233280.0;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < _count; i++) {
      final x = _rand(i, 1) * size.width;
      final speed = 0.55 + _rand(i, 2) * 0.7; // 每个循环下落的高度比例
      final phase = _rand(i, 3);
      final y = (((t * speed) + phase) % 1.0) * size.height;
      final sway =
          math.sin((t * math.pi * 2 * (1 + _rand(i, 4) * 2)) + phase * 6.28) *
          (14 + _rand(i, 5) * 22);
      final paint = Paint()..color = _colors[i % _colors.length];
      canvas.save();
      canvas.translate(x + sway, y);
      canvas.rotate(t * math.pi * 4 * (_rand(i, 6) - 0.5) + phase * 6.28);
      switch (i % 3) {
        case 0: // 圆角矩形
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(-4, -7, 8, 14),
              const Radius.circular(2),
            ),
            paint,
          );
        case 1: // 圆点
          canvas.drawCircle(Offset.zero, 4 + _rand(i, 7) * 3, paint);
        case 2: // 三角
          canvas.drawPath(
            Path()
              ..moveTo(0, -6)
              ..lineTo(5.5, 4)
              ..lineTo(-5.5, 4)
              ..close(),
            paint,
          );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiRainPainter oldDelegate) =>
      oldDelegate.t != t;
}

/// 金色旋转光环（虚线圆弧）
class _HaloPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          AppColors.gold.withValues(alpha: 0),
          AppColors.gold,
          AppColors.gold.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 4),
      0,
      math.pi * 1.5,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _HaloPainter oldDelegate) => false;
}

/// 徽章背后放射光芒线（随徽章入场渐显）
class _RaysPainter extends CustomPainter {
  /// 徽章缩放（用于光芒渐显）
  final double badgeScale;

  const _RaysPainter({required this.badgeScale});

  @override
  void paint(Canvas canvas, Size size) {
    if (badgeScale <= 0) return;
    final center = size.center(Offset.zero);
    final alpha = (badgeScale * 0.45).clamp(0.0, 0.45);
    final paint = Paint()..color = AppColors.gold.withValues(alpha: alpha);
    const count = 12;
    const innerR = 62.0;
    final outerR = size.width / 2;
    for (var i = 0; i < count; i++) {
      final angle = i * math.pi * 2 / count;
      final halfWedge = math.pi / count * 0.42;
      canvas.drawPath(
        Path()
          ..moveTo(
            center.dx + math.cos(angle - halfWedge) * innerR,
            center.dy + math.sin(angle - halfWedge) * innerR,
          )
          ..lineTo(
            center.dx + math.cos(angle) * outerR,
            center.dy + math.sin(angle) * outerR,
          )
          ..lineTo(
            center.dx + math.cos(angle + halfWedge) * innerR,
            center.dy + math.sin(angle + halfWedge) * innerR,
          )
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RaysPainter oldDelegate) =>
      oldDelegate.badgeScale != badgeScale;
}

/// 入场烟花：两侧底部喷射彩色粒子（抛物线 + 重力 + 渐隐，一次性）
class _FireworksPainter extends CustomPainter {
  /// 入场进度 0..1（intro 控制器，全程 2.6s）
  final double t;

  const _FireworksPainter(this.t);

  static const _colors = [
    AppColors.gold,
    AppColors.blue,
    AppColors.red,
    AppColors.green,
  ];

  static double _rand(int i, int salt) =>
      ((i * 9301 + salt * 49297) % 233280) / 233280.0;

  @override
  void paint(Canvas canvas, Size size) {
    // 两波：0.15s 与 0.9s 各从左右两侧喷射
    const waves = [0.058, 0.346]; // 相对 intro 进度（intro 2.6s）
    for (var w = 0; w < waves.length; w++) {
      final local = (t - waves[w]) / 0.55; // 每波持续 ~1.43s
      if (local < 0 || local > 1) continue;
      final burst = Curves.easeOut.transform(local.clamp(0.0, 1.0));
      final fade = 1.0 - local;
      for (var i = 0; i < 26; i++) {
        // 左右交替喷射
        final fromLeft = (i + w) % 2 == 0;
        final x0 = fromLeft ? size.width * 0.12 : size.width * 0.88;
        final y0 = size.height * 0.78;
        // 喷射方向：向上 ±32° 扇形
        final dir = (fromLeft ? 1 : -1) * (0.35 + _rand(i, 10 + w) * 0.75);
        final speed = size.height * (0.55 + _rand(i, 20 + w) * 0.35);
        final x = x0 + dir * speed * burst * 0.55;
        final y = y0 - speed * burst + 0.5 * size.height * 0.9 * burst * burst;
        final paint = Paint()
          ..color = _colors[i % _colors.length].withValues(
            alpha: fade.clamp(0.0, 1.0),
          );
        canvas.drawCircle(Offset(x, y), 3 + _rand(i, 30 + w) * 3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FireworksPainter oldDelegate) =>
      oldDelegate.t != t;
}
