import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/draw/airmix_sim.dart';
import '../../../core/theme/app_colors.dart';

/// 추첨기 무대 — 어두운 배경에 유리 통, 송풍 기둥, 출구관을 그리고 구슬을 움직인다.
///
/// [onTick] 은 매 프레임 지난 시간(초)을 받아 기계를 돌린다 (돌리지 않을 때는 그림만 그린다).
class AirMixStage extends StatefulWidget {
  const AirMixStage({super.key, required this.sim, this.onTick});

  final AirMixSim sim;
  final void Function(double seconds)? onTick;

  @override
  State<AirMixStage> createState() => _AirMixStageState();
}

class _AirMixStageState extends State<AirMixStage> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _repaint = ValueNotifier(0);
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = (elapsed - _last).inMicroseconds / 1e6;
      _last = elapsed;
      widget.onTick?.call(dt.clamp(0, 0.1));
      _repaint.value++;
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          painter: _StagePainter(widget.sim, _repaint),
          child: const SizedBox.expand(),
        ),
      );
}

class _StagePainter extends CustomPainter {
  _StagePainter(this.sim, Listenable repaint) : super(repaint: repaint);

  final AirMixSim sim;
  final _labels = <String, TextPainter>{};

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.7),
          radius: 1.2,
          colors: [DrawColors.stageHi, DrawColors.stage],
          stops: [0, 0.7],
        ).createShader(rect),
    );

    // 통 크기 — 위에 출구관, 아래에 받침이 들어갈 자리를 남긴다
    final r = min(size.width * 0.4, size.height * 0.36);
    final center = Offset(size.width / 2, size.height * 0.52);
    Offset at(double x, double y) => Offset(center.dx + x * r, center.dy - y * r);

    // 받침
    final base = Path()
      ..moveTo(center.dx - r * 0.32, center.dy + r * 0.93)
      ..lineTo(center.dx + r * 0.32, center.dy + r * 0.93)
      ..lineTo(center.dx + r * 0.55, center.dy + r * 1.28)
      ..lineTo(center.dx - r * 0.55, center.dy + r * 1.28)
      ..close();
    canvas.drawPath(
      base,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A3446), Color(0xFF121822)],
        ).createShader(base.getBounds()),
    );

    // 송풍 기둥 — 바람이 셀수록 밝게
    if (sim.blower > 0.02) {
      final jet = Rect.fromCenter(center: center, width: r * 0.6, height: r * 2);
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: r)));
      canvas.drawRect(
        jet,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              DrawColors.accent.withValues(alpha: 0.20 * sim.blower),
              DrawColors.accent.withValues(alpha: 0.0),
            ],
          ).createShader(jet)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
      canvas.restore();
    }

    // 유리 통
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [Colors.white.withValues(alpha: 0.07), Colors.white.withValues(alpha: 0.02)],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );

    // 출구관
    final gx = AirMixSim.gap * r;
    final gateTop = at(0, AirMixSim.gateY).dy;
    final tubeTop = center.dy - r * 1.32;
    final tube = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(
      Rect.fromLTRB(center.dx - gx, tubeTop, center.dx + gx, gateTop),
      Paint()..color = Colors.white.withValues(alpha: 0.05),
    );
    canvas.drawLine(Offset(center.dx - gx, gateTop), Offset(center.dx - gx, tubeTop), tube);
    canvas.drawLine(Offset(center.dx + gx, gateTop), Offset(center.dx + gx, tubeTop), tube);
    // 위 덮개
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(center.dx, tubeTop - 5), width: gx * 3.4, height: 10),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF2A3446),
    );

    // 통 테두리 — 출구 자리는 비운다
    final gapAngle = asin(AirMixSim.gap);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -pi / 2 + gapAngle,
      2 * pi - 2 * gapAngle,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
    // 유리 반사
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r * 0.9),
      pi * 1.08,
      pi * 0.32,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = r * 0.035,
    );

    // 출구 문 — 열리면 노랗게 옆으로 밀린다
    final open = sim.gateOpen;
    final lid = Rect.fromCenter(
      center: Offset(center.dx + (open ? gx * 1.9 : 0), gateTop),
      width: gx * 2.2,
      height: 5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(lid, const Radius.circular(3)),
      Paint()..color = open ? DrawColors.accent : const Color(0xFF8B97AB),
    );

    // 구슬
    final br = AirMixSim.radius * r;
    for (final b in sim.balls) {
      if (!b.inPlay) continue;
      _ball(canvas, at(b.x, b.y), br, b.number);
    }
  }

  void _ball(Canvas canvas, Offset c, double radius, int number) {
    final base = DrawColors.ball(number);
    final rect = Rect.fromCircle(center: c, radius: radius);
    canvas.drawCircle(
      c.translate(0, radius * 0.15),
      radius,
      Paint()..color = const Color(0x55000000),
    );
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          radius: 0.95,
          colors: [Color.lerp(base, Colors.white, 0.55)!, base, Color.lerp(base, Colors.black, 0.3)!],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
    if (radius < 7) return;
    final key = '$number@${radius.toStringAsFixed(1)}';
    final tp = _labels.putIfAbsent(
      key,
      () => TextPainter(
        text: TextSpan(
          text: '$number',
          style: TextStyle(
            fontSize: radius * (number >= 10 ? 0.95 : 1.1),
            fontWeight: FontWeight.w900,
            color: const Color(0xFF17191C),
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_StagePainter old) => old.sim != sim;
}
