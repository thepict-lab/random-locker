import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/draw/draw_rules.dart';
import '../../../core/theme/app_colors.dart';
import '../../controller/draw_controller.dart';
import 'draw_ball.dart';

/// 규칙 안내 — 팀장들이 한 화면으로 같이 보는 튜토리얼. 쪽을 넘기며 흐름대로 설명한다.
class DrawTutorial extends StatelessWidget {
  const DrawTutorial({super.key, required this.onStart});

  /// 마지막 쪽의 [시작하기]
  final VoidCallback onStart;

  static const _pages = <({String kicker, String title})>[
    (kicker: 'STEP 1', title: '구슬 55개가 들어 있습니다'),
    (kicker: 'STEP 2', title: '팀장님마다 숫자 ${DrawRules.picksPerTeam}개를 고릅니다'),
    (kicker: 'STEP 3', title: '추첨기가 구슬 ${DrawRules.drawCount}개를 뽑습니다'),
    (kicker: 'STEP 4', title: '점수 계산'),
    (kicker: 'STEP 5', title: '순위대로 영역을 고르고, 팀 안에서 배치합니다'),
  ];

  @override
  Widget build(BuildContext context) {
    final d = DrawController.to;
    return Obx(() {
      final page = d.tutorialPage.value;
      final last = page == _pages.length - 1;
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 8, 32, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: DrawColors.panel,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: DrawColors.line),
                ),
                padding: const EdgeInsets.fromLTRB(40, 32, 40, 28),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0.03, 0), end: Offset.zero).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Column(
                    key: ValueKey(page),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_pages[page].kicker,
                          style: const TextStyle(
                              fontSize: 13,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w700,
                              color: DrawColors.muted)),
                      const SizedBox(height: 6),
                      Text(_pages[page].title,
                          style: const TextStyle(
                              fontSize: 34, fontWeight: FontWeight.w900, color: DrawColors.fg)),
                      const SizedBox(height: 24),
                      Expanded(
                        child: SingleChildScrollView(
                          child: switch (page) {
                            0 => const _PoolPage(),
                            1 => const _PickPage(),
                            2 => const _MachinePage(),
                            3 => const _ScorePage(),
                            _ => const _FlowPage(),
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (var i = 0; i < _pages.length; i++)
                  GestureDetector(
                    onTap: () => d.tutorialPage.value = i,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      width: i == page ? 28 : 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: i == page ? DrawColors.accent : DrawColors.line,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                const Spacer(),
                if (page > 0)
                  OutlinedButton.icon(
                    onPressed: () => d.tutorialPage.value--,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('이전'),
                    style: _outlined,
                  ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: last ? onStart : () => d.tutorialPage.value++,
                  icon: Icon(last ? Icons.play_arrow_rounded : Icons.arrow_forward_rounded),
                  label: Text(last ? '시작하기' : '다음'),
                  style: accentButton,
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

final _outlined = OutlinedButton.styleFrom(
  foregroundColor: DrawColors.fg,
  side: const BorderSide(color: DrawColors.line),
  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
);

/// 노란 강조 버튼 (lotto-airmix 의 primary)
final accentButton = FilledButton.styleFrom(
  backgroundColor: DrawColors.accent,
  foregroundColor: DrawColors.accentFg,
  disabledBackgroundColor: DrawColors.line,
  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
);

const _body = TextStyle(fontSize: 19, height: 1.6, color: DrawColors.fg);
const _sub = TextStyle(fontSize: 15, height: 1.5, color: DrawColors.muted);

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: const BoxDecoration(
          color: DrawColors.bg,
          border: Border(left: BorderSide(color: DrawColors.accent, width: 4)),
          borderRadius: BorderRadius.only(
              topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
        ),
        child: Text(text, style: const TextStyle(fontSize: 16, height: 1.5, color: DrawColors.fg)),
      );
}

/// 1 — 숫자마다 구슬 개수가 다르다
class _PoolPage extends StatelessWidget {
  const _PoolPage();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('숫자가 클수록 구슬이 적습니다. 1 은 10개, 2 는 9개 … 10 은 딱 1개뿐입니다.', style: _body),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var n = 1; n <= DrawRules.maxNumber; n++)
                Expanded(
                  child: Column(
                    children: [
                      for (var i = 0; i < DrawRules.ballsOf(n); i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: DrawBall(n, size: 30),
                        ),
                      const SizedBox(height: 8),
                      Text('${DrawRules.ballsOf(n)}개',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      Text('평균 ${DrawRules.expectedCount(n).toStringAsFixed(1)}개 나옴', style: _sub),
                    ],
                  ),
                ),
            ],
          ),
          const _Note('「평균 나옴」은 추첨기가 ${DrawRules.drawCount}개를 뽑을 때 그 숫자가 평균 몇 개 나오는지입니다. '
              '작은 숫자는 잘 나오지만 점수가 낮고, 큰 숫자는 점수가 높지만 잘 안 나옵니다.'),
        ],
      );
}

/// 2 — 숫자 고르기
class _PickPage extends StatelessWidget {
  const _PickPage();

  static const _example = [1, 1, 2, 3, 4, 5, 5, 6, 7, 8, 10];

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '1 부터 10 까지에서 ${DrawRules.picksPerTeam}개를 고릅니다. 같은 숫자를 여러 번 골라도 됩니다.\n'
            '다만 한 숫자를 고를 수 있는 횟수는 그 숫자 구슬 개수를 넘을 수 없습니다.',
            style: _body,
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 14,
            runSpacing: 10,
            children: [
              for (var n = 1; n <= DrawRules.maxNumber; n++)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  DrawBall(n, size: 34),
                  const SizedBox(width: 6),
                  Text('최대 ${DrawRules.maxPicksOf(n)}번',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ]),
            ],
          ),
          const SizedBox(height: 26),
          const Text('예)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: [for (final n in _example) DrawBall(n, size: 42)]),
          const _Note('팀장님들이 한 화면을 같이 보므로, 고른 숫자는 추첨이 시작될 때까지 ? 로 가려 둡니다.'),
        ],
      );
}

/// 3 — 추첨기
class _MachinePage extends StatelessWidget {
  const _MachinePage();

  @override
  Widget build(BuildContext context) {
    Widget step(IconData icon, String title, String text) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: DrawColors.bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 30, color: DrawColors.fg),
                const SizedBox(height: 10),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(text, style: _sub),
              ],
            ),
          ),
        );
    Widget arrow() => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.chevron_right_rounded, color: DrawColors.muted, size: 30),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('55개를 무작위 순서로 통에 넣고, 바람으로 섞은 뒤 출구로 올라온 구슬을 하나씩 꺼냅니다.',
            style: _body),
        const SizedBox(height: 24),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              step(Icons.move_to_inbox_rounded, '넣기', '55개를 무작위 순서로 위에서 넣습니다'),
              arrow(),
              step(Icons.air_rounded, '섞기', '송풍기를 켜고 5초 동안 섞습니다'),
              arrow(),
              step(Icons.pause_circle_outline_rounded, '멈춤', '바람을 1.2초 멈춰 출구 근처를 비웁니다'),
              arrow(),
              step(Icons.north_rounded, '꺼내기', '다시 바람을 켜고 출구를 엽니다. 출구를 지난 구슬 하나가 뽑힙니다'),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text('멈춤 → 꺼내기를 ${DrawRules.drawCount}번 되풀이합니다.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const _Note('결과는 구슬을 넣은 순서 하나로 정해집니다. 같은 순서로 다시 돌리면 언제나 같은 구슬이 '
            '같은 순서로 나오므로, 결과 화면에서 「같은 순서로 다시 확인」을 눌러 공정했는지 볼 수 있습니다. '
            '빠르게 보기(2× · 4× · 8×)나 건너뛰기를 해도 결과는 같습니다.'),
      ],
    );
  }
}

/// 4 — 점수 계산 예시. 실제 점수 계산([DrawRules.score])으로 숫자를 만든다.
class _ScorePage extends StatelessWidget {
  const _ScorePage();

  static const _drawn = [1, 1, 1, 2, 2, 3, 3, 4, 5, 6, 9];
  static const _teams = <(String, List<int>)>[
    ('A팀장', [1, 1, 1, 1, 2, 2, 3, 3, 4, 5, 6]),
    ('B팀장', [5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10]),
    ('C팀장', [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2]),
  ];

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '숫자마다 (고른 횟수)와 (나온 개수) 중 작은 쪽만큼만 인정하고, 인정된 숫자를 모두 더합니다.\n'
            '예) 1 을 2번 골랐는데 1 이 3개 나오면 1 + 1 = 2점',
            style: _body,
          ),
          const SizedBox(height: 18),
          Row(children: [
            const Text('나온 구슬  ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            for (final n in _drawn)
              Padding(padding: const EdgeInsets.only(right: 5), child: DrawBall(n, size: 36)),
          ]),
          const SizedBox(height: 18),
          for (final (name, picks) in _teams) _row(name, picks),
        ],
      );

  Widget _row(String name, List<int> picks) {
    final s = DrawRules.score(picks, _drawn);
    final parts = [
      for (final l in s.lines)
        if (l.matched > 0) '${l.number}×${l.matched}',
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(color: DrawColors.bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          SizedBox(
              width: 80,
              child: Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          for (final l in s.lines)
            for (var i = 0; i < l.picked; i++)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: DrawBall(l.number,
                    size: 30, dim: i >= l.matched, ring: i < l.matched ? DrawColors.good : null),
              ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(parts.isEmpty ? '맞은 구슬 없음' : parts.join(' + '),
                style: const TextStyle(fontSize: 16, color: DrawColors.muted)),
          ),
          Text('${s.points}점',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: DrawColors.fg)),
        ],
      ),
    );
  }
}

/// 5 — 순위 · 재대결 · 영역 · 배치
class _FlowPage extends StatelessWidget {
  const _FlowPage();

  @override
  Widget build(BuildContext context) {
    Widget node(String n, String title, String text) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: DrawColors.bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: DrawColors.accent, borderRadius: BorderRadius.circular(6)),
                  child: Text(n,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, color: DrawColors.accentFg, fontSize: 13)),
                ),
                const SizedBox(height: 10),
                Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(text, style: _sub),
              ],
            ),
          ),
        );
    Widget arrow() => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.chevron_right_rounded, color: DrawColors.muted, size: 30),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              node('1', '순위', '점수가 높은 팀이 위입니다'),
              arrow(),
              node('2', '영역 고르기', '1등 팀부터 미리 나눠 둔 영역 중 하나를 가져갑니다'),
              arrow(),
              node('3', '팀 안에서 배치', '영역 안에서 랜덤으로 돌리거나, 팀끼리 협의해 직접 놓습니다'),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 22),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: DrawColors.stage,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(Icons.sports_kabaddi_rounded, color: DrawColors.accent, size: 34),
              SizedBox(width: 16),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: '동점이면 재대결\n',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900, color: DrawColors.accent)),
                    TextSpan(
                      text: '순위가 정해진 팀은 빠지고, 같은 점수의 팀장님들끼리만 숫자 고르기부터 '
                          '추첨까지 처음부터 다시 합니다. 재대결에서 또 같으면 한 번 더 합니다.',
                      style: TextStyle(fontSize: 16, height: 1.5, color: DrawColors.hudText),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
