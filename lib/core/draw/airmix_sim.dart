import 'dart:math';

import 'draw_rules.dart';

/// 추첨기 진행 단계
enum AirMixPhase {
  /// 위에서 구슬을 하나씩 넣는다
  loading('구슬 넣는 중'),

  /// 송풍기를 켜고 섞는다
  mixing('공기로 섞는 중'),

  /// 송풍기를 잠깐 멈춰 출구 근처를 비운다
  pause('잠깐 멈춤'),

  /// 송풍기를 다시 켜고 출구를 연다 — 바람에 밀려 올라간 구슬 하나가 출구를 지나면 뽑힌다
  open('출구 열림'),

  done('추첨 끝');

  const AirMixPhase(this.label);
  final String label;
}

class SimBall {
  SimBall(this.id, this.number);

  /// 구슬 번호 (0 … 54)
  final int id;

  /// 구슬에 적힌 숫자
  final int number;

  double x = 0, y = 0, vx = 0, vy = 0;

  /// 통 안에 있다 (아직 넣지 않았거나 뽑혀 나가면 false)
  bool inPlay = false;

  /// 출구관을 지나는 중
  bool leaving = false;
}

/// 공기 추첨기 — 2D 물리 흉내.
///
/// lotto-airmix 의 생각을 따랐다: 입력은 구슬을 넣는 순서뿐이고, 그 순서를 해시한 시드 하나로
/// 모든 흔들림을 만든다. 고정 시간 간격(1/240 초)으로만 진행하므로 화면 속도(1× … 8×)나
/// 프레임 수와 상관없이 같은 순서면 언제나 같은 구슬이 같은 순서로 나온다.
///
/// 좌표는 통의 반지름을 1 로 둔 값이고 y 는 위쪽이 +.
class AirMixSim {
  AirMixSim(List<int> loadOrder, {this.drawCount = DrawRules.drawCount})
      : loadOrder = List.unmodifiable(loadOrder),
        seed = seedOf(loadOrder) {
    final pool = DrawRules.pool();
    balls = [for (final id in loadOrder) SimBall(id, pool[id])];
    _rng = _Mulberry32(seed);
  }

  static const dt = 1 / 240;
  static const radius = 0.062; // 구슬
  static const gap = radius * 1.5; // 출구 반폭
  static const _gravity = 3.2;
  static const _drag = 2.6;
  static const _jet = 4.3;
  static const _jetWidth = 0.2;
  static const _turbulence = 1.7;
  static const _ballBounce = 0.6;
  static const _wallBounce = 0.5;

  static const _dropEvery = 0.07;
  static const _settle = 0.9;
  static const _mixTime = 5.0;
  static const _pauseTime = 1.2;

  /// 출구를 열어 둔 채 이만큼 지나도 안 나오면 바람을 점점 세게 한다
  static const _assistAfter = 6.0;

  /// 그래도 안 나오면 출구에 가장 가까운 구슬을 뽑는다 (결과는 여전히 시드로 정해진다)
  static const _forceAfter = 18.0;

  final List<int> loadOrder;
  final int seed;
  final int drawCount;
  late final List<SimBall> balls;
  late final _Mulberry32 _rng;

  double time = 0;
  AirMixPhase phase = AirMixPhase.loading;
  double _phaseAt = 0;

  /// 송풍기 세기 0 … 1 (켜고 끌 때 서서히)
  double blower = 0;
  bool gateOpen = false;

  /// 뽑힌 구슬 번호 (나온 순서)
  final List<int> drawnIds = [];

  List<int> get drawnNumbers => [for (final id in drawnIds) DrawRules.pool()[id]];

  bool get done => phase == AirMixPhase.done;

  /// 출구 모서리 높이
  static final double gateY = sqrt(1 - gap * gap);

  /// 이 높이를 지나면 뽑힌 것
  static const exitY = 1 + radius * 2.4;

  int _loaded = 0;

  /// 출구가 열린 뒤 지난 시간
  double get openFor => phase == AirMixPhase.open ? time - _phaseAt : 0;

  void advance(double seconds) {
    final steps = (seconds / dt).round();
    for (var i = 0; i < steps && !done; i++) {
      step();
    }
  }

  /// 끝까지 돌린다 — 건너뛰기 · 다시 확인에 쓴다.
  void runToEnd() {
    // 어떤 경우에도 끝나도록 상한을 둔다 (정상이면 1분 안팎).
    while (!done && time < 600) {
      step();
    }
  }

  void step() {
    _schedule();
    final target = (phase == AirMixPhase.mixing || phase == AirMixPhase.open) ? 1.0 : 0.0;
    blower += (target - blower) * (target > blower ? dt / 0.3 : dt / 0.4);

    final assist = phase == AirMixPhase.open
        ? 1 + 0.08 * max(0.0, openFor - _assistAfter)
        : 1.0;

    for (final b in balls) {
      if (!b.inPlay) continue;
      final (ux, uy) = _air(b.x, b.y, assist);
      b.vx += (_drag * (ux - b.vx)) * dt;
      b.vy += (_drag * (uy - b.vy) - _gravity) * dt;
      b.x += b.vx * dt;
      b.y += b.vy * dt;
    }
    _collideBalls();
    for (final b in balls) {
      if (b.inPlay) _collideWalls(b);
    }
    _checkExit();
    time += dt;
  }

  void _schedule() {
    final t = time - _phaseAt;
    switch (phase) {
      case AirMixPhase.loading:
        while (_loaded < balls.length && time >= _loaded * _dropEvery) {
          final b = balls[_loaded++];
          b
            ..x = (_rng.next() - 0.5) * gap * 0.6
            ..y = gateY - radius * 1.2
            ..vx = (_rng.next() - 0.5) * 0.6
            ..vy = -1.6
            ..inPlay = true;
        }
        if (_loaded == balls.length && time >= balls.length * _dropEvery + _settle) {
          _go(AirMixPhase.mixing);
        }
      case AirMixPhase.mixing:
        if (t >= _mixTime) _go(AirMixPhase.pause);
      case AirMixPhase.pause:
        if (t >= _pauseTime) {
          gateOpen = true;
          _go(AirMixPhase.open);
        }
      case AirMixPhase.open:
        if (t >= _forceAfter && !balls.any((b) => b.leaving)) {
          final near = balls.where((b) => b.inPlay).reduce(
              (a, b) => _distToGate(a) <= _distToGate(b) ? a : b);
          near
            ..leaving = true
            ..x = 0
            ..y = gateY + radius
            ..vx = 0
            ..vy = 2;
        }
      case AirMixPhase.done:
        break;
    }
  }

  static double _distToGate(SimBall b) => sqrt(b.x * b.x + (b.y - 1) * (b.y - 1));

  void _go(AirMixPhase next) {
    phase = next;
    _phaseAt = time;
  }

  /// 공기 흐름 — 가운데에서 솟는 바람 + 바닥에서 가운데로 모이는 흐름 + 잡음 난류
  (double, double) _air(double x, double y, double assist) {
    if (blower <= 0.001) return (0, 0);
    // 출구관 안은 위로 빨아올린다
    if (y > gateY - radius * 0.5 && x.abs() < gap && gateOpen) {
      return (-x * 6, 5.5 * blower);
    }
    final core = 1 / (1 + (x / _jetWidth) * (x / _jetWidth));
    final height = 0.7 + 0.3 * (1 - (y + 1) / 2);
    var ux = 0.0;
    var uy = _jet * assist * core * height;
    if (y < -0.45) ux -= x * 1.8 * (-0.45 - y) / 0.55;
    // 위쪽 벽을 따라 바깥으로 퍼진다
    if (y > 0.55) ux += x.sign * 1.2 * (y - 0.55) * core;
    ux += _turbulence * _noise(x * 2.4, y * 2.4, time * 1.3, 0);
    uy += _turbulence * _noise(x * 2.4, y * 2.4, time * 1.3, 1);
    return (ux * blower, uy * blower);
  }

  void _collideBalls() {
    const d = radius * 2;
    for (var i = 0; i < balls.length; i++) {
      final a = balls[i];
      if (!a.inPlay) continue;
      for (var j = i + 1; j < balls.length; j++) {
        final b = balls[j];
        if (!b.inPlay) continue;
        final dx = b.x - a.x, dy = b.y - a.y;
        final dist2 = dx * dx + dy * dy;
        if (dist2 >= d * d || dist2 == 0) continue;
        final dist = sqrt(dist2);
        final nx = dx / dist, ny = dy / dist;
        final push = (d - dist) * 0.5 * 0.9;
        a
          ..x -= nx * push
          ..y -= ny * push;
        b
          ..x += nx * push
          ..y += ny * push;
        final vn = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny;
        if (vn < 0) {
          final imp = -(1 + _ballBounce) * vn / 2;
          a
            ..vx -= imp * nx
            ..vy -= imp * ny;
          b
            ..vx += imp * nx
            ..vy += imp * ny;
        }
      }
    }
  }

  void _collideWalls(SimBall b) {
    // 출구관 안 — 양옆 벽
    if (b.y > gateY && b.x.abs() < gap) {
      if (!gateOpen && !b.leaving) {
        // 닫힌 문 아래로 밀어낸다
        b.y = gateY - radius;
        if (b.vy > 0) b.vy = -b.vy * _wallBounce;
        return;
      }
      final lim = gap - radius;
      if (b.x.abs() > lim) {
        b.x = lim * b.x.sign;
        b.vx = -b.vx * _wallBounce;
      }
      return;
    }

    final dist = sqrt(b.x * b.x + b.y * b.y);
    if (dist == 0) return;
    final nx = b.x / dist, ny = b.y / dist;
    final inGap = (gateOpen || b.leaving) && ny > 0 && (nx * 1).abs() < gap;
    if (dist > 1 - radius && !inGap) {
      b
        ..x = nx * (1 - radius)
        ..y = ny * (1 - radius);
      final vn = b.vx * nx + b.vy * ny;
      if (vn > 0) {
        b
          ..vx -= (1 + _wallBounce) * vn * nx
          ..vy -= (1 + _wallBounce) * vn * ny;
      }
      b
        ..vx *= 0.995
        ..vy *= 0.995;
    }
    if (inGap || gateOpen) {
      // 출구 모서리 두 점
      for (final cx in [-gap, gap]) {
        final dx = b.x - cx, dy = b.y - gateY;
        final d2 = dx * dx + dy * dy;
        if (d2 < radius * radius && d2 > 0) {
          final d = sqrt(d2);
          final mx = dx / d, my = dy / d;
          b
            ..x = cx + mx * radius
            ..y = gateY + my * radius;
          final vn = b.vx * mx + b.vy * my;
          if (vn < 0) {
            b
              ..vx -= (1 + _wallBounce) * vn * mx
              ..vy -= (1 + _wallBounce) * vn * my;
          }
        }
      }
    }
  }

  void _checkExit() {
    if (phase != AirMixPhase.open) return;
    for (final b in balls) {
      if (!b.inPlay) continue;
      if (b.y > gateY + radius * 0.2 && b.x.abs() < gap) b.leaving = true;
      if (b.y > exitY) {
        b
          ..inPlay = false
          ..leaving = false;
        drawnIds.add(b.id);
        gateOpen = false;
        // 출구관에 같이 들어와 있던 구슬은 통 안으로 돌려보낸다
        for (final o in balls) {
          if (o.inPlay && o.y > gateY - radius) {
            o
              ..leaving = false
              ..y = gateY - radius * 1.05
              ..vy = -0.5;
          }
        }
        _go(drawnIds.length >= drawCount ? AirMixPhase.done : AirMixPhase.pause);
        return;
      }
    }
  }

  // ───────────────────────── 시드 · 잡음 ─────────────────────────

  /// 넣는 순서 → 32비트 시드 (FNV-1a)
  static int seedOf(List<int> order) {
    var h = 0x811c9dc5;
    for (final v in order) {
      h ^= v & 0xff;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h;
  }

  static int _hash(int a) {
    var x = a & 0xffffffff;
    x = ((x ^ (x >> 16)) * 0x45d9f3b) & 0xffffffff;
    x = ((x ^ (x >> 16)) * 0x45d9f3b) & 0xffffffff;
    return x ^ (x >> 16);
  }

  double _lattice(int ix, int iy, int it, int ch) {
    final h = _hash(seed ^ (ix * 73856093) ^ (iy * 19349663) ^ (it * 83492791) ^ (ch * 0x9e3779b1));
    return h / 0xffffffff * 2 - 1;
  }

  /// 값 잡음 (3차원, 부드러운 보간)
  double _noise(double x, double y, double t, int ch) {
    final ix = x.floor(), iy = y.floor(), it = t.floor();
    double s(double v) => v * v * (3 - 2 * v);
    final fx = s(x - ix), fy = s(y - iy), ft = s(t - it);
    double lerp(double a, double b, double f) => a + (b - a) * f;
    double plane(int tt) => lerp(
          lerp(_lattice(ix, iy, tt, ch), _lattice(ix + 1, iy, tt, ch), fx),
          lerp(_lattice(ix, iy + 1, tt, ch), _lattice(ix + 1, iy + 1, tt, ch), fx),
          fy,
        );
    return lerp(plane(it), plane(it + 1), ft);
  }
}

/// 작은 결정적 난수 (mulberry32)
class _Mulberry32 {
  _Mulberry32(int seed) : _s = seed & 0xffffffff;

  int _s;

  double next() {
    _s = (_s + 0x6d2b79f5) & 0xffffffff;
    var t = _s;
    t = ((t ^ (t >> 15)) * (t | 1)) & 0xffffffff;
    t ^= (t + (((t ^ (t >> 7)) * (t | 61)) & 0xffffffff)) & 0xffffffff;
    return ((t ^ (t >> 14)) & 0xffffffff) / 4294967296;
  }
}
