import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/navigation/app_navigation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/win_file_dialog.dart';
import '../../main.dart';
import '../controller/locker_controller.dart';
import '../widget/condition_dialog.dart';
import '../widget/locker_board.dart';
import '../widget/member_panel.dart';
import '../widget/area_dialog.dart';
import '../widget/settings_dialog.dart';
import '../widget/team_dialog.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _boardKey = GlobalKey();
  late final AppLifecycleListener _lifecycle;

  LockerController get c => LockerController.to;

  @override
  void initState() {
    super.initState();
    // 창을 닫을 때 미뤄 둔 저장을 마저 한다.
    _lifecycle = AppLifecycleListener(onExitRequested: () async {
      await c.flush();
      return ui.AppExitResponse.exit;
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _shuffle() {
    if (c.activeMembers.isEmpty) {
      showToast('먼저 멤버를 등록해 주세요.');
      return;
    }
    if (c.usableSlots == 0) {
      showToast('사용할 수 있는 칸이 없습니다.');
      return;
    }
    final report = c.shuffle();
    if (report.leftOver.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (!mounted) return;
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(report.limitedByConditions ? '조건에 맞는 자리가 없습니다' : '칸이 모자랍니다'),
            content: SizedBox(
              width: 380,
              child: Text(
                '${report.leftOver.length}명은 칸을 받지 못했습니다.\n\n'
                '${report.leftOver.map((m) => m.name).join(', ')}\n\n'
                '${report.limitedByConditions ? '배치 조건에서 제외한 자리가 너무 많거나, 조건끼리 겹치지 않는지 확인해 주세요.' : '신발장 설정에서 칸을 늘리거나, 배치에서 제외할 사람을 정해 주세요.'}',
              ),
            ),
            actions: [
              FilledButton(onPressed: () => Navigator.pop(context), child: const Text('확인')),
            ],
          ),
        );
      });
    } else {
      showToast('${report.placed}명을 랜덤으로 배치했습니다.',
          actionLabel: '되돌리기', onAction: c.undo);
    }
  }

  Future<void> _clear() async {
    if (c.assignedCount == 0) return;
    final hasPinned = c.state.pinned.isNotEmpty;
    final keepPinned = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('배치 비우기'),
        content: Text(hasPinned
            ? '고정한 칸을 남길까요?'
            : '모든 칸을 비웁니다. 되돌리기(Ctrl+Z)로 되살릴 수 있습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          if (hasPinned)
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('고정까지 모두 비우기'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context, hasPinned),
            child: Text(hasPinned ? '고정 칸은 남기기' : '비우기'),
          ),
        ],
      ),
    );
    if (keepPinned == null) return;
    c.clearAll(keepPinned: keepPinned);
  }

  String get _dateStamp {
    final d = DateTime.now();
    return '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _savePng() async {
    c.skipReveal();
    await WidgetsBinding.instance.endOfFrame;
    final boundary = _boardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 2.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) return;
    final path = WinFileDialog.save(
      title: '배치표 이미지 저장',
      filters: const [('PNG 이미지', '*.png')],
      fileName: '신발장배치_$_dateStamp.png',
      defaultExtension: 'png',
    );
    if (path == null) return;
    await File(path).writeAsBytes(data.buffer.asUint8List(), flush: true);
    showToast('이미지를 저장했습니다.',
        actionLabel: '폴더 열기', onAction: () => WinFileDialog.reveal(path));
  }

  Future<void> _saveCsv() async {
    final path = WinFileDialog.save(
      title: '배치표 CSV 저장',
      filters: const [('CSV (엑셀)', '*.csv')],
      fileName: '신발장배치_$_dateStamp.csv',
      defaultExtension: 'csv',
    );
    if (path == null) return;
    await File(path).writeAsString(c.toCsv(), flush: true);
    showToast('CSV 를 저장했습니다.',
        actionLabel: '폴더 열기', onAction: () => WinFileDialog.reveal(path));
  }

  Future<void> _copyText() async {
    await Clipboard.setData(ClipboardData(text: c.toPlainText()));
    showToast('배치표를 복사했습니다. 잔디 메시지 창에 붙여넣으세요.');
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): c.undo,
        const SingleActivator(LogicalKeyboardKey.f5): _shuffle,
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _shuffle,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Column(
            children: [
              _TopBar(
                onShuffle: _shuffle,
                onClear: _clear,
                onSavePng: _savePng,
                onSaveCsv: _saveCsv,
                onCopyText: _copyText,
              ),
              const Divider(height: 1),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(width: 300, child: MemberPanel()),
                    const VerticalDivider(width: 1),
                    Expanded(child: LockerBoard(boundaryKey: _boardKey)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onShuffle,
    required this.onClear,
    required this.onSavePng,
    required this.onSaveCsv,
    required this.onCopyText,
  });

  final VoidCallback onShuffle;
  final VoidCallback onClear;
  final VoidCallback onSavePng;
  final VoidCallback onSaveCsv;
  final VoidCallback onCopyText;

  @override
  Widget build(BuildContext context) {
    final c = LockerController.to;
    return Container(
      height: 64,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Image.asset('assets/images/thepict_logo.png', height: 18,
              filterQuality: FilterQuality.high),
          Container(
            width: 1,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: AppColors.line,
          ),
          const Text('신발장 배치기',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(width: 24),
          Obx(() {
            c.version.value;
            return Row(children: [
              _Stat(label: '배치 대상', value: '${c.activeMembers.length}명'),
              _Stat(label: '배치됨', value: '${c.assignedCount}명'),
              _Stat(
                label: '빈 칸',
                value: '${c.usableSlots - c.assignedCount}칸',
                tooltip: '전체 ${c.totalSlots}칸 · 사용 안 함 ${c.totalSlots - c.usableSlots}칸',
              ),
            ]);
          }),
          const Spacer(),
          Obx(() => IconButton(
                tooltip: '되돌리기 (Ctrl+Z)',
                onPressed: c.canUndo.value ? c.undo : null,
                icon: const Icon(Icons.undo_rounded),
              )),
          IconButton(
            tooltip: '배치 비우기',
            onPressed: onClear,
            icon: const Icon(Icons.layers_clear_outlined),
          ),
          PopupMenuButton<VoidCallback>(
            tooltip: '내보내기',
            onSelected: (action) => action(),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: onSavePng,
                child: const ListTile(
                  dense: true,
                  leading: Icon(Icons.image_outlined),
                  title: Text('이미지로 저장 (PNG)'),
                ),
              ),
              PopupMenuItem(
                value: onSaveCsv,
                child: const ListTile(
                  dense: true,
                  leading: Icon(Icons.table_chart_outlined),
                  title: Text('엑셀용 CSV 저장'),
                ),
              ),
              PopupMenuItem(
                value: onCopyText,
                child: const ListTile(
                  dense: true,
                  leading: Icon(Icons.content_copy_rounded),
                  title: Text('글로 복사 (메신저 공유용)'),
                ),
              ),
            ],
            icon: const Icon(Icons.ios_share_rounded),
          ),
          Obx(() {
            c.version.value;
            final count = c.state.conditions.where((x) => x.enabled).length;
            return TextButton.icon(
              onPressed: () => showConditionDialog(context),
              icon: Badge(
                isLabelVisible: count > 0,
                label: Text('$count'),
                child: const Icon(Icons.rule_rounded),
              ),
              label: const Text('배치 조건'),
            );
          }),
          IconButton(
            tooltip: '팀 설정',
            onPressed: () => showTeamDialog(context),
            icon: const Icon(Icons.groups_rounded),
          ),
          IconButton(
            tooltip: '영역 설정',
            onPressed: () => showAreaDialog(context),
            icon: const Icon(Icons.dashboard_customize_outlined),
          ),
          IconButton(
            tooltip: '신발장 설정',
            onPressed: () => showSettingsDialog(context),
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: '팀장들이 숫자를 골라 추첨하고, 순위대로 영역을 고릅니다',
            child: FilledButton.icon(
              onPressed: () => Get.toNamed(PageInfo.draw),
              style: FilledButton.styleFrom(
                backgroundColor: DrawColors.accent,
                foregroundColor: DrawColors.accentFg,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              icon: const Icon(Icons.casino_rounded),
              label: const Text('팀장 추첨'),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: '고정한 칸은 그대로 두고 섞습니다. 영역을 가진 팀은 자기 영역 안에서만 섞입니다 (F5)',
            child: FilledButton.icon(
              onPressed: onShuffle,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              icon: const Icon(Icons.shuffle_rounded),
              label: const Text('랜덤 배치'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.tooltip});

  final String label;
  final String value;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text.rich(TextSpan(children: [
        TextSpan(text: '$label  ', style: const TextStyle(color: AppColors.inkSub, fontSize: 12.5)),
        TextSpan(
          text: value,
          style: const TextStyle(
              color: AppColors.ink, fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ])),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
  }
}
