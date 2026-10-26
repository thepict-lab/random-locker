import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:random_locker/core/draw/airmix_sim.dart';
import 'package:random_locker/core/draw/draw_rules.dart';

void main() {
  List<int> shuffled(int seed) => List.generate(DrawRules.poolSize, (i) => i)..shuffle(Random(seed));

  test('같은 넣는 순서면 같은 결과', () {
    final order = shuffled(1);
    final a = AirMixSim(order)..runToEnd();
    final b = AirMixSim(order)..runToEnd();
    expect(a.drawnIds, b.drawnIds);
  });

  test('나눠 돌려도 (화면 속도와 상관없이) 같은 결과', () {
    final order = shuffled(2);
    final a = AirMixSim(order)..runToEnd();
    final b = AirMixSim(order);
    while (!b.done) {
      b.advance(0.37);
    }
    expect(b.drawnIds, a.drawnIds);
  });

  test('서로 다른 구슬 11개를 적당한 시간 안에 뽑는다', () {
    final times = <double>[];
    final firsts = <int>{};
    for (var s = 0; s < 12; s++) {
      final sim = AirMixSim(shuffled(100 + s))..runToEnd();
      expect(sim.done, isTrue);
      expect(sim.drawnIds.length, DrawRules.drawCount);
      expect(sim.drawnIds.toSet().length, DrawRules.drawCount);
      times.add(sim.time);
      firsts.add(sim.drawnIds.first);
    }
    // ignore: avoid_print
    print('추첨 시간(초): ${times.map((t) => t.toStringAsFixed(1)).join(', ')}');
    expect(times.every((t) => t < 90), isTrue);
    expect(firsts.length, greaterThan(6)); // 순서가 달라지면 결과도 달라진다
  });
}
