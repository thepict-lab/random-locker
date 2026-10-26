import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// 숫자 구슬 — 위 왼쪽이 밝은 입체 구슬
class DrawBall extends StatelessWidget {
  const DrawBall(this.number, {super.key, this.size = 40, this.dim = false, this.ring});

  final int number;
  final double size;

  /// 흐리게 (고를 수 없음 · 맞지 않음)
  final bool dim;

  /// 둘레에 두르는 강조 색
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final base = DrawColors.ball(number);
    final ball = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.4),
          radius: 0.95,
          colors: [
            Color.lerp(base, Colors.white, 0.55)!,
            base,
            Color.lerp(base, Colors.black, 0.22)!,
          ],
          stops: const [0, 0.55, 1],
        ),
        border: ring == null ? null : Border.all(color: ring!, width: max(2, size * 0.07)),
        boxShadow: dim
            ? null
            : [
                BoxShadow(
                    color: const Color(0x40000000),
                    blurRadius: size * 0.15,
                    offset: Offset(0, size * 0.06)),
              ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: TextStyle(
          fontSize: size * (number >= 10 ? 0.4 : 0.46),
          fontWeight: FontWeight.w900,
          color: const Color(0xFF17191C),
          height: 1,
        ),
      ),
    );
    return dim ? Opacity(opacity: 0.28, child: ball) : ball;
  }
}

/// 비어 있는 구슬 자리 (점선 동그라미)
class EmptyBallSlot extends StatelessWidget {
  const EmptyBallSlot({super.key, this.size = 40, this.label, this.dark = false});

  final double size;
  final String? label;
  final bool dark;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _DashedCircle(dark ? const Color(0x40FFFFFF) : DrawColors.line),
        child: SizedBox(
          width: size,
          height: size,
          child: label == null
              ? null
              : Center(
                  child: Text(label!,
                      style: TextStyle(
                          fontSize: size * 0.32,
                          fontWeight: FontWeight.w700,
                          color: dark ? const Color(0x80FFFFFF) : DrawColors.muted)),
                ),
        ),
      );
}

class _DashedCircle extends CustomPainter {
  _DashedCircle(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = (Offset.zero & size).deflate(1);
    const n = 16;
    for (var i = 0; i < n; i++) {
      canvas.drawArc(rect, i * 2 * pi / n, pi / n, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCircle old) => old.color != color;
}

/// 고른 숫자를 가렸을 때 — 물음표 구슬
class HiddenBall extends StatelessWidget {
  const HiddenBall({super.key, this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: DrawColors.fg),
        alignment: Alignment.center,
        child: Text('?',
            style: TextStyle(
                color: DrawColors.accent, fontWeight: FontWeight.w900, fontSize: size * 0.5, height: 1)),
      );
}
