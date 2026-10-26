import 'dart:convert';

import 'package:excel/excel.dart' as xl;

import 'win_file_dialog.dart';

/// 명단 텍스트·파일에서 이름만 골라낸다.
///
/// 잔디는 멤버 목록을 꺼내는 공개 API 가 없다. 대신 잔디에서 복사한 목록이나
/// 관리자 메뉴 · 다른 곳에서 받은 엑셀/CSV 를 그대로 넣어도 이름 열을 찾아 읽는다.
abstract final class RosterParser {
  /// 머리글로 보이는 칸 — 이 열을 이름 열로 쓴다
  static final _nameHeader = RegExp(r'^(이름|성명|name|멤버|멤버명|사용자|닉네임|표시\s*이름)$',
      caseSensitive: false);

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _numberLike = RegExp(r'^[\d\s\-+().:/]+$');
  static final _bracket = RegExp(r'\s*[\(\[（【].*?[\)\]）】]\s*');

  /// 붙여넣은 글. 줄마다 탭 · 쉼표 · 세미콜론으로 나눈 표로 본다.
  static List<String> fromText(String text, {bool stripBrackets = true}) {
    final rows = const LineSplitter()
        .convert(text)
        .map((line) => line.split(RegExp(r'[\t,;]')))
        .toList();
    return fromRows(rows, stripBrackets: stripBrackets);
  }

  /// .xlsx · .csv · .txt 파일 바이트
  static List<String> fromFile(String path, List<int> bytes,
      {bool stripBrackets = true}) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.xlsx')) {
      return fromRows(_xlsxRows(bytes), stripBrackets: stripBrackets);
    }
    if (lower.endsWith('.csv')) {
      return fromRows(_csvRows(decodeText(bytes)), stripBrackets: stripBrackets);
    }
    return fromText(decodeText(bytes), stripBrackets: stripBrackets);
  }

  /// UTF-8(BOM 포함)이 아니면 CP949 로 읽는다 — 한국어 엑셀의 "CSV 저장" 기본값.
  static String decodeText(List<int> bytes) {
    var data = bytes;
    if (data.length >= 3 && data[0] == 0xEF && data[1] == 0xBB && data[2] == 0xBF) {
      data = data.sublist(3);
    }
    try {
      return utf8.decode(data);
    } on FormatException {
      return WinCodePage.decodeCp949(data) ?? latin1.decode(data);
    }
  }

  static List<String> fromRows(List<List<String>> rows, {bool stripBrackets = true}) {
    final table = rows
        .map((r) => r.map((c) => c.trim()).toList())
        .where((r) => r.any((c) => c.isNotEmpty))
        .toList();
    if (table.isEmpty) return const [];

    // 머리글 행을 앞쪽 다섯 줄에서 찾는다.
    int? headerRow;
    int? nameCol;
    for (var r = 0; r < table.length && r < 5 && nameCol == null; r++) {
      final c = table[r].indexWhere((cell) => _nameHeader.hasMatch(cell));
      if (c >= 0) {
        headerRow = r;
        nameCol = c;
      }
    }

    final names = <String>[];
    final seen = <String>{};
    for (var r = (headerRow ?? -1) + 1; r < table.length; r++) {
      final row = table[r];
      final raw = nameCol != null
          ? (nameCol < row.length ? row[nameCol] : '')
          : row.firstWhere(_looksLikeName, orElse: () => '');
      final name = clean(raw, stripBrackets: stripBrackets);
      if (name.isEmpty || !_looksLikeName(name)) continue;
      if (seen.add(name)) names.add(name);
    }
    return names;
  }

  /// 앞뒤 공백 · 괄호 속 부서/직함 · 앞에 붙은 번호("1. 홍길동")를 걷어낸다.
  static String clean(String raw, {bool stripBrackets = true}) {
    var s = raw.trim();
    if (stripBrackets) s = s.replaceAll(_bracket, ' ');
    s = s.replaceFirst(RegExp(r'^\d+[.)]\s*'), '');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool _looksLikeName(String cell) {
    final s = cell.trim();
    if (s.isEmpty || s.length > 30) return false;
    if (_email.hasMatch(s) || _numberLike.hasMatch(s)) return false;
    return true;
  }

  static List<List<String>> _xlsxRows(List<int> bytes) {
    final book = xl.Excel.decodeBytes(bytes);
    for (final sheet in book.tables.values) {
      final rows = sheet.rows
          .map((r) => r.map((c) => c?.value?.toString() ?? '').toList())
          .toList();
      if (rows.any((r) => r.any((c) => c.trim().isNotEmpty))) return rows;
    }
    return const [];
  }

  /// 따옴표로 감싼 칸("홍길동, 팀장")까지 읽는 작은 CSV 해석기
  static List<List<String>> _csvRows(String text) {
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var quoted = false;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (quoted) {
        if (ch == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            quoted = false;
          }
        } else {
          cell.write(ch);
        }
      } else if (ch == '"') {
        quoted = true;
      } else if (ch == ',') {
        row.add(cell.toString());
        cell.clear();
      } else if (ch == '\n' || ch == '\r') {
        if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        row.add(cell.toString());
        cell.clear();
        rows.add(row);
        row = <String>[];
      } else {
        cell.write(ch);
      }
    }
    if (cell.isNotEmpty || row.isNotEmpty) {
      row.add(cell.toString());
      rows.add(row);
    }
    return rows;
  }
}
