import 'dart:math';

/// 팀장 추첨 규칙
///
/// - 구슬 통: 숫자 k 구슬이 11 − k 개 (1 이 10개 … 10 이 1개), 모두 55개
/// - 팀장마다 숫자 11개를 고른다. 같은 숫자를 여러 번 골라도 되지만 그 숫자 구슬 개수를 넘을 수 없다
/// - 추첨기가 11개를 뽑는다
/// - 숫자마다 (고른 횟수)와 (나온 개수) 중 작은 쪽만큼 그 숫자를 더한 것이 점수
/// - 점수가 높은 순으로 순위를 매긴다. 동점이면 이미 순위가 정해진 팀은 빼고
///   동점인 팀끼리 숫자 고르기부터 다시 한다 (재대결)
abstract final class DrawRules {
  static const maxNumber = 10;
  static const picksPerTeam = 11;
  static const drawCount = 11;

  static int ballsOf(int number) => maxNumber + 1 - number;

  static int get poolSize => maxNumber * (maxNumber + 1) ~/ 2;

  /// 구슬 번호(0 부터) → 숫자. 1 이 10개, 2 가 9개 … 순서
  static List<int> pool() => [
        for (var n = 1; n <= maxNumber; n++)
          for (var i = 0; i < ballsOf(n); i++) n,
      ];

  /// 한 팀장이 [number] 를 고를 수 있는 최대 횟수
  static int maxPicksOf(int number) => min(ballsOf(number), picksPerTeam);

  static bool canPick(List<int> picks, int number) =>
      picks.length < picksPerTeam &&
      picks.where((n) => n == number).length < ballsOf(number);

  /// [drawCount] 개를 뽑을 때 [number] 가 평균 몇 개 나오는가
  static double expectedCount(int number) => drawCount * ballsOf(number) / poolSize;

  static TeamScore score(List<int> picks, List<int> drawn) {
    final lines = <ScoreLine>[];
    for (final n in {...picks}.toList()..sort()) {
      final picked = picks.where((x) => x == n).length;
      final out = drawn.where((x) => x == n).length;
      lines.add(ScoreLine(number: n, picked: picked, drawn: out));
    }
    return TeamScore(lines);
  }

  /// 순위 묶음 — 앞 묶음이 위. 한 묶음에 둘 이상이면 동점이라 재대결해야 한다.
  /// 묶음 안은 [scores] 에 넣은 순서를 지킨다.
  static List<List<String>> rank(Map<String, TeamScore> scores) {
    final ids = scores.keys.toList();
    int cmp(String a, String b) => scores[b]!.points - scores[a]!.points;

    final sorted = [...ids]..sort((a, b) {
        final c = cmp(a, b);
        return c != 0 ? c : ids.indexOf(a) - ids.indexOf(b);
      });
    final groups = <List<String>>[];
    for (final id in sorted) {
      if (groups.isNotEmpty && cmp(groups.last.first, id) == 0) {
        groups.last.add(id);
      } else {
        groups.add([id]);
      }
    }
    return groups;
  }

  /// [standings] 에서 [group] (동점 묶음) 자리를 이번 판 [scores] 의 순위로 바꿔 끼운다.
  static List<List<String>> resolve(
    List<List<String>> standings,
    List<String> group,
    Map<String, TeamScore> scores,
  ) {
    final i = standings.indexWhere((g) => g.length == group.length && g.every(group.contains));
    if (i < 0) return standings;
    return [...standings.sublist(0, i), ...rank(scores), ...standings.sublist(i + 1)];
  }

  /// 아직 재대결이 남은 (가장 높은 순위의) 동점 묶음. 없으면 순위가 다 정해졌다.
  static List<String>? pendingTie(List<List<String>> standings) =>
      standings.firstWhereOrNull((g) => g.length > 1);
}

extension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final x in this) {
      if (test(x)) return x;
    }
    return null;
  }
}

/// 점수표 한 줄 — 숫자 하나
class ScoreLine {
  const ScoreLine({required this.number, required this.picked, required this.drawn});

  final int number;

  /// 고른 횟수
  final int picked;

  /// 나온 개수
  final int drawn;

  /// 인정한 개수 — 고른 횟수와 나온 개수 중 작은 쪽
  int get matched => min(picked, drawn);

  int get points => number * matched;
}

class TeamScore {
  const TeamScore(this.lines);

  final List<ScoreLine> lines;

  int get points => lines.fold(0, (s, l) => s + l.points);

  int get matched => lines.fold(0, (s, l) => s + l.matched);
}
