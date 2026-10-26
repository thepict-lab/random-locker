import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/draw/airmix_sim.dart';
import '../../core/draw/draw_rules.dart';
import '../../core/theme/app_colors.dart';
import '../../main.dart';
import '../controller/draw_controller.dart';
import '../controller/locker_controller.dart';
import '../widget/area_dialog.dart';
import '../widget/area_map.dart';
import '../widget/draw/airmix_stage.dart';
import '../widget/draw/draw_ball.dart';
import '../widget/draw/draw_tutorial.dart';
import '../widget/team_dialog.dart';

/// 팀장 추첨 화면 — lotto-airmix 처럼 왼쪽에 추첨기 무대, 오른쪽에 진행 패널
class DrawScreen extends StatelessWidget {
  const DrawScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = DrawController.to;
    return Scaffold(
      backgroundColor: DrawColors.bg,
      body: Column(
        children: [
          const _Header(),
          Expanded(
            child: Obx(() {
              d.version.value;
              LockerController.to.version.value;
              return switch (d.step.value) {
                DrawStep.rules => DrawTutorial(onStart: () => _start(context)),
                DrawStep.picks => const _Split(left: _PicksLeft(), right: _PickPanel()),
                DrawStep.draw => const _Split(left: _MachineLeft(), right: _LivePanel()),
                DrawStep.result => const _Split(left: _MachineLeft(), right: _ResultPanel()),
                DrawStep.areas => const _Split(left: _AreasLeft(), right: _AreaPanel()),
                DrawStep.place => const _Split(left: _PlaceLeft(), right: _PlacePanel()),
              };
            }),
          ),
        ],
      ),
    );
  }

  /// 규칙 안내의 [시작하기] — 진행 중인 추첨이 있으면 이어서, 없으면 새로
  static Future<void> _start(BuildContext context) async {
    final d = DrawController.to;
    if (d.record != null) {
      final resume = DrawStep.values.lastWhere(d.canGoTo);
      if (resume != DrawStep.rules) {
        d.goTo(resume);
        return;
      }
    }
    if (!await ensureTeams(context)) return;
    d.startNew();
  }

  /// 추첨할 수 있게 팀이 둘 이상 있는지 — 없으면 팀 설정으로 안내한다.
  static Future<bool> ensureTeams(BuildContext context) async {
    final d = DrawController.to;
    if (d.eligibleTeams.length >= 2) return true;
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('팀을 먼저 만들어 주세요'),
        content: const Text('추첨하려면 멤버가 있는 팀이 둘 이상 있어야 합니다.\n'
            '팀 설정에서 팀을 만들고 이름을 팀으로 끌어다 놓아 소속을 정해 주세요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('팀 설정')),
        ],
      ),
    );
    if (go == true && context.mounted) await showTeamDialog(context);
    return d.eligibleTeams.length >= 2;
  }
}

// ───────────────────────── 머리 ─────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  Future<void> _newDraw(BuildContext context) async {
    final d = DrawController.to;
    if (d.running.value) return;
    if (d.record != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('새 추첨'),
          content: const Text('고른 숫자 · 추첨 결과 · 팀이 가져간 영역을 모두 지우고 처음부터 합니다.\n'
              '신발장 배치는 그대로 둡니다.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('새로 시작')),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (!context.mounted || !await DrawScreen.ensureTeams(context)) return;
    d.startNew();
  }

  @override
  Widget build(BuildContext context) {
    final d = DrawController.to;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 32, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            tooltip: '신발장 화면으로',
            onPressed: () {
              if (!d.running.value) Get.back();
            },
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 8),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('AIR-MIX DRAW',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w700,
                      color: DrawColors.muted)),
              SizedBox(height: 4),
              Text('팀장 우선권 추첨',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: DrawColors.fg)),
            ],
          ),
          const SizedBox(width: 28),
          Expanded(
            child: Obx(() {
              d.version.value;
              final now = d.step.value;
              return Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in DrawStep.values)
                    _StepPill(
                      label: s == DrawStep.picks && d.isRematch ? '재대결 숫자 고르기' : s.label,
                      active: s == now,
                      done: s.index < now.index,
                      onTap: d.canGoTo(s) ? () => d.goTo(s) : null,
                    ),
                ],
              );
            }),
          ),
          TextButton.icon(
            onPressed: () => showTeamDialog(context),
            icon: const Icon(Icons.groups_rounded),
            label: const Text('팀 설정'),
            style: TextButton.styleFrom(foregroundColor: DrawColors.fg),
          ),
          TextButton.icon(
            onPressed: () => showAreaDialog(context),
            icon: const Icon(Icons.dashboard_customize_outlined),
            label: const Text('영역 설정'),
            style: TextButton.styleFrom(foregroundColor: DrawColors.fg),
          ),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            onPressed: () => _newDraw(context),
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('새 추첨'),
            style: OutlinedButton.styleFrom(
              foregroundColor: DrawColors.fg,
              side: const BorderSide(color: DrawColors.line),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill({required this.label, required this.active, required this.done, this.onTap});

  final String label;
  final bool active;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? DrawColors.accent : DrawColors.line),
            color: active ? Colors.white : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? DrawColors.accent : (done ? DrawColors.good : DrawColors.line),
                boxShadow: active
                    ? [BoxShadow(color: DrawColors.accent.withValues(alpha: 0.35), spreadRadius: 3)]
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? DrawColors.fg : DrawColors.muted,
                )),
          ]),
        ),
      );
}

// ───────────────────────── 틀 ─────────────────────────

/// 추첨 기록 · 신발장 상태가 바뀌면 다시 그리는 위젯
abstract class _Reactive extends StatelessWidget {
  const _Reactive();

  Widget buildReactive(BuildContext context);

  @override
  Widget build(BuildContext context) => Obx(() {
        DrawController.to.version.value;
        DrawController.to.running.value;
        LockerController.to.version.value;
        return buildReactive(context);
      });
}

/// 왼쪽 넓게 + 오른쪽 패널
class _Split extends StatelessWidget {
  const _Split({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: left),
            const SizedBox(width: 18),
            SizedBox(width: 440, child: _Panel(child: right)),
          ],
        ),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
        color: DrawColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: DrawColors.line),
        ),
        child: Padding(padding: const EdgeInsets.all(20), child: child),
      );
}

/// 패널 제목 — 노란 번호표 + 제목
class _PanelTitle extends StatelessWidget {
  const _PanelTitle(this.n, this.title, {this.trailing});

  final String n;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration:
                BoxDecoration(color: DrawColors.accent, borderRadius: BorderRadius.circular(6)),
            child: Text(n,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: DrawColors.accentFg)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: DrawColors.fg)),
          ),
          ?trailing,
        ]),
      );
}

class _TeamDot extends StatelessWidget {
  const _TeamDot(this.teamId, {this.size = 12});

  final String teamId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = DrawController.to.team(teamId);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.teamColor(t?.color ?? 0),
      ),
    );
  }
}

/// "1팀 · 팀장 창대"
class _TeamLabel extends StatelessWidget {
  const _TeamLabel(this.teamId, {this.size = 16});

  final String teamId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final d = DrawController.to;
    final leader = d.leaderName(teamId);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _TeamDot(teamId, size: size * 0.7),
      const SizedBox(width: 8),
      Flexible(
        child: Text.rich(
          TextSpan(children: [
            TextSpan(
                text: d.teamName(teamId),
                style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: DrawColors.fg)),
            if (leader != null)
              TextSpan(
                  text: '  팀장 $leader',
                  style: TextStyle(fontSize: size * 0.8, color: DrawColors.muted)),
          ]),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ]);
  }
}

// ───────────────────────── 숫자 고르기 ─────────────────────────

class _PicksLeft extends StatelessWidget {
  const _PicksLeft();

  @override
  Widget build(BuildContext context) {
    final d = DrawController.to;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _StageCard(sim: d.idleSim, overlay: _rematchBanner())),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DrawColors.panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: DrawColors.line),
          ),
          child: Obx(() {
            d.version.value;
            final r = d.round!;
            final picking = d.pickingTeam.value;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final id in r.teamIds)
                  _TeamPickCard(
                    teamId: id,
                    picks: r.picks[id],
                    active: id == picking,
                    hide: d.hidePicks.value,
                    onTap: () => d.isPicked(id) ? d.unpick(id) : d.selectPicker(id),
                  ),
              ],
            );
          }),
        ),
      ],
    );
  }

  Widget? _rematchBanner() {
    final d = DrawController.to;
    if (!d.isRematch) return null;
    return Positioned(
      left: 16,
      right: 16,
      top: 16,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xA0080B10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: DrawColors.accent),
          ),
          child: Text(
            '재대결 ${d.record!.rounds.length - 1}차 — ${d.round!.teamIds.map(d.teamName).join(' · ')}',
            style: const TextStyle(
                color: DrawColors.accent, fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

class _TeamPickCard extends StatelessWidget {
  const _TeamPickCard({
    required this.teamId,
    required this.picks,
    required this.active,
    required this.hide,
    required this.onTap,
  });

  final String teamId;
  final List<int>? picks;
  final bool active;
  final bool hide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = picks?.length == DrawRules.picksPerTeam;
    return Tooltip(
      message: done ? '눌러서 다시 고르기' : '눌러서 이 팀 고르기',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFFF8DB) : DrawColors.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? DrawColors.accent : Colors.transparent, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: _TeamLabel(teamId, size: 15)),
                if (done)
                  const Icon(Icons.check_circle_rounded, color: DrawColors.good, size: 20)
                else if (active)
                  const Text('고르는 중',
                      style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFB98F00)))
                else
                  const Text('대기', style: TextStyle(color: DrawColors.muted)),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 3, runSpacing: 3, children: [
                if (done)
                  for (final n in picks!) hide ? const HiddenBall(size: 22) : DrawBall(n, size: 22)
                else
                  for (var i = 0; i < DrawRules.picksPerTeam; i++) const EmptyBallSlot(size: 22),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickPanel extends StatelessWidget {
  const _PickPanel();

  @override
  Widget build(BuildContext context) {
    final d = DrawController.to;
    return Obx(() {
      d.version.value;
      final teamId = d.pickingTeam.value;
      final draft = d.draft.toList();
      if (teamId == null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _PanelTitle('2', '숫자 고르기 끝'),
            const Text('모든 팀장님이 숫자를 골랐습니다.\n추첨기로 가서 구슬을 뽑습니다.',
                style: TextStyle(fontSize: 15, height: 1.6, color: DrawColors.muted)),
            const Spacer(),
            _HideToggle(d: d),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: d.openDraw,
              icon: const Icon(Icons.casino_rounded),
              label: const Text('추첨기로'),
              style: accentButton,
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelTitle('2', '숫자 고르기'),
          _TeamLabel(teamId, size: 24),
          const SizedBox(height: 4),
          Text('${draft.length} / ${DrawRules.picksPerTeam}개 골랐습니다',
              style: const TextStyle(fontSize: 14, color: DrawColors.muted)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 5,
            shrinkWrap: true,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var n = 1; n <= DrawRules.maxNumber; n++) _PickChip(n),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: DrawColors.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (var i = 0; i < DrawRules.picksPerTeam; i++)
                  i < draft.length
                      ? Tooltip(
                          message: '빼기',
                          child: InkWell(
                            onTap: () => d.removePickAt(i),
                            customBorder: const CircleBorder(),
                            child: DrawBall(draft[i], size: 32),
                          ),
                        )
                      : EmptyBallSlot(size: 32, label: '${i + 1}'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            TextButton.icon(
              onPressed: draft.isEmpty ? null : d.removeLastPick,
              icon: const Icon(Icons.backspace_outlined, size: 18),
              label: const Text('하나 빼기'),
            ),
            TextButton(
              onPressed: draft.isEmpty ? null : d.clearDraft,
              child: const Text('모두 지우기'),
            ),
          ]),
          const Spacer(),
          _HideToggle(d: d),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: draft.length == DrawRules.picksPerTeam ? d.confirmPicks : null,
            icon: const Icon(Icons.check_rounded),
            label: Text(draft.length == DrawRules.picksPerTeam
                ? '확정하고 다음 팀으로'
                : '${DrawRules.picksPerTeam - draft.length}개 더 골라 주세요'),
            style: accentButton,
          ),
        ],
      );
    });
  }
}

class _HideToggle extends StatelessWidget {
  const _HideToggle({required this.d});

  final DrawController d;

  @override
  Widget build(BuildContext context) => Obx(() => SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        value: d.hidePicks.value,
        onChanged: (v) => d.hidePicks.value = v,
        title: const Text('고른 숫자 가리기 (추첨 때 공개)', style: TextStyle(fontSize: 13.5)),
      ));
}

class _PickChip extends StatelessWidget {
  const _PickChip(this.number);

  final int number;

  @override
  Widget build(BuildContext context) {
    final d = DrawController.to;
    final used = d.draft.where((x) => x == number).length;
    final left = DrawRules.maxPicksOf(number) - used;
    final can = d.canAdd(number);
    return Tooltip(
      message: '${DrawRules.ballsOf(number)}개 들어 있음 · 최대 ${DrawRules.maxPicksOf(number)}번',
      child: InkWell(
        onTap: can ? () => d.addPick(number) : null,
        customBorder: const CircleBorder(),
        child: LayoutBuilder(
          builder: (context, box) => Stack(
            clipBehavior: Clip.none,
            children: [
              DrawBall(number, size: box.maxWidth, dim: !can),
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 22),
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: left == 0 ? DrawColors.line : DrawColors.fg,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: Text('$left',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: left == 0 ? DrawColors.muted : DrawColors.bg)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 추첨기 ─────────────────────────

/// 어두운 무대 카드 — 추첨기 + 위 HUD
class _StageCard extends StatelessWidget {
  const _StageCard({required this.sim, this.onTick, this.overlay, this.hud = false});

  final AirMixSim sim;
  final void Function(double)? onTick;
  final Widget? overlay;
  final bool hud;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(child: AirMixStage(sim: sim, onTick: onTick)),
            if (hud) Positioned(left: 12, top: 12, child: _Hud(sim: sim)),
            ?overlay,
          ],
        ),
      );
}

/// 무대 위 상태 표시 — 단계 · 몇 번째 구슬 · 시간
class _Hud extends StatefulWidget {
  const _Hud({required this.sim});

  final AirMixSim sim;

  @override
  State<_Hud> createState() => _HudState();
}

class _HudState extends State<_Hud> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sim;
    final n = s.drawnIds.length;
    final detail = switch (s.phase) {
      AirMixPhase.loading => '${s.balls.where((b) => b.inPlay).length} / ${s.balls.length}개',
      AirMixPhase.pause || AirMixPhase.open => '${n + 1}번째 구슬 · ${DrawRules.drawCount}개 중',
      AirMixPhase.done => '$n개 모두 나왔습니다',
      _ => '',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x9E080B10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.phase.label,
              style: const TextStyle(
                  color: DrawColors.hudText, fontSize: 16, fontWeight: FontWeight.w700)),
          Text('$detail   ${s.time.toStringAsFixed(1)}초',
              style: const TextStyle(color: DrawColors.hudSub, fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _MachineLeft extends _Reactive {
  const _MachineLeft();

  @override
  Widget buildReactive(BuildContext context) {
    final d = DrawController.to;
    final sim = d.sim ?? d.idleSim;
    final result = d.step.value == DrawStep.result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _StageCard(
            sim: sim,
            hud: d.sim != null,
            onTick: (dt) {
              if (d.tick(dt)) d.version.value++;
            },
            overlay: result ? const Positioned.fill(child: _ResultOverlay()) : null,
          ),
        ),
        const SizedBox(height: 12),
        const _Tray(),
      ],
    );
  }
}

/// 나온 구슬 받침
class _Tray extends _Reactive {
  const _Tray();

  @override
  Widget buildReactive(BuildContext context) {
    final d = DrawController.to;
    final drawn = d.drawnSoFar;
    final order = d.round?.loadOrder;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: DrawColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DrawColors.line),
      ),
      child: Row(
        children: [
          const Text('나온 구슬',
              style: TextStyle(
                  fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: DrawColors.muted)),
          const SizedBox(width: 14),
          for (var i = 0; i < DrawRules.drawCount; i++)
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: i < drawn.length
                  ? TweenAnimationBuilder<double>(
                      key: ValueKey('$i-${drawn[i]}'),
                      tween: Tween(begin: 0.3, end: 1),
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutBack,
                      builder: (_, v, child) => Transform.scale(scale: v, child: child),
                      child: DrawBall(drawn[i], size: 44),
                    )
                  : EmptyBallSlot(size: 44, label: '${i + 1}'),
            ),
          const Spacer(),
          if (order != null)
            Tooltip(
              message: '넣은 순서(구슬 번호): ${order.join(' ')}',
              child: Text('시드 ${AirMixSim.seedOf(order).toRadixString(16).padLeft(8, '0')}',
                  style: const TextStyle(fontSize: 12, color: DrawColors.muted)),
            ),
        ],
      ),
    );
  }
}

/// 추첨 중 — 실시간 점수
class _LivePanel extends _Reactive {
  const _LivePanel();

  @override
  Widget buildReactive(BuildContext context) {
    final d = DrawController.to;
    final r = d.round!;
    final finished = r.drawn.length >= DrawRules.drawCount;
    final started = d.sim != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelTitle('3', d.isRematch ? '재대결 실시간 점수' : '실시간 점수',
            trailing: d.running.value ? const _SpeedSeg() : null),
        Expanded(
          child: ListView(
            children: [
              for (final id in r.teamIds) _LiveRow(teamId: id, revealed: started || !d.hidePicks.value),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!started)
          FilledButton.icon(
            onPressed: d.startMachine,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('추첨 시작'),
            style: accentButton,
          )
        else if (d.running.value)
          OutlinedButton.icon(
            onPressed: d.skipToEnd,
            icon: const Icon(Icons.fast_forward_rounded),
            label: const Text('건너뛰고 결과 보기'),
          )
        else if (finished)
          FilledButton.icon(
            onPressed: d.showResult,
            icon: const Icon(Icons.emoji_events_rounded),
            label: const Text('결과 보기'),
            style: accentButton,
          )
        else
          FilledButton.icon(
            onPressed: d.startMachine,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('추첨 시작'),
            style: accentButton,
          ),
      ],
    );
  }
}

class _SpeedSeg extends StatelessWidget {
  const _SpeedSeg();

  @override
  Widget build(BuildContext context) {
    final d = DrawController.to;
    return Obx(() => Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: DrawColors.bg, borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (final s in const [1, 2, 4, 8])
              InkWell(
                onTap: () => d.speed.value = s,
                borderRadius: BorderRadius.circular(7),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: d.speed.value == s ? DrawColors.accent : null,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text('$s×',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
          ]),
        ));
  }
}

class _LiveRow extends StatelessWidget {
  const _LiveRow({required this.teamId, required this.revealed});

  final String teamId;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    final d = DrawController.to;
    final picks = d.round!.picks[teamId] ?? const <int>[];
    final score = d.liveScore(teamId);
    final matched = {for (final l in score.lines) l.number: l.matched};
    final seen = <int, int>{};
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: DrawColors.bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TeamLabel(teamId, size: 15),
                const SizedBox(height: 8),
                Wrap(spacing: 3, runSpacing: 3, children: [
                  for (final n in picks)
                    if (!revealed)
                      const HiddenBall(size: 22)
                    else
                      Builder(builder: (_) {
                        final k = seen[n] = (seen[n] ?? 0) + 1;
                        final hit = k <= (matched[n] ?? 0);
                        return DrawBall(n, size: 22, dim: !hit, ring: hit ? DrawColors.good : null);
                      }),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(end: score.points.toDouble()),
            duration: const Duration(milliseconds: 500),
            builder: (_, v, _) => Text('${v.round()}',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: DrawColors.fg)),
          ),
          const Text(' 점', style: TextStyle(color: DrawColors.muted)),
        ],
      ),
    );
  }
}

// ───────────────────────── 결과 ─────────────────────────

/// 무대 위 결과 — 순위를 크게
class _ResultOverlay extends _Reactive {
  const _ResultOverlay();

  @override
  Widget buildReactive(BuildContext context) {
    final d = DrawController.to;
    final standings = d.record!.standings;
    final tie = d.pendingTie;
    final lastScores = d.scoresOf(d.round!);
    var rank = 1;
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 0.9,
          colors: [Color(0x99080B10), Color(0xE6080B10)],
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('RESULT',
                  style: TextStyle(
                      color: DrawColors.accent, letterSpacing: 2.4, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(tie == null ? '순위가 정해졌습니다' : '동점 — 재대결이 필요합니다',
                  style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
              const SizedBox(height: 22),
              for (final g in standings)
                Builder(builder: (_) {
                  final r = rank;
                  rank += g.length;
                  return Container(
                    width: 560,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0x14FFFFFF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: g.length > 1 ? DrawColors.accent : const Color(0x22FFFFFF)),
                    ),
                    child: Row(children: [
                      SizedBox(
                        width: 64,
                        child: Text('$r위',
                            style: TextStyle(
                                color: r == 1 ? DrawColors.accent : Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900)),
                      ),
                      Expanded(
                        child: Wrap(spacing: 14, runSpacing: 4, children: [
                          for (final id in g)
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              _TeamDot(id, size: 14),
                              const SizedBox(width: 8),
                              Text(d.teamName(id),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                              if (d.leaderName(id) case final l?)
                                Text('  $l',
                                    style: const TextStyle(color: DrawColors.hudSub, fontSize: 15)),
                            ]),
                        ]),
                      ),
                      if (g.length > 1)
                        const Text('재대결',
                            style: TextStyle(color: DrawColors.accent, fontWeight: FontWeight.w800))
                      else if (lastScores[g.single] case final s?)
                        Text('${s.points}점',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                    ]),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultPanel extends _Reactive {
  const _ResultPanel();

  String _summary(DrawController d) {
    final b = StringBuffer('[팀장 우선권 추첨 결과]\n');
    var rank = 1;
    for (final g in d.record!.standings) {
      b.writeln('$rank위  ${g.map(d.teamName).join(' · ')}${g.length > 1 ? ' (재대결)' : ''}');
      rank += g.length;
    }
    for (var i = 0; i < d.record!.rounds.length; i++) {
      final r = d.record!.rounds[i];
      b
        ..writeln()
        ..writeln(i == 0 ? '[본선]' : '[재대결 $i차]')
        ..writeln('나온 구슬: ${r.drawn.join(' ')}');
      final scores = d.scoresOf(r);
      for (final id in r.teamIds) {
        b.writeln('${d.teamName(id)}: ${r.picks[id]?.join(' ')} → ${scores[id]!.points}점');
      }
      if (r.loadOrder != null) {
        b.writeln('넣은 순서: ${r.loadOrder!.join(' ')} (시드 ${AirMixSim.seedOf(r.loadOrder!).toRadixString(16)})');
      }
    }
    return b.toString().trimRight();
  }

  @override
  Widget buildReactive(BuildContext context) {
    final d = DrawController.to;
    final r = d.round!;
    final scores = d.scoresOf(r);
    final order = [...r.teamIds]..sort((a, b) => scores[b]!.points - scores[a]!.points);
    final tie = d.pendingTie;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelTitle('4', d.isRematch ? '재대결 ${d.record!.rounds.length - 1}차 점수표' : '점수표'),
        Expanded(
          child: ListView(
            children: [
              for (final id in order) _ScoreCard(teamId: id, score: scores[id]!),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                final same = d.verifyReplay(r);
                showToast(same
                    ? '같은 넣는 순서로 다시 돌려도 같은 구슬 ${DrawRules.drawCount}개가 같은 순서로 나왔습니다.'
                    : '다시 돌린 결과가 다릅니다 — 기록이 바뀌었을 수 있습니다.');
              },
              icon: const Icon(Icons.verified_outlined, size: 18),
              label: const Text('같은 순서로 다시 확인'),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _summary(d)));
              showToast('추첨 결과를 복사했습니다.');
            },
            icon: const Icon(Icons.content_copy_rounded, size: 18),
            label: const Text('복사'),
          ),
        ]),
        const SizedBox(height: 10),
        if (tie != null)
          FilledButton.icon(
            onPressed: d.startRematch,
            icon: const Icon(Icons.sports_kabaddi_rounded),
            label: Text('재대결 시작 — ${tie.map(d.teamName).join(' · ')}'),
            style: accentButton,
          )
        else
          FilledButton.icon(
            onPressed: d.openAreas,
            icon: const Icon(Icons.dashboard_customize_rounded),
            label: const Text('영역 고르러 가기'),
            style: accentButton,
          ),
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.teamId, required this.score});

  final String teamId;
  final TeamScore score;

  @override
  Widget build(BuildContext context) {
    const head = TextStyle(fontSize: 12, color: DrawColors.muted);
    const cell = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: DrawColors.bg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: _TeamLabel(teamId, size: 15)),
            Text('${score.points}점',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 8),
          Table(
            columnWidths: const {0: FixedColumnWidth(44)},
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              const TableRow(children: [
                Text('숫자', style: head),
                Text('고름', style: head),
                Text('나옴', style: head),
                Text('인정', style: head),
                Text('점수', style: head, textAlign: TextAlign.right),
              ]),
              for (final l in score.lines)
                TableRow(children: [
                  Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: DrawBall(l.number, size: 24)),
                  Text('${l.picked}', style: cell),
                  Text('${l.drawn}', style: cell),
                  Text('${l.matched}',
                      style: cell.copyWith(color: l.matched > 0 ? DrawColors.good : DrawColors.muted)),
                  Text(l.points > 0 ? '${l.number} × ${l.matched} = ${l.points}' : '0',
                      textAlign: TextAlign.right, style: cell),
                ]),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── 영역 고르기 ─────────────────────────

class _AreasLeft extends _Reactive {
  const _AreasLeft();

  @override
  Widget buildReactive(BuildContext context) {
    final d = DrawController.to;
    final chooser = d.nextChooser;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: DrawColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DrawColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chooser != null) ...[
            Row(children: [
              Text('${d.rankOf(chooser)}위  ',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFFB98F00))),
              Flexible(child: _TeamLabel(chooser, size: 28)),
            ]),
            const SizedBox(height: 4),
            const Text('팀장님, 가져갈 영역을 골라 주세요. 지도에서 영역을 눌러도 됩니다.',
                style: TextStyle(fontSize: 16, color: DrawColors.muted)),
          ] else
            const Text('영역을 모두 골랐습니다',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: AreaMap(
                cellWidth: 74,
                cellHeight: 42,
                softFree: true,
                onTapSlot: chooser == null
                    ? null
                    : (slot) {
                        final a = LockerController.to.areaOf(slot);
                        if (a != null && a.teamId == null) d.chooseArea(a.id);
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AreaPanel extends _Reactive {
  const _AreaPanel();

  @override
  Widget buildReactive(BuildContext context) {
    final d = DrawController.to;
    final c = LockerController.to;
    final ranking = d.ranking ?? const <String>[];
    final chooser = d.nextChooser;
    final areas = c.state.areas;
    final short = areas.length < ranking.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PanelTitle('5', '영역 고르기'),
        if (areas.isEmpty || short)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4D6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFFB7851B)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(areas.isEmpty
                    ? '아직 영역이 없습니다. 영역 설정에서 신발장을 영역으로 나눠 주세요.'
                    : '영역(${areas.length}개)이 팀(${ranking.length}팀)보다 적습니다.'),
              ),
              TextButton(onPressed: () => showAreaDialog(context), child: const Text('영역 설정')),
            ]),
          ),
        Expanded(
          child: ListView(
            children: [
              for (final a in areas) _AreaOption(areaId: a.id, canChoose: chooser != null),
            ],
          ),
        ),
        const Divider(height: 24),
        const Text('순위', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        for (final id in ranking)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              SizedBox(
                  width: 36,
                  child: Text('${d.rankOf(id)}위', style: const TextStyle(fontWeight: FontWeight.w800))),
              Expanded(child: _TeamLabel(id, size: 14)),
              Text(c.areaOfTeam(id)?.name ?? (id == chooser ? '고르는 중' : '대기'),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: c.areaOfTeam(id) != null
                        ? AppColors.teamColor(c.colorOfArea(c.areaOfTeam(id)!))
                        : DrawColors.muted,
                  )),
            ]),
          ),
        const SizedBox(height: 12),
        Row(children: [
          OutlinedButton(
            onPressed: areas.any((a) => a.teamId != null) ? d.resetAreas : null,
            child: const Text('다시 고르기'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: chooser == null && areas.any((a) => a.teamId != null) ? d.openPlace : null,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('팀별 배치로'),
              style: accentButton,
            ),
          ),
        ]),
      ],
    );
  }
}

class _AreaOption extends StatelessWidget {
  const _AreaOption({required this.areaId, required this.canChoose});

  final String areaId;
  final bool canChoose;

  @override
  Widget build(BuildContext context) {
    final d = DrawController.to;
    final c = LockerController.to;
    final a = c.areaById(areaId)!;
    final taken = a.teamId != null;
    final chooser = d.nextChooser;
    final need = chooser == null ? null : c.membersOf(chooser).where((m) => !m.excluded).length;
    final slots = c.usableSlotsOf(a);
    return Opacity(
      opacity: taken ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: DrawColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: AppColors.teamColor(c.colorOfArea(a)), width: 6)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: ListTile(
          title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          subtitle: Text(
            taken
                ? '${d.teamName(a.teamId!)}이(가) 가져감'
                : '$slots칸${need != null && need > slots ? '  ·  ${need - slots}칸 모자람' : ''}',
          ),
          trailing: taken
              ? _TeamDot(a.teamId!, size: 16)
              : FilledButton(
                  onPressed: canChoose ? () => d.chooseArea(a.id) : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: DrawColors.fg,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('가져가기'),
                ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 팀별 배치 ─────────────────────────

class _PlaceLeft extends _Reactive {
  const _PlaceLeft();

  @override
  Widget buildReactive(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: DrawColors.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DrawColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('배치 미리보기',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('팀마다 랜덤으로 돌리거나, 신발장 화면에서 협의한 대로 이름을 끌어다 놓으세요.',
                style: TextStyle(fontSize: 14, color: DrawColors.muted)),
            const SizedBox(height: 18),
            Expanded(
              child: SingleChildScrollView(
                child: AreaMap(cellWidth: 82, cellHeight: 42, showNames: true),
              ),
            ),
          ],
        ),
      );
}

class _PlacePanel extends _Reactive {
  const _PlacePanel();

  void _report(BuildContext context, ShuffleLike report) {
    if (report.leftOver.isEmpty) {
      showToast('${report.placed}명을 배치했습니다.', actionLabel: '되돌리기', onAction: LockerController.to.undo);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('칸이 모자랍니다'),
        content: Text('${report.leftOver.length}명은 영역 안에 칸을 받지 못했습니다.\n\n'
            '${report.leftOver.join(', ')}\n\n신발장 화면에서 직접 옮겨 주세요.'),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('확인')),
        ],
      ),
    );
  }

  @override
  Widget buildReactive(BuildContext context) {
    final d = DrawController.to;
    final c = LockerController.to;
    final ranking = d.ranking ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PanelTitle('6', '팀별 배치'),
        Expanded(
          child: ListView(
            children: [
              for (final id in ranking)
                Builder(builder: (context) {
                  final area = c.areaOfTeam(id);
                  final members = c.membersOf(id).where((m) => !m.excluded).toList();
                  final seated = members.where((m) => area?.slots.contains(c.slotOf(m.id)) ?? false).length;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: DrawColors.bg, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _TeamLabel(id, size: 15),
                            const SizedBox(height: 4),
                            Text(
                              area == null
                                  ? '영역 없음'
                                  : '${area.name} · ${c.usableSlotsOf(area)}칸 · $seated/${members.length}명 배치됨',
                              style: const TextStyle(fontSize: 13, color: DrawColors.muted),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: area == null
                            ? null
                            : () {
                                final r = c.shuffleTeam(id);
                                if (r != null) {
                                  _report(context, ShuffleLike(r.placed, [for (final m in r.leftOver) m.name]));
                                }
                              },
                        icon: const Icon(Icons.shuffle_rounded, size: 18),
                        label: const Text('랜덤'),
                      ),
                    ]),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () {
            final r = c.shuffle();
            _report(context, ShuffleLike(r.placed, [for (final m in r.leftOver) m.name]));
          },
          icon: const Icon(Icons.shuffle_on_rounded),
          label: const Text('모든 팀 한꺼번에 랜덤'),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: Get.back,
          icon: const Icon(Icons.pan_tool_alt_rounded),
          label: const Text('신발장 화면에서 직접 배치'),
          style: accentButton,
        ),
      ],
    );
  }
}

/// 배치 결과 알림에 필요한 것만
class ShuffleLike {
  const ShuffleLike(this.placed, this.leftOver);

  final int placed;
  final List<String> leftOver;
}
