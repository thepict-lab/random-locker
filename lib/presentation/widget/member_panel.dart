import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/locker_models.dart';
import '../../main.dart';
import '../controller/locker_controller.dart';
import 'import_dialog.dart';
import 'locker_board.dart';

enum _Filter {
  all('전체'),
  unassigned('미배치'),
  excluded('제외');

  const _Filter(this.label);
  final String label;
}

/// 왼쪽 멤버 목록 — 등록 · 검색 · 끌어서 칸에 넣기
class MemberPanel extends StatefulWidget {
  const MemberPanel({super.key});

  @override
  State<MemberPanel> createState() => _MemberPanelState();
}

class _MemberPanelState extends State<MemberPanel> {
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  String _query = '';
  _Filter _filter = _Filter.all;

  LockerController get c => LockerController.to;

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _add() {
    final text = _input.text;
    final names = text.split(RegExp(r'[,\n\t;]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (names.isEmpty) return;
    final added = c.addMembers(names);
    _input.clear();
    _inputFocus.requestFocus();
    final skipped = names.length - added;
    if (skipped > 0) {
      showToast(added == 0 ? '이미 등록된 이름입니다.' : '$added명 등록 · 이미 있는 $skipped명은 건너뛰었습니다.');
    }
  }

  Future<void> _rename(Member m) async {
    final ctrl = TextEditingController(text: m.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이름 변경'),
        content: SizedBox(
          width: 320,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('변경')),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.trim().isEmpty) return;
    if (name.trim() != m.name && c.hasMemberNamed(name)) {
      showToast('같은 이름이 이미 있습니다.');
      return;
    }
    c.renameMember(m.id, name);
  }

  Future<void> _removeAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('멤버 전체 삭제'),
        content: Text('등록된 ${c.state.members.length}명과 배치를 모두 지웁니다.\n되돌리기(Ctrl+Z)로 되살릴 수 있습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('모두 삭제'),
          ),
        ],
      ),
    );
    if (ok == true) c.removeAllMembers();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('멤버',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
              const SizedBox(width: 6),
              Obx(() {
                c.version.value;
                return Text('${c.state.members.length}명',
                    style: const TextStyle(fontSize: 13, color: AppColors.inkMute, fontWeight: FontWeight.w600));
              }),
              const Spacer(),
              TextButton.icon(
                onPressed: () => showImportDialog(context),
                icon: const Icon(Icons.group_add_outlined, size: 18),
                label: const Text('명단 가져오기'),
              ),
              PopupMenuButton<String>(
                tooltip: '더 보기',
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                onSelected: (v) {
                  if (v == 'removeAll') _removeAll();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'removeAll', child: Text('멤버 전체 삭제')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _input,
            focusNode: _inputFocus,
            decoration: InputDecoration(
              hintText: '이름 입력 후 Enter',
              prefixIcon: const Icon(Icons.person_add_alt_rounded, size: 20),
              suffixIcon: IconButton(
                tooltip: '추가',
                onPressed: _add,
                icon: const Icon(Icons.add_circle_rounded, color: AppColors.brand),
              ),
            ),
            onSubmitted: (_) => _add(),
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              hintText: '검색',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
          const SizedBox(height: 10),
          SegmentedButton<_Filter>(
            segments: [
              for (final f in _Filter.values) ButtonSegment(value: f, label: Text(f.label)),
            ],
            selected: {_filter},
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            onSelectionChanged: (s) => setState(() => _filter = s.first),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Obx(() {
              c.version.value;
              final all = c.state.members;
              if (all.isEmpty) return const _EmptyMembers();
              final list = all.where((m) {
                if (_query.isNotEmpty && !m.name.toLowerCase().contains(_query)) return false;
                return switch (_filter) {
                  _Filter.all => true,
                  _Filter.unassigned => !m.excluded && c.slotOf(m.id) == null,
                  _Filter.excluded => m.excluded,
                };
              }).toList();
              if (list.isEmpty) {
                return const Center(
                    child: Text('해당하는 사람이 없습니다', style: TextStyle(color: AppColors.inkMute)));
              }
              return ListView.builder(
                itemCount: list.length,
                itemExtent: 46,
                itemBuilder: (context, i) => _MemberTile(
                  member: list[i],
                  onRename: () => _rename(list[i]),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          const Text(
            '이름을 칸으로 끌어 배치 · 칸 우클릭은 사용 안 함',
            style: TextStyle(fontSize: 11.5, color: AppColors.inkMute),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.onRename});

  final Member member;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final c = LockerController.to;
    final slot = c.slotOf(member.id);
    final pinned = slot != null && c.isPinned(slot);

    final tile = MouseRegion(
      onEnter: (_) => c.hoveredMember.value = member.id,
      onExit: (_) {
        if (c.hoveredMember.value == member.id) c.hoveredMember.value = null;
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: member.excluded
                  ? AppColors.disabled
                  : (slot != null ? AppColors.brand : AppColors.brandSoft),
              child: Text(
                member.name.characters.first,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: member.excluded
                      ? AppColors.inkMute
                      : (slot != null ? Colors.white : AppColors.brand),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                member.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: member.excluded ? AppColors.inkMute : AppColors.ink,
                  decoration: member.excluded ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (c.conditionsOf(member.id) case final rules when rules.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Tooltip(
                  message: rules
                      .map((r) => '${r.name} · ${r.type.label} (${r.slots.length}칸)')
                      .join('\n'),
                  child: const Icon(Icons.rule_rounded, size: 16, color: AppColors.brand),
                ),
              ),
            _SlotBadge(
              label: member.excluded
                  ? '제외'
                  : (slot == null ? '미배치' : c.slotLabel(slot)),
              active: slot != null,
              pinned: pinned,
            ),
            PopupMenuButton<String>(
              tooltip: '',
              icon: const Icon(Icons.more_horiz_rounded, size: 18, color: AppColors.inkMute),
              onSelected: (v) {
                switch (v) {
                  case 'rename':
                    onRename();
                  case 'exclude':
                    c.toggleExcluded(member.id);
                  case 'pin':
                    c.togglePin(slot!);
                  case 'unassign':
                    c.clearSlot(slot!);
                  case 'remove':
                    c.removeMember(member.id);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'rename', child: Text('이름 변경')),
                PopupMenuItem(
                  value: 'exclude',
                  child: Text(member.excluded ? '배치에 다시 포함' : '배치에서 제외 (휴가 · 외근)'),
                ),
                if (slot != null) ...[
                  PopupMenuItem(value: 'pin', child: Text(pinned ? '고정 풀기' : '이 칸에 고정')),
                  const PopupMenuItem(value: 'unassign', child: Text('칸에서 빼기')),
                ],
                const PopupMenuItem(
                  value: 'remove',
                  child: Text('삭제', style: TextStyle(color: AppColors.danger)),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (member.excluded) return tile;
    return Draggable<MemberDrag>(
      data: MemberDrag(member.id, fromSlot: slot),
      feedback: NameChip(name: member.name),
      childWhenDragging: Opacity(opacity: 0.4, child: tile),
      child: tile,
    );
  }
}

class _SlotBadge extends StatelessWidget {
  const _SlotBadge({required this.label, required this.active, required this.pinned});

  final String label;
  final bool active;
  final bool pinned;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: pinned ? AppColors.pinned : (active ? AppColors.brandSoft : AppColors.canvas),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (pinned) ...[
            const Icon(Icons.lock_rounded, size: 11, color: Color(0xFFB7851B)),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active ? AppColors.brand : AppColors.inkMute,
            ),
          ),
        ]),
      );
}

class _EmptyMembers extends StatelessWidget {
  const _EmptyMembers();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.groups_2_outlined, size: 44, color: AppColors.brandLine),
            const SizedBox(height: 12),
            const Text('아직 등록된 사람이 없습니다',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.inkSub)),
            const SizedBox(height: 6),
            const Text(
              '위 칸에 이름을 입력하거나\n복사한 명단을 가져오세요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.inkMute, height: 1.5),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => showImportDialog(context),
              icon: const Icon(Icons.group_add_outlined, size: 18),
              label: const Text('명단 가져오기'),
            ),
          ],
        ),
      );
}
