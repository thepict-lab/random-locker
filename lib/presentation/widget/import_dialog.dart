import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/roster_parser.dart';
import '../../core/utils/win_file_dialog.dart';
import '../../main.dart';
import '../controller/locker_controller.dart';

Future<void> showImportDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _ImportDialog());

/// 명단 가져오기 — 붙여넣기 또는 .xlsx · .csv · .txt 파일
///
/// 잔디는 팀 멤버 목록을 꺼내는 공개 API 를 주지 않는다(웹훅은 메시지 보내기 전용).
/// 그래서 잔디에서 복사한 글이나 내려받은 엑셀을 그대로 받아 이름만 골라낸다.
class _ImportDialog extends StatefulWidget {
  const _ImportDialog();

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _text = TextEditingController();
  bool _stripBrackets = true;
  String? _fileName;
  List<int>? _fileBytes;
  String? _filePath;

  List<String> _names = const [];
  final _unchecked = <String>{};

  LockerController get c => LockerController.to;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _parse() {
    final names = _fileBytes != null
        ? RosterParser.fromFile(_filePath!, _fileBytes!, stripBrackets: _stripBrackets)
        : RosterParser.fromText(_text.text, stripBrackets: _stripBrackets);
    setState(() {
      _names = names;
      _unchecked.retainWhere(names.contains);
    });
  }

  Future<void> _openFile() async {
    final path = WinFileDialog.open(
      title: '명단 파일 열기',
      filters: const [
        ('명단 파일 (엑셀 · CSV · 텍스트)', '*.xlsx;*.csv;*.txt'),
        ('모든 파일', '*.*'),
      ],
    );
    if (path == null) return;
    try {
      final bytes = await File(path).readAsBytes();
      _filePath = path;
      _fileBytes = bytes;
      _fileName = path.split(RegExp(r'[\\/]')).last;
      _text.clear();
      _parse();
      if (_names.isEmpty) showToast('파일에서 이름을 찾지 못했습니다.');
    } catch (e) {
      showToast('파일을 읽지 못했습니다: $e');
    }
  }

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;
    _clearFile();
    _text.text = data!.text!;
    _parse();
  }

  void _clearFile() {
    _fileBytes = null;
    _filePath = null;
    _fileName = null;
  }

  @override
  Widget build(BuildContext context) {
    final fresh = _names.where((n) => !c.hasMemberNamed(n)).toList();
    final selected = fresh.where((n) => !_unchecked.contains(n)).toList();

    return AlertDialog(
      title: const Text('명단 가져오기'),
      content: SizedBox(
        width: 760,
        height: 460,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '멤버 목록이나 엑셀에서 이름을 복사해 붙여넣거나, '
                    '엑셀(.xlsx) · CSV 파일을 여세요. "이름" 열을 자동으로 찾고, '
                    '이메일 · 전화번호 같은 칸은 걸러 냅니다.',
                    style: TextStyle(fontSize: 13, color: AppColors.inkSub, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    OutlinedButton.icon(
                      onPressed: _pasteClipboard,
                      icon: const Icon(Icons.content_paste_rounded, size: 18),
                      label: const Text('클립보드 붙여넣기'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _openFile,
                      icon: const Icon(Icons.file_open_outlined, size: 18),
                      label: const Text('파일 열기…'),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _fileName != null
                        ? _FileCard(
                            name: _fileName!,
                            onClear: () => setState(() {
                              _clearFile();
                              _names = const [];
                            }),
                          )
                        : TextField(
                            controller: _text,
                            expands: true,
                            maxLines: null,
                            textAlignVertical: TextAlignVertical.top,
                            decoration: const InputDecoration(
                              hintText: '홍길동\n김철수 (디자인팀)\n이영희, younghee@pict.kr\n…',
                            ),
                            onChanged: (_) => _parse(),
                          ),
                  ),
                  const SizedBox(height: 6),
                  CheckboxListTile(
                    value: _stripBrackets,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('괄호 안 내용 빼기 — "홍길동 (개발팀)" → "홍길동"'),
                    onChanged: (v) {
                      _stripBrackets = v ?? true;
                      _parse();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 260,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
                      child: Row(children: [
                        Text('미리보기 ${_names.length}명',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        if (fresh.isNotEmpty)
                          TextButton(
                            onPressed: () => setState(() {
                              if (_unchecked.isEmpty) {
                                _unchecked.addAll(fresh);
                              } else {
                                _unchecked.clear();
                              }
                            }),
                            child: Text(_unchecked.isEmpty ? '모두 해제' : '모두 선택'),
                          ),
                      ]),
                    ),
                    Expanded(
                      child: _names.isEmpty
                          ? const Center(
                              child: Text('찾은 이름이 여기에 보입니다',
                                  style: TextStyle(color: AppColors.inkMute, fontSize: 12.5)))
                          : ListView(
                              children: [
                                for (final n in _names)
                                  CheckboxListTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    value: !c.hasMemberNamed(n) && !_unchecked.contains(n),
                                    onChanged: c.hasMemberNamed(n)
                                        ? null
                                        : (v) => setState(() {
                                              if (v == true) {
                                                _unchecked.remove(n);
                                              } else {
                                                _unchecked.add(n);
                                              }
                                            }),
                                    title: Text(n),
                                    subtitle: c.hasMemberNamed(n)
                                        ? const Text('이미 등록됨', style: TextStyle(fontSize: 11))
                                        : null,
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(
          onPressed: selected.isEmpty
              ? null
              : () {
                  final added = c.addMembers(selected);
                  Navigator.pop(context);
                  showToast('$added명을 등록했습니다.');
                },
          child: Text('${selected.length}명 추가'),
        ),
      ],
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({required this.name, required this.onClear});

  final String name;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.brandSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.description_outlined, size: 40, color: AppColors.brand),
            const SizedBox(height: 8),
            Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextButton(onPressed: onClear, child: const Text('다시 고르기')),
          ],
        ),
      );
}
