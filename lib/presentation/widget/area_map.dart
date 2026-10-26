import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/locker_models.dart';
import '../controller/locker_controller.dart';

/// 신발장을 작게 그려 영역을 색으로 보여 준다.
///
/// - [areas] 를 넘기면 그 목록으로 칠한다 (설정 화면의 사본). 없으면 저장된 영역.
/// - [onTapSlot] 이 있으면 칸을 누를 수 있고, [onTapLine] 이 있으면 줄 · 열 머리를 누를 수 있다.
/// - [showNames] 면 칸에 앉은 사람 이름을 쓴다.
class AreaMap extends StatelessWidget {
  const AreaMap({
    super.key,
    this.areas,
    this.cellWidth = 46,
    this.cellHeight = 30,
    this.showNames = false,
    this.highlight,
    this.onTapSlot,
    this.onTapLine,
    this.dark = false,
    this.byOwner = true,
    this.softFree = false,
  });

  /// 팀이 가져간 영역은 팀 색으로 칠한다 (설정 화면에서는 영역 자기 색)
  final bool byOwner;

  /// 아직 주인 없는 영역은 옅게 — 영역 고르기에서 남은 영역과 가져간 영역을 가른다
  final bool softFree;

  final List<LockerArea>? areas;
  final double cellWidth;
  final double cellHeight;
  final bool showNames;

  /// 밝게 보여 줄 영역 (나머지는 옅게)
  final String? highlight;
  final void Function(SlotKey slot)? onTapSlot;
  final void Function(List<SlotKey> slots)? onTapLine;

  /// 어두운 무대 위에 그릴 때
  final bool dark;

  static const _gap = 3.0;

  @override
  Widget build(BuildContext context) {
    final c = LockerController.to;
    final list = areas ?? c.state.areas;
    final owner = {for (final a in list) for (final s in a.slots) s: a};
    return Wrap(
      spacing: 28,
      runSpacing: 16,
      children: [
        for (final bank in c.state.banks) _bank(c, bank, owner),
      ],
    );
  }

  Widget _bank(LockerController c, LockerBank bank, Map<SlotKey, LockerArea> owner) {
    final head = TextStyle(fontSize: 10.5, color: dark ? const Color(0x99FFFFFF) : AppColors.inkMute);
    Widget header(String label, List<SlotKey> slots, {double? width, double? height}) {
      final text = SizedBox(
        width: width,
        height: height,
        child: Center(child: Text(label, style: head)),
      );
      if (onTapLine == null) return text;
      return InkWell(
          onTap: () => onTapLine!(slots), borderRadius: BorderRadius.circular(4), child: text);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${bank.name} 신발장',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: dark ? Colors.white : AppColors.ink)),
        const SizedBox(height: 6),
        Row(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 30),
          for (var col = 0; col < bank.cols; col++)
            Padding(
              padding: const EdgeInsets.only(right: _gap),
              child: header('${col + 1}열',
                  [for (var r = 0; r < bank.rows; r++) slotKey(bank.id, r * bank.cols + col)],
                  width: cellWidth, height: 18),
            ),
        ]),
        for (var r = 0; r < bank.rows; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: _gap),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              header('${r + 1}줄',
                  [for (var col = 0; col < bank.cols; col++) slotKey(bank.id, r * bank.cols + col)],
                  width: 30, height: cellHeight),
              for (var col = 0; col < bank.cols; col++)
                Padding(
                  padding: const EdgeInsets.only(right: _gap),
                  child: _cell(c, bank, r * bank.cols + col, owner),
                ),
            ]),
          ),
      ],
    );
  }

  Widget _cell(LockerController c, LockerBank bank, int index, Map<SlotKey, LockerArea> owner) {
    final key = slotKey(bank.id, index);
    final area = owner[key];
    final disabled = bank.disabled.contains(index);
    final dimmed = highlight != null && area?.id != highlight;
    final name = showNames ? c.memberById(c.memberAt(key))?.name : null;

    Color bg;
    Color fg;
    if (disabled) {
      bg = dark ? const Color(0x22FFFFFF) : AppColors.disabled;
      fg = AppColors.inkMute;
    } else if (area != null && softFree && area.teamId == null) {
      bg = AppColors.teamSoft(area.color);
      fg = AppColors.teamColor(area.color);
    } else if (area != null) {
      bg = AppColors.teamColor(byOwner ? c.colorOfArea(area) : area.color);
      fg = Colors.white;
    } else {
      bg = dark ? const Color(0x14FFFFFF) : Colors.white;
      fg = dark ? const Color(0x80FFFFFF) : AppColors.inkMute;
    }
    if (dimmed && area != null) {
      bg = Color.alphaBlend(bg.withValues(alpha: 0.25), dark ? const Color(0xFF0B0F16) : Colors.white);
    }

    final face = Container(
      width: cellWidth,
      height: cellHeight,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
            color: area == null
                ? (dark ? const Color(0x22FFFFFF) : AppColors.line)
                : (softFree && area.teamId == null
                    ? AppColors.teamColor(area.color).withValues(alpha: 0.5)
                    : Colors.transparent)),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: disabled
          ? Icon(Icons.block_rounded, size: cellHeight * 0.45, color: AppColors.inkMute)
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                name ?? '${c.numberOf(bank, index)}',
                maxLines: 1,
                style: TextStyle(
                  fontSize: name == null ? 11 : 12,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
    );
    if (onTapSlot == null) return face;
    return InkWell(onTap: () => onTapSlot!(key), borderRadius: BorderRadius.circular(5), child: face);
  }
}
