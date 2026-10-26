import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/locker_models.dart';
import '../controller/locker_controller.dart';

Future<void> showTeamDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _TeamDialog());

/// 팀 설정 — 팀을 만들고, 이름을 팀으로 끌어다 놓아 소속을 정하고, 왕관으로 팀장을 고른다.
/// 바뀐 것은 바로 반영된다 (Ctrl+Z 로 되돌릴 수 있다).
class _TeamDialog extends StatefulWidget {
  const _TeamDialog();

  @override
  State<_TeamDialog> createState() => _TeamDialogState();
}

class _TeamDialogState extends State<_TeamDialog> {
  final c = LockerController.to;
  String _query = '';

  Future<void> _rename(Team t) async {
    final ctrl = TextEditingController(text: t.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('팀 이름'),
        content: SizedBox(
          width: 300,
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
    if (name != null) c.renameTeam(t.id, name);
  }

  Future<void> _remove(Team t) async {
    final n = c.membersOf(t.id).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${t.name} 삭제'),
        content: Text(n == 0 ? '팀을 지웁니다.' : '소속 $n명은 「소속 없음」이 됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok == true) c.removeTeam(t.id);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      title: const Row(children: [
        Icon(Icons.groups_rounded, color: AppColors.brand),
        SizedBox(width: 8),
        Text('팀 설정'),
        SizedBox(width: 12),
        Text('이름을 팀으로 끌어다 놓으세요 · 👑 를 누르면 팀장',
            style: TextStyle(fontSize: 13, color: AppColors.inkMute, fontWeight: FontWeight.w500)),
      ]),
      content: SizedBox(
        width: 1180,
        height: 640,
        child: Obx(() {
          c.version.value;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 240, child: _unassigned()),
              const VerticalDivider(width: 28),
              Expanded(child: _teams()),
            ],
          );
        }),
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
      ],
    );
  }

  Widget _unassigned() {
    final list = c.state.members
        .where((m) => m.teamId == null && m.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return DragTarget<String>(
      onAcceptWithDetails: (d) => c.setMemberTeam(d.data, null),
      builder: (context, candidates, _) => Container(
        decoration: BoxDecoration(
          color: candidates.isNotEmpty ? AppColors.brandSoft : AppColors.canvas,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('소속 없음  ${c.state.members.where((m) => m.teamId == null).length}명',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                hintText: '이름 검색',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
                fillColor: Colors.white,
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final m in list) _MemberChip(member: m)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teams() => SingleChildScrollView(
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final t in c.state.teams)
              _TeamCard(team: t, onRename: () => _rename(t), onRemove: () => _remove(t)),
            InkWell(
              onTap: () => c.addTeam(),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 280,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line, width: 1.5),
                ),
                alignment: Alignment.center,
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded, color: AppColors.brand),
                  SizedBox(width: 6),
                  Text('팀 추가', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.brand)),
                ]),
              ),
            ),
          ],
        ),
      );
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.team, required this.onRename, required this.onRemove});

  final Team team;
  final VoidCallback onRename;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = LockerController.to;
    final members = c.membersOf(team.id)
      ..sort((a, b) => (b.id == team.leaderId ? 1 : 0) - (a.id == team.leaderId ? 1 : 0));
    final color = AppColors.teamColor(team.color);
    return DragTarget<String>(
      onAcceptWithDetails: (d) => c.setMemberTeam(d.data, team.id),
      builder: (context, candidates, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 280,
        constraints: const BoxConstraints(minHeight: 120),
        decoration: BoxDecoration(
          color: candidates.isNotEmpty ? AppColors.teamSoft(team.color) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: candidates.isNotEmpty ? color : AppColors.line, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: Row(children: [
                Expanded(
                  child: InkWell(
                    onTap: onRename,
                    child: Text('${team.name}  ${members.length}명',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
                PopupMenuButton<int>(
                  tooltip: '색',
                  icon: const Icon(Icons.palette_outlined, color: Colors.white, size: 18),
                  onSelected: (i) => c.setTeamColor(team.id, i),
                  itemBuilder: (_) => [
                    for (var i = 0; i < AppColors.team.length; i++)
                      PopupMenuItem(
                        value: i,
                        height: 36,
                        child: Container(width: 60, height: 18, color: AppColors.team[i]),
                      ),
                  ],
                ),
                IconButton(
                  tooltip: '이름 바꾸기',
                  onPressed: onRename,
                  icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                ),
                IconButton(
                  tooltip: '팀 삭제',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 18),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: members.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Text('여기로 이름을 끌어다 놓으세요',
                          textAlign: TextAlign.center, style: TextStyle(color: AppColors.inkMute)),
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final m in members) _MemberChip(member: m, team: team),
                      ],
                    ),
            ),
            if (team.leaderId == null && members.isNotEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Text('👑 를 눌러 팀장을 정해 주세요',
                    style: TextStyle(fontSize: 12, color: AppColors.inkMute)),
              ),
          ],
        ),
      ),
    );
  }
}

/// 끌 수 있는 이름표. 팀 안에서는 왕관 버튼으로 팀장을 정한다.
class _MemberChip extends StatelessWidget {
  const _MemberChip({required this.member, this.team});

  final Member member;
  final Team? team;

  @override
  Widget build(BuildContext context) {
    final c = LockerController.to;
    final leader = team != null && team!.leaderId == member.id;
    Widget chip({bool dragging = false}) => Material(
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.fromLTRB(10, 5, team == null ? 10 : 2, 5),
            decoration: BoxDecoration(
              color: leader ? const Color(0xFFFFF4D6) : (dragging ? AppColors.brand : Colors.white),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: leader ? AppColors.pinnedLine : AppColors.line),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(
                member.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: dragging ? Colors.white : (member.excluded ? AppColors.inkMute : AppColors.ink),
                  decoration: member.excluded ? TextDecoration.lineThrough : null,
                ),
              ),
              if (team != null && !dragging)
                InkWell(
                  onTap: () => c.toggleLeader(team!.id, member.id),
                  borderRadius: BorderRadius.circular(6),
                  child: Tooltip(
                    message: leader ? '팀장 풀기' : '팀장으로',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Opacity(
                        opacity: leader ? 1 : 0.25,
                        child: const Text('👑', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        );
    return Draggable<String>(
      data: member.id,
      feedback: chip(dragging: true),
      childWhenDragging: Opacity(opacity: 0.35, child: chip()),
      child: MouseRegion(cursor: SystemMouseCursors.grab, child: chip()),
    );
  }
}
