import 'package:flutter_test/flutter_test.dart';
import 'package:random_locker/core/draw/draw_rules.dart';

void main() {
  test('구슬 통 — 1이 10개 … 10이 1개, 모두 55개', () {
    final pool = DrawRules.pool();
    expect(pool.length, 55);
    expect(pool.where((n) => n == 1).length, 10);
    expect(pool.where((n) => n == 7).length, 4);
    expect(pool.where((n) => n == 10).length, 1);
  });

  test('한 숫자는 구슬 개수만큼만 고를 수 있다', () {
    expect(DrawRules.canPick([10], 10), isFalse);
    expect(DrawRules.canPick([9], 9), isTrue);
    expect(DrawRules.canPick([9, 9], 9), isFalse);
    expect(DrawRules.canPick(List.filled(9, 1), 1), isTrue);
    expect(DrawRules.canPick(List.filled(10, 1), 1), isFalse); // 1 구슬은 10개뿐
    expect(DrawRules.canPick([...List.filled(10, 1), 2], 3), isFalse); // 11개를 다 골랐다
    expect(DrawRules.maxPicksOf(1), 10);
    expect(DrawRules.maxPicksOf(8), 3);
  });

  group('점수', () {
    // 15개가 1×4, 2×3, 3×2, 4×2, 5, 6, 7, 8 로 나왔을 때
    const drawn = [1, 1, 1, 1, 2, 2, 2, 3, 3, 4, 4, 5, 6, 7, 8];

    test('A — 3,3,4,4,8 은 22점', () {
      final s = DrawRules.score([3, 3, 4, 4, 8], drawn);
      expect(s.points, 22);
      expect(s.matched, 5);
    });

    test('B — 1,1,1,9,10 은 3점 (9 · 10 은 안 나옴)', () {
      final s = DrawRules.score([1, 1, 1, 9, 10], drawn);
      expect(s.points, 3);
      expect(s.matched, 3);
    });

    test('C — 5,5,6,7,8 은 26점 (5 는 하나만 나와 한 번만 인정)', () {
      final s = DrawRules.score([5, 5, 6, 7, 8], drawn);
      expect(s.points, 26);
      final five = s.lines.firstWhere((l) => l.number == 5);
      expect((five.picked, five.drawn, five.matched, five.points), (2, 1, 1, 5));
    });

    test('1 을 2번 골랐는데 1 이 3개 나오면 2점', () {
      expect(DrawRules.score([1, 1], [1, 1, 1]).points, 2);
    });
  });

  group('순위', () {
    test('점수 순, 같은 점수는 한 묶음 (재대결)', () {
      final groups = DrawRules.rank({
        'a': DrawRules.score([3, 3, 4, 4, 8], const [3, 3, 4, 4, 8]), // 22점
        'b': DrawRules.score([10, 9, 3], const [10, 9, 3]), // 22점
        'c': DrawRules.score([2], const [2]), // 2점
        'd': DrawRules.score([7], const [7]), // 7점
        'e': DrawRules.score([1, 1], const [1, 1]), // 2점
      });
      expect(groups, [
        ['a', 'b'],
        ['d'],
        ['c', 'e'],
      ]);
    });

    test('재대결 — 동점 묶음 자리를 재대결 결과로 바꿔 끼운다', () {
      final standings = [
        ['a', 'b'],
        ['d'],
        ['c', 'e'],
      ];
      final next = DrawRules.resolve(standings, ['a', 'b'], {
        'a': DrawRules.score([5], const [1]), // 0점
        'b': DrawRules.score([1], const [1]), // 1점
      });
      expect(next, [
        ['b'],
        ['a'],
        ['d'],
        ['c', 'e'],
      ]);
      expect(DrawRules.pendingTie(next), ['c', 'e']);
      expect(DrawRules.pendingTie([['a'], ['b']]), isNull);
    });
  });

  test('기대 개수 — 11 × (11 − k) / 55', () {
    expect(DrawRules.expectedCount(1), closeTo(2.0, 0.001));
    expect(DrawRules.expectedCount(10), closeTo(0.2, 0.001));
  });
}
