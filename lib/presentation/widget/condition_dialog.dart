import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/locker_models.dart';
import '../controller/locker_controller.dart';

Future<void> showConditionDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _ConditionDialog());

/// 배치 조건 — "이 멤버들은 이 자리를 빼고(또는 이 자리에만) 랜덤 배치"
///
/// 사본을 고치다가 저장할 때 한꺼번에 반영한다(취소하면 그대로).
class _ConditionDialog extends StatefulWidget {
  const _ConditionDialog();

  @override
  State<_ConditionDialog> createState() => _ConditionDialogState();
}

class _ConditionDialogState extends State<_ConditionDialog> {
  final c = LockerController.to;
  late final List<LockerCondition> _drafts = [for (final x in c.state.conditions) x.copy()];
  int _selected = 0;
  final _name = TextEditingController();

  LockerCondition? get _current =>
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
        _drafts.add(c.newCondition(_drafts));
        _selected = _drafts.length - 1;
        _syncName();
      });

  void _remove(int i) => setState(() {
        _drafts.removeAt(i);
        _selected = (_selected >= _drafts.length ? _drafts.length - 1 : _selected).clamp(0, 1 << 20);
        _syncName();
      });

  Future<void> _pickMembers(LockerCondition cond) async {
    final picked = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _MemberMultiPicker(initial: cond.memberIds),
    );
    if (picked == null) return;
    setState(() {
      cond.memberIds
        ..clear()
        ..addAll(picked);
    });
  }

  void _save() {
    for (final d in _drafts) {
      if (d.name.trim().isEmpty) d.name = c.nextConditionName(_drafts);
    }
    c.replaceConditions(_drafts);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cond = _current;
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      title: const Row(children: [
        Icon(Icons.rule_rounded, color: AppColors.brand),
        SizedBox(width: 8),
        Text('배치 조건'),
      ]),
      content: SizedBox(
        width: 980,
        height: 600,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 240, child: _list()),
            const VerticalDivider(width: 32),
            Expanded(
              child: cond == null
                  ? const _NoCondition()
                  : SingleChildScrollView(child: _editor(cond)),
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

  Widget _list() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '랜덤 배치 때만 적용됩니다.\n고정한 칸은 그대로 둡니다.',
            style: TextStyle(fontSize: 12.5, color: AppColors.inkMute, height: 1.5),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: _drafts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, i) {
                final d = _drafts[i];
                final selected = i == _selected;
                return Material(
                  color: selected ? AppColors.brandSoft : AppColors.canvas,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _select(i),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: d.enabled ? AppColors.ink : AppColors.inkMute,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${d.type.label} · ${d.memberIds.length}명 · ${d.slots.length}칸',
                                style: const TextStyle(fontSize: 12, color: AppColors.inkMute),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: d.enabled,
                          onChanged: (v) => setState(() => d.enabled = v),
                        ),
                      ]),
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
            label: const Text('조건 추가'),
          ),
        ],
      );

  Widget _editor(LockerCondition cond) {
    final exclude = cond.type == ConditionType.exclude;
    final names = [for (final id in cond.memberIds) ?c.memberById(id)]
      ..sort((a, b) => a.name.compareTo(b.name));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          SizedBox(
            width: 220,
            child: TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: '조건 이름'),
              onChanged: (v) => setState(() => cond.name = v),
            ),
          ),
          const SizedBox(width: 16),
          SegmentedButton<ConditionType>(
            segments: [
              for (final t in ConditionType.values)
                ButtonSegment(
                  value: t,
                  label: Text(t.label),
                  icon: Icon(t == ConditionType.exclude ? Icons.block_rounded : Icons.check_rounded),
                ),
            ],
            selected: {cond.type},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => cond.type = s.first),
          ),
          const Spacer(),
          IconButton(
            tooltip: '이 조건 삭제',
            onPressed: () => _remove(_selected),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ]),
        const SizedBox(height: 20),
        _sectionTitle('1. 대상 멤버', '${names.length}명'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final m in names)
              InputChip(
                label: Text(m.name),
                onDeleted: () => setState(() => cond.memberIds.remove(m.id)),
              ),
            ActionChip(
              avatar: const Icon(Icons.person_add_alt_rounded, size: 18),
              label: Text(names.isEmpty ? '멤버 고르기' : '멤버 바꾸기'),
              onPressed: () => _pickMembers(cond),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionTitle(
          exclude ? '2. 제외할 자리' : '2. 배치할 자리',
          '${cond.slots.length}칸',
          trailing: cond.slots.isEmpty
              ? null
              : TextButton(
                  onPressed: () => setState(cond.slots.clear),
                  child: const Text('모두 해제'),
                ),
        ),
        const Text(
          '칸을 눌러 고르세요. 줄 · 열 번호를 누르면 한 줄을 통째로 고릅니다.',
          style: TextStyle(fontSize: 12.5, color: AppColors.inkMute),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 28,
          runSpacing: 16,
          children: [
            for (final bank in c.state.banks)
              _SlotPicker(
                bank: bank,
                selected: cond.slots,
                exclude: exclude,
                onChanged: () => setState(() {}),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _Summary(cond: cond, names: names.map((m) => m.name).toList()),
      ],
    );
  }

  Widget _sectionTitle(String title, String count, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(width: 8),
          Text(count, style: const TextStyle(fontSize: 12.5, color: AppColors.inkMute)),
          ?trailing,
        ]),
      );
}

class _NoCondition extends StatelessWidget {
  const _NoCondition();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.rule_rounded, size: 44, color: AppColors.brandLine),
            SizedBox(height: 12),
            Text('아직 조건이 없습니다', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text(
              '예) 「조건 1」 — 홍길동 · 김철수는 A 신발장 맨 아랫줄 제외\n'
              '왼쪽 아래 [조건 추가] 를 누르세요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.inkMute, height: 1.6),
            ),
          ],
        ),
      );
}

/// 조건 한 줄 요약
class _Summary extends StatelessWidget {
  const _Summary({required this.cond, required this.names});

  final LockerCondition cond;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final c = LockerController.to;
    final String text;
    if (names.isEmpty || cond.slots.isEmpty) {
      text = '대상 멤버와 자리를 고르면 조건이 적용됩니다.';
    } else {
      final who = names.length <= 3 ? names.join(', ') : '${names.take(3).join(', ')} 외 ${names.length - 3}명';
      final where = cond.slots.length <= 4
          ? '${cond.slots.map(c.slotLabel).join(', ')}번'
          : '고른 ${cond.slots.length}칸';
      text = cond.type == ConditionType.exclude
          ? '$who 은(는) $where에 배치되지 않습니다.'
          : '$who 은(는) $where 중에서만 배치됩니다.';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cond.enabled ? AppColors.brandSoft : AppColors.canvas,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(cond.enabled ? Icons.info_outline_rounded : Icons.pause_circle_outline_rounded,
            size: 18, color: cond.enabled ? AppColors.brand : AppColors.inkMute),
        const SizedBox(width: 8),
        Expanded(
          child: Text(cond.enabled ? text : '꺼진 조건입니다 — 랜덤 배치에 적용하지 않습니다.',
              style: const TextStyle(fontSize: 13)),
        ),
      ]),
    );
  }
}

/// 신발장 한 세트를 작게 그려 칸을 고른다.
class _SlotPicker extends StatelessWidget {
  const _SlotPicker({
    required this.bank,
    required this.selected,
    required this.exclude,
    required this.onChanged,
  });

  final LockerBank bank;
  final Set<SlotKey> selected;
  final bool exclude;
  final VoidCallback onChanged;

  static const _w = 40.0;
  static const _h = 26.0;
  static const _gap = 3.0;

  Color get _on => exclude ? AppColors.danger : AppColors.brand;

  void _toggleAll(Iterable<int> indexes) {
    final keys = indexes.map((i) => slotKey(bank.id, i)).toList();
    if (keys.every(selected.contains)) {
      selected.removeAll(keys);
    } else {
      selected.addAll(keys);
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final c = LockerController.to;
    Widget header(String label, VoidCallback onTap, {double? width, double? height}) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: width,
            height: height,
            child: Center(
              child: Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.inkMute)),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${bank.name} 신발장',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 6),
        Row(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 30),
          for (var col = 0; col < bank.cols; col++)
            Padding(
              padding: const EdgeInsets.only(right: _gap),
              child: header('${col + 1}열',
                  () => _toggleAll([for (var r = 0; r < bank.rows; r++) r * bank.cols + col]),
                  width: _w, height: 18),
            ),
        ]),
        for (var r = 0; r < bank.rows; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: _gap),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              header('${r + 1}줄',
                  () => _toggleAll([for (var col = 0; col < bank.cols; col++) r * bank.cols + col]),
                  width: 30, height: _h),
              for (var col = 0; col < bank.cols; col++)
                Padding(
                  padding: const EdgeInsets.only(right: _gap),
                  child: _cell(c, r * bank.cols + col),
                ),
            ]),
          ),
      ],
    );
  }

  Widget _cell(LockerController c, int index) {
    final key = slotKey(bank.id, index);
    final on = selected.contains(key);
    final disabled = bank.disabled.contains(index);
    return InkWell(
      onTap: () {
        if (!selected.remove(key)) selected.add(key);
        onChanged();
      },
      borderRadius: BorderRadius.circular(5),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: _w,
        height: _h,
        decoration: BoxDecoration(
          color: on ? _on : (disabled ? AppColors.disabled : Colors.white),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: on ? _on : AppColors.line),
        ),
        alignment: Alignment.center,
        child: Text(
          '${c.numberOf(bank, index)}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: on ? Colors.white : AppColors.inkMute,
          ),
        ),
      ),
    );
  }
}

/// 여러 명 고르기
class _MemberMultiPicker extends StatefulWidget {
  const _MemberMultiPicker({required this.initial});

  final Set<String> initial;

  @override
  State<_MemberMultiPicker> createState() => _MemberMultiPickerState();
}

class _MemberMultiPickerState extends State<_MemberMultiPicker> {
  late final Set<String> _picked = {...widget.initial};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = LockerController.to;
    final people = c.state.members
        .where((m) => m.name.toLowerCase().contains(_query.toLowerCase()))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return AlertDialog(
      title: Text('대상 멤버 고르기 (${_picked.length}명)'),
      content: SizedBox(
        width: 360,
        height: 440,
        child: Column(children: [
          TextField(
            autofocus: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded, size: 20),
              hintText: '이름 검색',
            ),
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: people.isEmpty
                ? const Center(
                    child: Text('등록된 사람이 없습니다', style: TextStyle(color: AppColors.inkMute)))
                : ListView(children: [
                    for (final m in people)
                      CheckboxListTile(
                        dense: true,
                        value: _picked.contains(m.id),
                        title: Text(m.name),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _picked.add(m.id);
                          } else {
                            _picked.remove(m.id);
                          }
                        }),
                      ),
                  ]),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(onPressed: () => Navigator.pop(context, _picked), child: const Text('확인')),
      ],
    );
  }
}
