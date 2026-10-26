import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/locker_models.dart';
import '../controller/locker_controller.dart';

Future<void> showSettingsDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _SettingsDialog());

class _BankDraft {
  _BankDraft({this.id, required String name, required this.cols, required this.rows})
      : name = TextEditingController(text: name);

  final String? id;
  final TextEditingController name;
  int cols;
  int rows;
}

/// 신발장 설정 — 세트 이름 · 크기 · 개수, 채우는 방식, 번호 매기기
class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog();

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  final c = LockerController.to;
  late final List<_BankDraft> _banks = [
    for (final b in c.state.banks) _BankDraft(id: b.id, name: b.name, cols: b.cols, rows: b.rows),
  ];
  late FillMode _fill = c.state.fillMode;
  late NumberingOrder _numbering = c.state.numbering;
  late bool _continuous = c.state.continuousNumbering;

  static const _maxSide = 20;
  static const _maxBanks = 6;

  @override
  void dispose() {
    for (final b in _banks) {
      b.name.dispose();
    }
    super.dispose();
  }

  /// 크기를 줄이면 잘려 나가는 칸에 있던 사람 수
  int get _lostAssignments {
    var lost = 0;
    for (final slot in c.state.assignments.keys) {
      final (bankId, index) = parseSlotKey(slot);
      final old = c.bankById(bankId);
      final draft = _banks.where((d) => d.id == bankId).firstOrNull;
      if (old == null) continue;
      if (draft == null) {
        lost++;
        continue;
      }
      final r = index ~/ old.cols, col = index % old.cols;
      if (r >= draft.rows || col >= draft.cols) lost++;
    }
    return lost;
  }

  void _save() {
    c.updateBanks([
      for (final d in _banks) BankEdit(id: d.id, name: d.name.text, cols: d.cols, rows: d.rows),
    ]);
    c.setFillMode(_fill);
    c.setNumbering(_numbering);
    c.setContinuousNumbering(_continuous);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final lost = _lostAssignments;
    final total = _banks.fold(0, (s, b) => s + b.cols * b.rows);
    return AlertDialog(
      title: const Text('신발장 설정'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _section('신발장 구성', trailing: '전체 $total칸'),
              for (var i = 0; i < _banks.length; i++) _bankRow(i),
              if (_banks.length < _maxBanks)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _banks.add(_BankDraft(
                          name: String.fromCharCode('A'.codeUnitAt(0) + _banks.length),
                          cols: 4,
                          rows: 7,
                        ))),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('신발장 추가'),
                  ),
                ),
              if (lost > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('줄어든 칸에 있던 $lost명은 미배치가 됩니다.',
                      style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
                ),
              const SizedBox(height: 18),
              _section('빈 칸 남기는 방식'),
              Text(
                '사람보다 칸이 많을 때, 빈 칸을 어디에 둘지 정합니다.',
                style: const TextStyle(fontSize: 12.5, color: AppColors.inkMute),
              ),
              const SizedBox(height: 8),
              SegmentedButton<FillMode>(
                segments: [
                  for (final m in FillMode.values) ButtonSegment(value: m, label: Text(m.label)),
                ],
                selected: {_fill},
                onSelectionChanged: (s) => setState(() => _fill = s.first),
              ),
              const SizedBox(height: 18),
              _section('칸 번호'),
              SegmentedButton<NumberingOrder>(
                segments: [
                  for (final o in NumberingOrder.values) ButtonSegment(value: o, label: Text(o.label)),
                ],
                selected: {_numbering},
                onSelectionChanged: (s) => setState(() => _numbering = s.first),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _continuous,
                onChanged: (v) => setState(() => _continuous = v),
                title: const Text('번호 이어 매기기'),
                subtitle: const Text('두 번째 신발장을 1번이 아니라 앞 신발장 다음 번호부터 셉니다.'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(onPressed: _save, child: const Text('저장')),
      ],
    );
  }

  Widget _section(String title, {String? trailing}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const Spacer(),
          if (trailing != null)
            Text(trailing, style: const TextStyle(fontSize: 12.5, color: AppColors.inkMute)),
        ]),
      );

  Widget _bankRow(int i) {
    final d = _banks[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: TextField(
              controller: d.name,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: '이름',
                counterText: '',
                fillColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          _Stepper(
            label: '가로',
            value: d.cols,
            onChanged: (v) => setState(() => d.cols = v),
            max: _maxSide,
          ),
          const SizedBox(width: 12),
          _Stepper(
            label: '세로',
            value: d.rows,
            onChanged: (v) => setState(() => d.rows = v),
            max: _maxSide,
          ),
          const Spacer(),
          Text('${d.cols * d.rows}칸', style: const TextStyle(color: AppColors.inkSub)),
          IconButton(
            tooltip: '이 신발장 삭제',
            onPressed: _banks.length <= 1
                ? null
                : () => setState(() {
                      _banks.removeAt(i).name.dispose();
                    }),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, required this.value, required this.onChanged, required this.max});

  final String label;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.inkSub)),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
          ),
          SizedBox(
            width: 22,
            child: Text('$value',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
          ),
        ],
      );
}
