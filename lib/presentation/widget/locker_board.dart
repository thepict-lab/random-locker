import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/locker_models.dart';
import '../../main.dart';
import '../controller/locker_controller.dart';
import 'member_picker_dialog.dart';

/// 끌어서 옮기는 값 — 목록에서 끌면 [fromSlot] 이 없다.
class MemberDrag {
  const MemberDrag(this.memberId, {this.fromSlot});

  final String memberId;
  final SlotKey? fromSlot;
}

/// 신발장 세트를 나란히 그린다. 창 크기에 맞춰 칸 크기를 정한다.
class LockerBoard extends StatelessWidget {
  const LockerBoard({super.key, required this.boundaryKey});

  /// 이미지 저장 때 이 영역을 그대로 찍는다
  final GlobalKey boundaryKey;

  static const _gap = 6.0; // 칸 사이
  static const _bankGap = 28.0; // 세트 사이
  static const _bankPad = 16.0; // 세트 카드 안쪽
  static const _bankHeader = 40.0;
  static const _outerPad = 24.0;
  static const _caption = 36.0;
  static const _aspect = 1.6; // 칸 가로 : 세로

  @override
  Widget build(BuildContext context) {
    final c = LockerController.to;
    return Obx(() {
      c.version.value;
      final banks = c.state.banks;
      return LayoutBuilder(builder: (context, box) {
        final maxRows = banks.map((b) => b.rows).fold(1, max);
        final sumCols = banks.fold(0, (s, b) => s + b.cols);

        final fixedW = _outerPad * 2 +
            banks.length * _bankPad * 2 +
            (banks.length - 1) * _bankGap +
            banks.fold(0.0, (s, b) => s + (b.cols - 1) * _gap);
        final fixedH = _outerPad * 2 + _caption + _bankPad * 2 + _bankHeader + (maxRows - 1) * _gap;

        final byWidth = (box.maxWidth - fixedW) / (sumCols * _aspect);
        final byHeight = (box.maxHeight - fixedH) / maxRows;
        final cellH = min(byWidth, byHeight).clamp(30.0, 96.0);
        final cellW = cellH * _aspect;

        final board = RepaintBoundary(
          key: boundaryKey,
          child: Container(
            color: AppColors.canvas,
            padding: const EdgeInsets.all(_outerPad),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: _caption, child: _Caption()),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < banks.length; i++) ...[
                      if (i > 0) const SizedBox(width: _bankGap),
                      _BankCard(bank: banks[i], cellW: cellW, cellH: cellH),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );

        // 창이 너무 작으면 스크롤로 본다.
        return Scrollbar(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: box.maxWidth, minHeight: box.maxHeight),
                child: Center(child: board),
              ),
            ),
          ),
        );
      });
    });
  }
}

class _Caption extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = LockerController.to;
    final at = c.state.lastShuffledAt;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('신발장 배치표',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
        const SizedBox(width: 10),
        if (at != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '${at.year}.${at.month.toString().padLeft(2, '0')}.${at.day.toString().padLeft(2, '0')} 배치',
              style: const TextStyle(fontSize: 12.5, color: AppColors.inkMute),
            ),
          ),
        const SizedBox(width: 40),
        const _Legend(color: Colors.white, line: AppColors.brandLine, label: '배치됨'),
        const _Legend(color: AppColors.pinned, line: AppColors.pinnedLine, label: '고정'),
        const _Legend(color: AppColors.disabled, line: Color(0xFFD3D8E0), label: '사용 안 함'),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.line, required this.label});

  final Color color;
  final Color line;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 14, top: 3),
        child: Row(children: [
          Container(
            width: 14,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: line),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.inkSub)),
        ]),
      );
}

class _BankCard extends StatelessWidget {
  const _BankCard({required this.bank, required this.cellW, required this.cellH});

  final LockerBank bank;
  final double cellW;
  final double cellH;

  @override
  Widget build(BuildContext context) {
    final c = LockerController.to;
    final used = List.generate(bank.size, (i) => slotKey(bank.id, i))
        .where(c.state.assignments.containsKey)
        .length;
    return Container(
      padding: const EdgeInsets.all(LockerBoard._bankPad),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(color: Color(0x0F0F172A), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: LockerBoard._bankHeader,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(bank.name,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text('신발장',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.ink)),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('가로 ${bank.cols} × 세로 ${bank.rows}  ·  $used/${bank.size - bank.disabled.length}',
                      style: const TextStyle(fontSize: 12, color: AppColors.inkMute)),
                ),
              ],
            ),
          ),
          for (var r = 0; r < bank.rows; r++) ...[
            if (r > 0) const SizedBox(height: LockerBoard._gap),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var col = 0; col < bank.cols; col++) ...[
                  if (col > 0) const SizedBox(width: LockerBoard._gap),
                  SizedBox(
                    width: cellW,
                    height: cellH,
                    child: LockerCell(bank: bank, index: r * bank.cols + col, height: cellH),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 신발장 한 칸 — 누르면 메뉴, 끌어서 다른 칸과 맞바꾼다.
class LockerCell extends StatelessWidget {
  const LockerCell({super.key, required this.bank, required this.index, required this.height});

  final LockerBank bank;
  final int index;
  final double height;

  SlotKey get slot => slotKey(bank.id, index);

  @override
  Widget build(BuildContext context) {
    final c = LockerController.to;
    return Obx(() {
      c.version.value;
      c.revealCount.value;
      final hovered = c.hoveredMember.value;
      final member = c.memberById(c.memberAt(slot));
      final disabled = bank.disabled.contains(index);
      final pinned = c.isPinned(slot);
      final hidden = c.isHidden(slot);
      final highlight = member != null && member.id == hovered;
      final number = c.numberOf(bank, index);

      final violation = !hidden && c.violatesCondition(slot);

      Widget cell(bool dropping) => _CellFace(
            number: number,
            name: member?.name,
            violation: violation,
            height: height,
            disabled: disabled,
            pinned: pinned,
            hidden: hidden,
            highlight: highlight,
            dropping: dropping,
            hiddenName: hidden ? _rollingName(c) : null,
          );

      Widget body = DragTarget<MemberDrag>(
        onWillAcceptWithDetails: (d) => !disabled && d.data.fromSlot != slot,
        onAcceptWithDetails: (d) {
          final from = d.data.fromSlot;
          if (from != null) {
            c.swapSlots(from, slot);
          } else {
            c.placeMember(d.data.memberId, slot);
          }
          _warnIfViolates([slot, ?from]);
        },
        builder: (context, candidates, _) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _showMenu(context, d.globalPosition),
          onSecondaryTap: _toggleDisabled,
          child: MouseRegion(
            cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
            child: cell(candidates.isNotEmpty),
          ),
        ),
      );

      if (member != null && !hidden && !disabled) {
        body = Draggable<MemberDrag>(
          data: MemberDrag(member.id, fromSlot: slot),
          feedback: NameChip(name: member.name),
          childWhenDragging: Opacity(opacity: 0.35, child: cell(false)),
          child: body,
        );
      }
      return body;
    });
  }

  /// 연출 중인 칸 — 이름이 슬롯머신처럼 굴러간다
  String _rollingName(LockerController c) {
    final people = c.state.members;
    if (people.isEmpty) return '';
    return people[(index * 7 + bank.id.hashCode + c.revealCount.value * 3) % people.length].name;
  }

  /// 손으로 놓은 자리가 배치 조건에 어긋나면 알려 준다 (놓는 것 자체는 막지 않는다).
  static void _warnIfViolates(List<SlotKey> slots) {
    final c = LockerController.to;
    for (final s in slots) {
      final member = c.memberById(c.memberAt(s));
      if (member == null || c.isAllowed(member.id, s)) continue;
      final rules = c.conditionsOf(member.id).where((x) => x.forbids(member.id, s));
      showToast('${member.name}님은 ${rules.map((x) => x.name).join(', ')}에 따라 '
          '${c.slotLabel(s)}번에 배치하지 않는 조건이 있습니다.');
      return;
    }
  }

  /// 우클릭 — 메뉴 없이 바로 사용 안 함 / 다시 사용
  void _toggleDisabled() {
    final c = LockerController.to;
    if (c.isRevealing) {
      c.skipReveal();
      return;
    }
    final member = c.memberById(c.memberAt(slot));
    final wasDisabled = bank.disabled.contains(index);
    c.toggleDisabled(slot);
    if (!wasDisabled && member != null) {
      showToast('${c.slotLabel(slot)}번을 사용 안 함으로 바꿨습니다. ${member.name}님은 미배치가 됩니다.',
          actionLabel: '되돌리기', onAction: c.undo);
    }
  }

  Future<void> _showMenu(BuildContext context, Offset at) async {
    final c = LockerController.to;
    if (c.isRevealing) {
      c.skipReveal();
      return;
    }
    final member = c.memberById(c.memberAt(slot));
    final disabled = bank.disabled.contains(index);
    final pinned = c.isPinned(slot);
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(at & const Size(1, 1), Offset.zero & overlay.size),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          height: 34,
          child: Text(
            '${c.slotLabel(slot)}번${member != null ? '  ·  ${member.name}' : ''}',
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
        ),
        const PopupMenuDivider(),
        if (!disabled) ...[
          _item('pick', Icons.person_search_rounded, member == null ? '사람 지정…' : '다른 사람으로 바꾸기…'),
          if (member != null) ...[
            _item('pin', pinned ? Icons.lock_open_rounded : Icons.lock_rounded,
                pinned ? '고정 풀기' : '고정 (랜덤 배치에서 제외)'),
            _item('clear', Icons.backspace_outlined, '칸 비우기'),
          ],
        ],
        _item('disable', disabled ? Icons.check_circle_outline_rounded : Icons.block_rounded,
            disabled ? '다시 사용' : '사용 안 함'),
      ],
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'pick':
        final id = await showMemberPicker(context, title: '${c.slotLabel(slot)}번에 넣을 사람');
        if (id != null) {
          final from = c.slotOf(id);
          c.placeMember(id, slot);
          _warnIfViolates([slot, ?from]);
        }
      case 'pin':
        c.togglePin(slot);
      case 'clear':
        c.clearSlot(slot);
      case 'disable':
        c.toggleDisabled(slot);
    }
  }

  PopupMenuItem<String> _item(String value, IconData icon, String label) => PopupMenuItem(
        value: value,
        height: 40,
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.inkSub),
          const SizedBox(width: 10),
          Text(label),
        ]),
      );
}

class _CellFace extends StatelessWidget {
  const _CellFace({
    required this.number,
    required this.name,
    required this.height,
    required this.disabled,
    required this.pinned,
    required this.hidden,
    required this.highlight,
    required this.dropping,
    required this.hiddenName,
    this.violation = false,
  });

  final int number;
  final String? name;

  /// 배치 조건에 어긋난 자리 (손으로 놓았거나 고정한 경우)
  final bool violation;
  final double height;
  final bool disabled;
  final bool pinned;
  final bool hidden;
  final bool highlight;
  final bool dropping;
  final String? hiddenName;

  @override
  Widget build(BuildContext context) {
    final filled = name != null && !hidden;
    final Color bg;
    final Color border;
    if (dropping) {
      bg = AppColors.brandSoft;
      border = AppColors.brand;
    } else if (disabled) {
      bg = AppColors.disabled;
      border = AppColors.disabled;
    } else if (hidden) {
      bg = AppColors.brandSoft;
      border = AppColors.brandLine;
    } else if (pinned) {
      bg = AppColors.pinned;
      border = AppColors.pinnedLine;
    } else if (filled) {
      bg = Colors.white;
      border = AppColors.brandLine;
    } else {
      bg = const Color(0xFFF8FAFC);
      border = AppColors.line;
    }

    final nameSize = (height * 0.27).clamp(11.0, 19.0);
    final numberSize = (height * 0.17).clamp(9.0, 12.5);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight ? AppColors.brand : border,
          width: highlight || dropping ? 2 : 1,
        ),
        boxShadow: highlight
            ? const [BoxShadow(color: Color(0x400152BD), blurRadius: 10)]
            : const [],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 6,
            top: 3,
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: numberSize,
                fontWeight: FontWeight.w700,
                color: disabled ? AppColors.inkMute : (filled ? AppColors.brand : AppColors.inkMute),
              ),
            ),
          ),
          if (violation)
            Positioned(
              right: 4,
              bottom: 3,
              child: Tooltip(
                message: '배치 조건에 어긋난 자리입니다',
                child: Icon(Icons.warning_amber_rounded,
                    size: numberSize + 2, color: const Color(0xFFE08A00)),
              ),
            ),
          if (pinned && !hidden)
            Positioned(
              right: 4,
              top: 3,
              child: Icon(Icons.lock_rounded, size: numberSize + 1, color: const Color(0xFFB7851B)),
            ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(6, numberSize * 0.9, 6, 2),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutBack,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(scale: Tween(begin: 0.6, end: 1.0).animate(anim), child: child),
                  ),
                  child: _label(nameSize),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(double size) {
    if (disabled) {
      return Icon(Icons.block_rounded, key: const ValueKey('x'), size: size, color: AppColors.inkMute);
    }
    if (hidden) {
      return Text(
        hiddenName ?? '',
        key: const ValueKey('hidden'),
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: TextStyle(fontSize: size * 0.9, color: AppColors.brand.withValues(alpha: 0.35)),
      );
    }
    if (name == null) return const SizedBox.shrink(key: ValueKey('empty'));
    return FittedBox(
      key: ValueKey(name),
      fit: BoxFit.scaleDown,
      child: Text(
        name!,
        maxLines: 1,
        style: TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: AppColors.ink),
      ),
    );
  }
}

/// 끌고 다닐 때 마우스를 따라오는 이름표
class NameChip extends StatelessWidget {
  const NameChip({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [BoxShadow(color: Color(0x400152BD), blurRadius: 14, offset: Offset(0, 4))],
          ),
          child: Text(name,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
        ),
      );
}
