import 'dart:math';

import 'package:get/get.dart';

import '../../core/draw/airmix_sim.dart';
import '../../core/draw/draw_rules.dart';
import '../../data/models/locker_models.dart';
import 'locker_controller.dart';

/// 추첨 화면의 단계 — 위쪽 진행 표시에 그대로 쓴다
enum DrawStep {
  rules('규칙'),
  picks('숫자 고르기'),
  draw('추첨'),
  result('결과'),
  areas('영역 고르기'),
  place('팀별 배치');

  const DrawStep(this.label);
  final String label;
}

/// 팀장 추첨 화면 — 규칙 안내 → 숫자 고르기 → 추첨 → 결과(동점이면 재대결) → 영역 고르기 → 팀별 배치
///
/// 기록은 [LockerState.draw] 에 두어 앱을 껐다 켜도 이어서 할 수 있다.
class DrawController extends GetxController {
  static DrawController get to => Get.find();

  LockerController get c => LockerController.to;

  final step = DrawStep.rules.obs;

  /// 화면을 다시 그리게 할 때 올린다
  final version = 0.obs;

  /// 규칙 안내 쪽 번호
  final tutorialPage = 0.obs;

  /// 고른 숫자를 추첨 전까지 가린다 — 한 화면을 다 같이 보므로
  final hidePicks = true.obs;

  /// 숫자를 고르고 있는 팀
  final pickingTeam = RxnString();

  /// 고르는 중인 숫자 (확정 전)
  final draft = <int>[].obs;

  /// 추첨기
  AirMixSim? sim;

  /// [sim] 이 돌리는 판
  DrawRound? _simFor;
  final speed = 1.obs;
  final running = false.obs;

  /// 추첨 전 무대에 보여 줄, 구슬이 가라앉아 있는 통
  late final AirMixSim idleSim = AirMixSim(List.generate(DrawRules.poolSize, (i) => i))
    ..advance(DrawRules.poolSize * 0.07 + 0.9);

  DrawRecord? get record => c.state.draw;
  DrawRound? get round => record?.rounds.lastOrNull;

  /// 재대결 판인가
  bool get isRematch => (record?.rounds.length ?? 0) > 1;

  @override
  void onInit() {
    super.onInit();
    step.value = _resumeStep();
    if (step.value == DrawStep.picks) _selectNextPicker();
  }

  /// 저장된 기록을 보고 이어서 할 단계를 고른다.
  DrawStep _resumeStep() {
    final rec = record;
    final r = round;
    if (rec == null || r == null) return DrawStep.rules;
    if (!_allPicked(r)) return DrawStep.picks;
    if (r.drawn.length < DrawRules.drawCount) return DrawStep.draw;
    if (DrawRules.pendingTie(rec.standings) != null) return DrawStep.result;
    if (nextChooser != null) return DrawStep.areas;
    return DrawStep.place;
  }

  void _bump() => version.value++;

  // ───────────────────────── 팀 ─────────────────────────

  /// 추첨에 나갈 수 있는 팀 — 배치 대상 멤버가 한 명 이상
  List<Team> get eligibleTeams => c.state.teams
      .where((t) => c.membersOf(t.id).any((m) => !m.excluded))
      .toList();

  Team? team(String? id) => c.teamById(id);

  String teamName(String id) => team(id)?.name ?? '?';

  String? leaderName(String id) => c.memberById(team(id)?.leaderId)?.name;

  // ───────────────────────── 규칙 → 시작 ─────────────────────────

  void goTo(DrawStep s) {
    if (!canGoTo(s)) return;
    step.value = s;
    if (s == DrawStep.picks) _selectNextPicker();
  }

  /// 진행 표시를 눌러 옮겨 갈 수 있는가 — 지나온 단계와 규칙 안내만
  bool canGoTo(DrawStep s) {
    if (running.value) return false;
    if (s == DrawStep.rules) return true;
    return s.index <= _resumeStep().index;
  }

  /// 새 추첨 (본선) — 고른 숫자 · 결과 · 가져간 영역을 모두 지운다.
  void startNew() {
    final teams = eligibleTeams;
    if (teams.length < 2) return;
    sim = null;
    _simFor = null;
    c.startDraw([for (final t in teams) t.id]);
    step.value = DrawStep.picks;
    _selectNextPicker();
    _bump();
  }

  // ───────────────────────── 숫자 고르기 ─────────────────────────

  bool _allPicked(DrawRound r) =>
      r.teamIds.every((id) => (r.picks[id]?.length ?? 0) == DrawRules.picksPerTeam);

  bool get allPicked => round != null && _allPicked(round!);

  bool isPicked(String teamId) => (round?.picks[teamId]?.length ?? 0) == DrawRules.picksPerTeam;

  void selectPicker(String teamId) {
    pickingTeam.value = teamId;
    draft.assignAll(round?.picks[teamId] ?? const []);
  }

  void _selectNextPicker() {
    final r = round;
    if (r == null) return;
    final next = r.teamIds.firstWhereOrNull((id) => !isPicked(id));
    pickingTeam.value = next;
    draft.assignAll(next == null ? const [] : (r.picks[next] ?? const []));
  }

  bool canAdd(int number) => DrawRules.canPick(draft, number);

  void addPick(int number) {
    if (!canAdd(number)) return;
    draft.add(number);
  }

  void removeLastPick() {
    if (draft.isNotEmpty) draft.removeLast();
  }

  void removePickAt(int i) {
    if (i < draft.length) draft.removeAt(i);
  }

  void clearDraft() => draft.clear();

  /// 고른 숫자를 확정하고 다음 팀으로
  void confirmPicks() {
    final id = pickingTeam.value;
    final r = round;
    if (id == null || r == null || draft.length != DrawRules.picksPerTeam) return;
    r.picks[id] = [...draft]..sort();
    c.touchDraw();
    _selectNextPicker();
    _bump();
  }

  /// 확정한 숫자를 다시 고른다
  void unpick(String teamId) {
    final r = round;
    if (r == null) return;
    selectPicker(teamId);
    r.picks.remove(teamId);
    c.touchDraw();
    _bump();
  }

  // ───────────────────────── 추첨 ─────────────────────────

  void openDraw() {
    if (!allPicked) return;
    step.value = DrawStep.draw;
    final r = round!;
    // 다시 들어왔을 때 (껐다 켰거나 결과에서 돌아옴) 같은 순서로 다시 보여 준다
    if (r.loadOrder != null && _simFor != r) {
      sim = AirMixSim(r.loadOrder!);
      _simFor = r;
      if (r.drawn.length >= DrawRules.drawCount) sim!.runToEnd();
    }
    _bump();
  }

  /// 추첨 시작 — 넣는 순서를 무작위로 정해 기록하고 돌린다.
  void startMachine() {
    final r = round;
    if (r == null || running.value) return;
    if (r.loadOrder == null || r.drawn.length >= DrawRules.drawCount) {
      r.loadOrder = List.generate(DrawRules.poolSize, (i) => i)..shuffle(Random.secure());
      r.drawn.clear();
      c.touchDraw();
    }
    sim = AirMixSim(r.loadOrder!);
    _simFor = r;
    running.value = true;
    _bump();
  }

  /// 무대가 매 프레임 부른다. 새로 뽑힌 구슬이 있으면 true.
  bool tick(double seconds) {
    final s = sim;
    if (s == null || !running.value) return false;
    final before = s.drawnIds.length;
    s.advance(min(seconds * speed.value, 0.25));
    if (s.done) _finishRound();
    return s.drawnIds.length != before;
  }

  /// 연출을 건너뛰고 결과까지 바로 계산한다 (같은 순서면 결과는 같다).
  void skipToEnd() {
    final s = sim;
    if (s == null) return;
    s.runToEnd();
    _finishRound();
  }

  void _finishRound() {
    final s = sim!;
    final r = round!;
    final rec = record!;
    running.value = false;
    r.drawn
      ..clear()
      ..addAll(s.drawnNumbers);
    final scores = scoresOf(r);
    final next = rec.rounds.length == 1
        ? DrawRules.rank(scores)
        : DrawRules.resolve(rec.standings, r.teamIds, scores);
    rec.standings
      ..clear()
      ..addAll(next);
    c.touchDraw();
    _bump();
    // 마지막 구슬을 잠깐 보여 준 뒤 결과로 넘어간다.
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (step.value == DrawStep.draw && !running.value && round == r) showResult();
    });
  }

  void showResult() {
    step.value = DrawStep.result;
    _bump();
  }

  /// 지금까지 나온 숫자 — 추첨 중이면 기계에서, 끝났으면 기록에서
  List<int> get drawnSoFar {
    final s = sim;
    if (s != null && _simFor == round) return s.drawnNumbers;
    return round?.drawn ?? const [];
  }

  Map<String, TeamScore> scoresOf(DrawRound r, [List<int>? drawn]) => {
        for (final id in r.teamIds) id: DrawRules.score(r.picks[id] ?? const [], drawn ?? r.drawn),
      };

  /// 추첨 중 실시간 점수
  TeamScore liveScore(String teamId) =>
      DrawRules.score(round?.picks[teamId] ?? const [], drawnSoFar);

  /// 같은 넣는 순서로 다시 돌려 결과가 같은지 확인한다.
  bool verifyReplay(DrawRound r) {
    final order = r.loadOrder;
    if (order == null) return false;
    final again = AirMixSim(order)..runToEnd();
    return _listEquals(again.drawnNumbers, r.drawn);
  }

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ───────────────────────── 결과 · 재대결 ─────────────────────────

  List<String>? get pendingTie {
    final rec = record;
    return rec == null ? null : DrawRules.pendingTie(rec.standings);
  }

  /// 순위가 다 정해졌으면 팀 순서, 아니면 null
  List<String>? get ranking {
    final rec = record;
    if (rec == null || rec.standings.isEmpty || pendingTie != null) return null;
    return [for (final g in rec.standings) g.single];
  }

  /// [teamId] 의 순위 (1부터). 동점 묶음이면 묶음의 순위.
  int rankOf(String teamId) {
    var rank = 1;
    for (final g in record?.standings ?? const <List<String>>[]) {
      if (g.contains(teamId)) return rank;
      rank += g.length;
    }
    return 0;
  }

  /// 동점 팀끼리 재대결 — 숫자 고르기부터 다시
  void startRematch() {
    final tie = pendingTie;
    final rec = record;
    if (tie == null || rec == null) return;
    rec.rounds.add(DrawRound(teamIds: [...tie]));
    sim = null;
    _simFor = null;
    c.touchDraw();
    step.value = DrawStep.picks;
    _selectNextPicker();
    _bump();
  }

  // ───────────────────────── 영역 ─────────────────────────

  /// 다음에 영역을 고를 팀 — 순위가 다 정해진 뒤, 아직 영역이 없는 가장 높은 팀
  String? get nextChooser {
    final order = ranking;
    if (order == null) return null;
    if (!c.state.areas.any((a) => a.teamId == null)) return null;
    return order.firstWhereOrNull((id) => c.areaOfTeam(id) == null);
  }

  void openAreas() {
    step.value = DrawStep.areas;
    _bump();
  }

  void chooseArea(String areaId) {
    final teamId = nextChooser;
    final area = c.areaById(areaId);
    if (teamId == null || area == null || area.teamId != null) return;
    c.takeArea(teamId, areaId);
    _bump();
  }

  /// 영역 고르기를 처음부터
  void resetAreas() {
    c.releaseAreas();
    _bump();
  }

  void openPlace() {
    step.value = DrawStep.place;
    _bump();
  }
}
