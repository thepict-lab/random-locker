import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../controller/locker_controller.dart';

/// 칸에 넣을 사람을 고른다. 고른 사람의 id, 취소하면 null.
Future<String?> showMemberPicker(BuildContext context, {required String title}) =>
    showDialog<String>(context: context, builder: (_) => _MemberPicker(title: title));

class _MemberPicker extends StatefulWidget {
  const _MemberPicker({required this.title});

  final String title;

  @override
  State<_MemberPicker> createState() => _MemberPickerState();
}

class _MemberPickerState extends State<_MemberPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = LockerController.to;
    // 미배치 사람을 먼저 보여 준다.
    final people = c.state.members
        .where((m) => m.name.toLowerCase().contains(_query.toLowerCase()))
        .toList()
      ..sort((a, b) {
        final sa = c.slotOf(a.id) == null ? 0 : 1;
        final sb = c.slotOf(b.id) == null ? 0 : 1;
        return sa != sb ? sa - sb : a.name.compareTo(b.name);
      });

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 360,
        height: 420,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded, size: 20),
                hintText: '이름 검색',
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
              onSubmitted: (_) {
                if (people.isNotEmpty) Navigator.pop(context, people.first.id);
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: people.isEmpty
                  ? const Center(
                      child: Text('등록된 사람이 없습니다', style: TextStyle(color: AppColors.inkMute)))
                  : ListView.builder(
                      itemCount: people.length,
                      itemBuilder: (context, i) {
                        final m = people[i];
                        final slot = c.slotOf(m.id);
                        return ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          title: Text(m.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: m.excluded ? AppColors.inkMute : AppColors.ink,
                              )),
                          trailing: Text(
                            slot != null
                                ? '${c.slotLabel(slot)}번 → 맞바꿈'
                                : (m.excluded ? '제외됨 → 포함' : '미배치'),
                            style: const TextStyle(fontSize: 12, color: AppColors.inkMute),
                          ),
                          onTap: () => Navigator.pop(context, m.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
      ],
    );
  }
}
