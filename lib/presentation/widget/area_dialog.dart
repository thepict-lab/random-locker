import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/locker_models.dart';
import '../controller/locker_controller.dart';
import 'area_map.dart';

Future<void> showAreaDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _AreaDialog());

/// 영역 설정 — 신발장 칸을 묶어 영역을 만든다. 한 칸은 한 영역에만 들어간다.
///
/// 사본을 고치다가 저장할 때 한꺼번에 반영한다(취소하면 그대로).
class _AreaDialog extends StatefulWidget {
  const _AreaDialog();

  @override
  State<_AreaDialog> createState() => _AreaDialogState();
}

class _AreaDialogState extends State<_AreaDialog> {
  final c = LockerController.to;
  late final List<LockerArea> _drafts = [for (final a in c.state.areas) a.copy()];
  int _selected = 0;
  final _name = TextEditingController();

  LockerArea? get _current =>
      _drafts.isEmpty ? null : _drafts[_selected.clamp(0, _drafts.length - 1)];

  @override
  void initState() {
    super.initState();
    _syncName();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _syncName() => _name.text = _current?.name ?? '';

  void _select(int i) => setState(() {
        _selected = i;
        _syncName();
      });

  void _add() => setState(() {
        _drafts.add(c.newArea(_drafts));
        _selected = _drafts.length - 1;
        _syncName();
      });

  void _remove(int i) => setState(() {
        _drafts.removeAt(i);
        _selected = (_selected >= _drafts.length ? _drafts.length - 1 : _selected).clamp(0, 1 << 20);
        _syncName();
      });

  Future<void> _auto() async {
    final teams = c.state.teams.length;
    final count = await showDialog<int>(
      context: context,
      builder: (context) {
        var n = teams < 2 ? 4 : teams;
        return StatefulBuilder(
          builder: (context, set) => AlertDialog(
            title: const Text('자동으로 나누기'),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('쓸 수 있는 칸을 번호 순서로 늘어놓고 앞에서부터 나눕니다.\n'
                      '영역 수가 팀 수와 같으면 팀 인원 비율대로, 아니면 똑같이 나눕니다.\n'
                      '지금 영역은 모두 지워집니다.'),
                  const SizedBox(height: 16),
                  Row(children: [
                    const Text('영역 수'),
                    const SizedBox(width: 12),
                    IconButton(
                        onPressed: n > 1 ? () => set(() => n--) : null,
                        icon: const Icon(Icons.remove_rounded)),
                    Text('$n', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    IconButton(
                        onPressed: n < 12 ? () => set(() => n++) : null,
                        icon: const Icon(Icons.add_rounded)),
                    if (teams >= 2) Text('(팀 $teams개)', style: const TextStyle(color: AppColors.inkMute)),
                  ]),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
              FilledButton(onPressed: () => Navigator.pop(context, n), child: const Text('나누기')),
            ],
          ),
        );
      },
    );
    if (count == null) return;
    setState(() {
      _drafts
        ..clear()
        ..addAll(c.autoAreas(count: count));
      _selected = 0;
      _syncName();
    });
  }

  /// 칸을 지금 영역에 넣거나 뺀다. 다른 영역에 있던 칸이면 옮겨 온다.
  void _toggle(SlotKey slot) {
    final cur = _current;
    if (cur == null) return;
    setState(() {
      if (!cur.slots.remove(slot)) {
        for (final a in _drafts) {
          a.slots.remove(slot);
        }
        cur.slots.add(slot);
      }
    });
  }

  void _toggleLine(List<SlotKey> slots) {
    final cur = _current;
    if (cur == null) return;
    setState(() {
      if (slots.every(cur.slots.contains)) {
        cur.slots.removeAll(slots);
      } else {
        for (final a in _drafts) {
          a.slots.removeAll(slots);
        }
        cur.slots.addAll(slots);
      }
    });
  }

  void _save() {
    for (final d in _drafts) {
      if (d.name.trim().isEmpty) d.name = c.newArea(_drafts).name;
    }
    c.replaceAreas(_drafts);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cur = _current;
    final free = c.usableSlots -
        _drafts.fold<int>(0, (s, a) => s + a.slots.where((x) => !c.isDisabled(x)).length);
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      title: const Row(children: [
        Icon(Icons.dashboard_customize_outlined, color: AppColors.brand),
        SizedBox(width: 8),
        Text('영역 설정'),
      ]),
      content: SizedBox(
        width: 1080,
        height: 620,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 240, child: _list(free)),
            const VerticalDivider(width: 32),
            Expanded(
              child: cur == null
                  ? const Center(
                      child: Text('왼쪽 아래 [영역 추가] 또는 [자동으로 나누기] 를 누르세요.',
                          style: TextStyle(color: AppColors.inkMute)))
                  : SingleChildScrollView(child: _editor(cur)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(onPressed: _save, child: const Text('저장')),
      ],
    );
  }

  Widget _list(int free) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '추첨 순위대로 팀이 영역을 하나씩 가져갑니다.\n어느 영역에도 없는 칸 $free칸',
            style: const TextStyle(fontSize: 12.5, color: AppColors.inkMute, height: 1.5),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: _drafts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, i) {
                final a = _drafts[i];
                final selected = i == _selected;
                return Material(
                  color: selected ? AppColors.teamSoft(a.color) : AppColors.canvas,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _select(i),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border(left: BorderSide(color: AppColors.teamColor(a.color), width: 5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            '${a.slots.where((s) => !c.isDisabled(s)).length}칸'
                            '${a.teamId != null ? ' · ${c.teamById(a.teamId)?.name ?? ''} 차지' : ''}',
                            style: const TextStyle(fontSize: 12, color: AppColors.inkMute),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add_rounded),
            label: const Text('영역 추가'),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: _auto,
            icon: const Icon(Icons.auto_awesome_mosaic_outlined),
            label: const Text('자동으로 나누기'),
          ),
        ],
      );

  Widget _editor(LockerArea cur) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            SizedBox(
              width: 220,
              child: TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: '영역 이름'),
                onChanged: (v) => setState(() => cur.name = v),
              ),
            ),
            const SizedBox(width: 16),
            for (var i = 0; i < AppColors.team.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () => setState(() => cur.color = i),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.team[i],
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: cur.color == i ? AppColors.ink : Colors.transparent, width: 2.5),
                    ),
                  ),
                ),
              ),
            const Spacer(),
            IconButton(
              tooltip: '이 영역 삭제',
              onPressed: () => _remove(_selected),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ]),
          const SizedBox(height: 16),
          const Text(
            '칸을 눌러 이 영역에 넣거나 뺍니다. 줄 · 열 번호를 누르면 한 줄을 통째로 고릅니다. '
            '다른 영역의 칸을 누르면 이 영역으로 옮겨 옵니다.',
            style: TextStyle(fontSize: 12.5, color: AppColors.inkMute),
          ),
          const SizedBox(height: 12),
          AreaMap(
            areas: _drafts,
            highlight: cur.id,
            byOwner: false,
            cellWidth: 52,
            cellHeight: 32,
            onTapSlot: _toggle,
            onTapLine: _toggleLine,
          ),
        ],
      );
}
