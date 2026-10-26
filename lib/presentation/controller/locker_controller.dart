import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:get/get.dart';

import '../../data/models/locker_models.dart';
import '../../data/repository/locker_repository.dart';

/// 랜덤 배치 결과
class ShuffleReport {
  const ShuffleReport({
    required this.placed,
    required this.leftOver,
    required this.limitedByConditions,
  });

  /// 이번에 새로 칸을 받은 사람 수 (고정 칸 제외)
  final int placed;

  /// 칸을 받지 못한 사람
  final List<Member> leftOver;

  /// 빈 칸은 남았는데 배치 조건 때문에 못 들어간 사람이 있다
  final bool limitedByConditions;
}

/// 신발장 설정 화면에서 넘겨받는 한 세트의 값
class BankEdit {
  const BankEdit({this.id, required this.name, required this.cols, required this.rows});

  /// 새로 만드는 세트면 null
  final String? id;
  final String name;
  final int cols;
  final int rows;
}

class LockerController extends GetxController {
  LockerController(this._repository);

  static LockerController get to => Get.find();

  final LockerRepository _repository;
  final _random = Random();

  late LockerState state;

  /// 상태가 바뀔 때마다 1 씩 오른다 — 화면은 이 값 하나만 지켜본다.
  final version = 0.obs;

  /// 목록에서 마우스를 올린 사람 — 신발장에서 그 칸을 밝힌다
  final hoveredMember = RxnString();

  /// 랜덤 배치 연출 — [revealOrder] 의 앞 [revealCount] 칸만 이름을 보여 준다
  final revealCount = 0.obs;
  Map<SlotKey, int> revealOrder = const {};
  bool get isRevealing => revealOrder.isNotEmpty;
  Timer? _revealTimer;

  final _undo = <String>[];
  final canUndo = false.obs;
  static const _undoLimit = 30;

  Timer? _saveTimer;
  late final Future<void> ready = _load();

  Map<String, SlotKey>? _slotOfMember;

  Future<void> _load() async {
    state = await _repository.load();
    _sanitize();
    version.value++;
  }

  // ───────────────────────── 조회 ─────────────────────────

  Member? memberById(String? id) =>
      id == null ? null : state.members.firstWhereOrNull((m) => m.id == id);

  LockerBank? bankById(String id) => state.banks.firstWhereOrNull((b) => b.id == id);

  String? memberAt(SlotKey slot) => state.assignments[slot];

  SlotKey? slotOf(String memberId) {
    _slotOfMember ??= {for (final e in state.assignments.entries) e.value: e.key};
    return _slotOfMember![memberId];
  }

  bool isPinned(SlotKey slot) => state.pinned.contains(slot);

  /// 배치 조건으로 보아 [memberId] 를 [slot] 에 둘 수 있는가
  bool isAllowed(String memberId, SlotKey slot) =>
      !state.conditions.any((c) => c.forbids(memberId, slot));

  /// [memberId] 가 대상인 (켜진) 조건
  List<LockerCondition> conditionsOf(String memberId) => state.conditions
      .where((c) => c.enabled && c.memberIds.contains(memberId))
      .toList();

  /// 이 칸의 사람이 조건에 어긋나 있다 (손으로 놓았거나 고정한 경우)
  bool violatesCondition(SlotKey slot) {
    final id = state.assignments[slot];
    return id != null && !isAllowed(id, slot);
  }

  bool isDisabled(SlotKey slot) {
    final (bankId, index) = parseSlotKey(slot);
    return bankById(bankId)?.disabled.contains(index) ?? true;
  }

  /// 사람에게 보여 주는 칸 번호 (번호 방향 · 이어 매기기 설정 반영)
  int numberOf(LockerBank bank, int index) {
    final r = index ~/ bank.cols;
    final c = index % bank.cols;
    final local = state.numbering == NumberingOrder.rowMajor
        ? index + 1
        : c * bank.rows + r + 1;
    if (!state.continuousNumbering) return local;
    var offset = 0;
    for (final b in state.banks) {
      if (b.id == bank.id) break;
      offset += b.size;
    }
    return offset + local;
  }

  /// "A-12" 같은 칸 이름
  String slotLabel(SlotKey slot) {
    final (bankId, index) = parseSlotKey(slot);
    final bank = bankById(bankId);
    if (bank == null) return slot;
    return '${bank.name}-${numberOf(bank, index)}';
  }

  /// 배치 대상(제외하지 않은 사람)
  List<Member> get activeMembers => state.members.where((m) => !m.excluded).toList();

  int get totalSlots => state.banks.fold(0, (sum, b) => sum + b.size);

  int get usableSlots =>
      state.banks.fold(0, (sum, b) => sum + b.size - b.disabled.length);

  int get assignedCount => state.assignments.length;

  List<Member> get unassignedMembers =>
      activeMembers.where((m) => slotOf(m.id) == null).toList();

  // ───────────────────────── 사람 ─────────────────────────

  /// 이름을 여러 개 등록한다. 이미 있는 이름은 건너뛰고, 실제로 넣은 수를 돌려준다.
  int addMembers(Iterable<String> names) {
    final existing = state.members.map((m) => m.name).toSet();
    var added = 0;
    _snapshot();
    for (final raw in names) {
      final name = raw.trim();
      if (name.isEmpty || !existing.add(name)) continue;
      state.members.add(Member(id: _newId(), name: name));
      added++;
    }
    if (added == 0) {
      _dropSnapshot();
    } else {
      _changed();
    }
    return added;
  }

  bool hasMemberNamed(String name) => state.members.any((m) => m.name == name.trim());

  void renameMember(String id, String name) {
    final m = memberById(id);
    if (m == null || name.trim().isEmpty || m.name == name.trim()) return;
    _snapshot();
    m.name = name.trim();
    _changed();
  }

  /// 배치 제외 — 칸을 차지하고 있었다면 비운다.
  void toggleExcluded(String id) {
    final m = memberById(id);
    if (m == null) return;
    _snapshot();
    m.excluded = !m.excluded;
    if (m.excluded) _unassignMember(id);
    _changed();
  }

  void removeMember(String id) {
    _snapshot();
    _unassignMember(id);
    state.members.removeWhere((m) => m.id == id);
    for (final c in state.conditions) {
      c.memberIds.remove(id);
    }
    _changed();
  }

  void removeAllMembers() {
    if (state.members.isEmpty) return;
    _snapshot();
    state.members.clear();
    state.assignments.clear();
    state.pinned.clear();
    for (final c in state.conditions) {
      c.memberIds.clear();
    }
    _changed();
  }

  // ───────────────────────── 배치 조건 ─────────────────────────

  /// 조건 편집 화면에서 고친 목록으로 통째로 바꾼다.
  void replaceConditions(List<LockerCondition> conditions) {
    _snapshot();
    state.conditions
      ..clear()
      ..addAll(conditions);
    _changed();
  }

  /// 새 조건의 기본 이름 — 조건 1, 조건 2 …
  String nextConditionName(Iterable<LockerCondition> existing) {
    final used = existing.map((c) => c.name).toSet();
    var n = 1;
    while (used.contains('조건 $n')) {
      n++;
    }
    return '조건 $n';
  }

  LockerCondition newCondition(Iterable<LockerCondition> existing) =>
      LockerCondition(id: _newId(), name: nextConditionName(existing));

  // ───────────────────────── 칸 ─────────────────────────

  /// 사람을 칸에 넣는다. 그 칸에 누가 있었다면 옮겨 오는 사람의 원래 칸과 맞바꾼다
  /// (원래 칸이 없었으면 그 사람은 미배치가 된다).
  void placeMember(String memberId, SlotKey target) {
    if (isDisabled(target)) return;
    final from = slotOf(memberId);
    if (from == target) return;
    if (from != null) {
      swapSlots(from, target);
      return;
    }
    _snapshot();
    final wasPinned = isPinned(target);
    state.assignments[target] = memberId;
    // 고정은 칸이 아니라 사람에 붙은 것 — 새 사람이 들어오면 풀어 준다.
    if (wasPinned) state.pinned.remove(target);
    final m = memberById(memberId);
    if (m != null && m.excluded) m.excluded = false;
    _changed();
  }

  /// 두 칸의 사람(과 고정 여부)을 맞바꾼다.
  void swapSlots(SlotKey a, SlotKey b) {
    if (a == b || isDisabled(a) || isDisabled(b)) return;
    _snapshot();
    final ma = state.assignments.remove(a);
    final mb = state.assignments.remove(b);
    if (ma != null) state.assignments[b] = ma;
    if (mb != null) state.assignments[a] = mb;
    final pa = state.pinned.remove(a);
    final pb = state.pinned.remove(b);
    if (pa && ma != null) state.pinned.add(b);
    if (pb && mb != null) state.pinned.add(a);
    _changed();
  }

  void clearSlot(SlotKey slot) {
    if (!state.assignments.containsKey(slot)) return;
    _snapshot();
    state.assignments.remove(slot);
    state.pinned.remove(slot);
    _changed();
  }

  void togglePin(SlotKey slot) {
    if (!state.assignments.containsKey(slot)) return;
    _snapshot();
    if (!state.pinned.remove(slot)) state.pinned.add(slot);
    _changed();
  }

  /// 사용 안 함 — 들어 있던 사람은 미배치가 된다.
  void toggleDisabled(SlotKey slot) {
    final (bankId, index) = parseSlotKey(slot);
    final bank = bankById(bankId);
    if (bank == null) return;
    _snapshot();
    if (!bank.disabled.remove(index)) {
      bank.disabled.add(index);
      state.assignments.remove(slot);
      state.pinned.remove(slot);
    }
    _changed();
  }

  // ───────────────────────── 배치 ─────────────────────────

  /// 랜덤 배치. 고정 칸은 그대로 두고 나머지 사람을 남은 칸에 섞어 넣는다.
  /// 배치 조건은 지킨다 — 조건 때문에 들어갈 칸이 없는 사람은 [ShuffleReport.leftOver] 로 알린다.
  ShuffleReport shuffle() {
    _snapshot();
    final keep = <SlotKey, String>{
      for (final slot in state.pinned) slot: ?state.assignments[slot],
    };
    final keptMembers = keep.values.toSet();

    final people = activeMembers.where((m) => !keptMembers.contains(m.id)).toList()
      ..shuffle(_random);

    final free = <SlotKey>[
      for (final bank in state.banks)
        for (final index in _orderedIndexes(bank))
          if (!bank.disabled.contains(index) &&
              !keep.containsKey(slotKey(bank.id, index)))
            slotKey(bank.id, index),
    ];
    if (state.fillMode == FillMode.scatter) free.shuffle(_random);

    final placed = _assign(people, free);
    state.assignments
      ..clear()
      ..addAll(keep)
      ..addAll(placed);
    state.pinned.retainWhere(keep.containsKey);
    state.lastShuffledAt = DateTime.now();

    _startReveal(placed.keys.toList());
    _changed();
    final seated = placed.values.toSet();
    final leftOver = people.where((m) => !seated.contains(m.id)).toList();
    return ShuffleReport(
      placed: placed.length,
      leftOver: leftOver,
      limitedByConditions: leftOver.isNotEmpty && free.length > placed.length,
    );
  }

  /// 조건을 지키며 [people] 을 [slots] 에 될 수 있는 한 많이 넣는다.
  /// "앞 번호부터" 모드면 [slots] 의 앞쪽을 가장 짧게 쓰는 배치를 고른다.
  Map<SlotKey, String> _assign(List<Member> people, List<SlotKey> slots) {
    final best = _match(people, slots);
    if (state.fillMode != FillMode.sequential) return best;
    // 조건이 앞 칸을 막으면 몇 칸 더 뒤까지 써야 한다 — 다 들어가는 가장 짧은 앞부분을 찾는다.
    for (var k = min(best.length, slots.length); k < slots.length; k++) {
      final m = _match(people, slots.sublist(0, k));
      if (m.length == best.length) return m;
    }
    return best;
  }

  /// 이분 매칭(증가 경로). 사람은 [people] 순서, 칸은 [slots] 순서대로 먼저 시도하므로
  /// 두 목록을 섞어 넘기면 결과도 무작위다. 조건이 걸린 사람(갈 수 있는 칸이 적은 사람)을
  /// 먼저 앉혀서, 칸이 모자랄 때 조건 있는 사람이 밀려나지 않게 한다.
  Map<SlotKey, String> _match(List<Member> people, List<SlotKey> slots) {
    final allowed = {
      for (final m in people) m.id: [for (final s in slots) if (isAllowed(m.id, s)) s],
    };
    final owner = <SlotKey, String>{};

    bool seat(String id, Set<SlotKey> visited) {
      for (final s in allowed[id]!) {
        if (!visited.add(s)) continue;
        final current = owner[s];
        if (current == null || seat(current, visited)) {
          owner[s] = id;
          return true;
        }
      }
      return false;
    }

    final order = [...people]
      ..sort((a, b) => allowed[a.id]!.length.compareTo(allowed[b.id]!.length));
    for (final m in order) {
      seat(m.id, <SlotKey>{});
    }
    return owner;
  }

  /// 칸 번호 순서대로의 index — "앞 번호부터" 채우기에 쓴다.
  Iterable<int> _orderedIndexes(LockerBank bank) {
    final indexes = List.generate(bank.size, (i) => i);
    indexes.sort((a, b) => numberOf(bank, a).compareTo(numberOf(bank, b)));
    return indexes;
  }

  /// 칸이 하나씩 열리는 연출. 순서는 무작위.
  void _startReveal(List<SlotKey> slots) {
    _revealTimer?.cancel();
    final order = [...slots]..shuffle(_random);
    revealOrder = {for (var i = 0; i < order.length; i++) order[i]: i};
    revealCount.value = 0;
    if (order.isEmpty) {
      revealOrder = const {};
      return;
    }
    // 사람이 많아도 연출은 1.6초 안팎에서 끝난다.
    final step = Duration(milliseconds: (1600 / order.length).clamp(18, 70).round());
    _revealTimer = Timer.periodic(step, (t) {
      revealCount.value++;
      if (revealCount.value >= order.length) {
        t.cancel();
        Future.delayed(const Duration(milliseconds: 400), () {
          revealOrder = const {};
          version.value++;
        });
      }
    });
  }

  void skipReveal() {
    _revealTimer?.cancel();
    revealOrder = const {};
    version.value++;
  }

  /// 아직 이름을 가리고 있는 칸인가
  bool isHidden(SlotKey slot) {
    final i = revealOrder[slot];
    return i != null && i >= revealCount.value;
  }

  void clearAll({required bool keepPinned}) {
    if (state.assignments.isEmpty) return;
    _snapshot();
    if (keepPinned) {
      state.assignments.removeWhere((slot, _) => !state.pinned.contains(slot));
    } else {
      state.assignments.clear();
      state.pinned.clear();
    }
    _changed();
  }

  // ───────────────────────── 설정 ─────────────────────────

  void setFillMode(FillMode mode) {
    state.fillMode = mode;
    _changed();
  }

  void setNumbering(NumberingOrder order) {
    state.numbering = order;
    _changed();
  }

  void setContinuousNumbering(bool value) {
    state.continuousNumbering = value;
    _changed();
  }

  /// 신발장 크기 · 이름 · 개수를 바꾼다. 남는 칸은 (줄, 칸) 자리를 지켜 옮긴다.
  void updateBanks(List<BankEdit> edits) {
    if (edits.isEmpty) return;
    _snapshot();
    final next = <LockerBank>[];
    final assignments = <SlotKey, String>{};
    final pinned = <SlotKey>{};
    final moved = <SlotKey, SlotKey>{}; // 예전 칸 → 새 칸 (배치 조건의 자리도 따라 옮긴다)
    for (final edit in edits) {
      final old = edit.id == null ? null : bankById(edit.id!);
      final bank = LockerBank(
        id: old?.id ?? _newBankId(next),
        name: edit.name.trim().isEmpty ? '?' : edit.name.trim(),
        cols: edit.cols,
        rows: edit.rows,
      );
      if (old != null) {
        int? remap(int i) {
          final r = i ~/ old.cols, c = i % old.cols;
          return r < bank.rows && c < bank.cols ? r * bank.cols + c : null;
        }

        for (final i in old.disabled) {
          if (remap(i) case final n?) bank.disabled.add(n);
        }
        for (var i = 0; i < old.size; i++) {
          final n = remap(i);
          if (n == null) continue;
          final from = slotKey(old.id, i);
          final to = slotKey(bank.id, n);
          moved[from] = to;
          final member = state.assignments[from];
          if (member == null) continue;
          assignments[to] = member;
          if (state.pinned.contains(from)) pinned.add(to);
        }
      }
      next.add(bank);
    }
    state.banks
      ..clear()
      ..addAll(next);
    state.assignments
      ..clear()
      ..addAll(assignments);
    state.pinned
      ..clear()
      ..addAll(pinned);
    for (final c in state.conditions) {
      final slots = {for (final s in c.slots) ?moved[s]};
      c.slots
        ..clear()
        ..addAll(slots);
    }
    _changed();
  }

  String _newBankId(List<LockerBank> taken) {
    final used = {...state.banks.map((b) => b.id), ...taken.map((b) => b.id)};
    for (var c = 'A'.codeUnitAt(0); c <= 'Z'.codeUnitAt(0); c++) {
      final id = String.fromCharCode(c);
      if (!used.contains(id)) return id;
    }
    return _newId();
  }

  // ───────────────────────── 내보내기 ─────────────────────────

  /// 엑셀에서 바로 열리는 CSV (UTF-8 BOM)
  String toCsv() {
    final b = StringBuffer('﻿신발장,번호,이름,고정\r\n');
    for (final row in _rows()) {
      b.write('${_csv(row.bank)},${row.number},${_csv(row.name)},${row.pinned ? 'O' : ''}\r\n');
    }
    final left = unassignedMembers;
    if (left.isNotEmpty) {
      for (final m in left) {
        b.write('미배치,,${_csv(m.name)},\r\n');
      }
    }
    return b.toString();
  }

  /// 메신저에 붙여넣기 좋은 글 — "A-1 홍길동"
  String toPlainText() {
    final b = StringBuffer();
    String? current;
    for (final row in _rows()) {
      if (row.bank != current) {
        if (current != null) b.writeln();
        b.writeln('[${row.bank} 신발장]');
        current = row.bank;
      }
      b.writeln('${row.number}번  ${row.name}');
    }
    final left = unassignedMembers;
    if (left.isNotEmpty) {
      b
        ..writeln()
        ..writeln('[미배치] ${left.map((m) => m.name).join(', ')}');
    }
    return b.toString().trimRight();
  }

  List<({String bank, int number, String name, bool pinned})> _rows() {
    final rows = <({String bank, int number, String name, bool pinned})>[];
    for (final bank in state.banks) {
      for (final index in _orderedIndexes(bank)) {
        final slot = slotKey(bank.id, index);
        final member = memberById(state.assignments[slot]);
        if (member == null) continue;
        rows.add((
          bank: bank.name,
          number: numberOf(bank, index),
          name: member.name,
          pinned: isPinned(slot),
        ));
      }
    }
    return rows;
  }

  static String _csv(String v) =>
      v.contains(RegExp(r'[",\r\n]')) ? '"${v.replaceAll('"', '""')}"' : v;

  // ───────────────────────── 되돌리기 · 저장 ─────────────────────────

  void undo() {
    if (_undo.isEmpty) return;
    skipReveal();
    state = LockerState.fromJson(jsonDecode(_undo.removeLast()) as Map<String, dynamic>);
    canUndo.value = _undo.isNotEmpty;
    _changed();
  }

  void _snapshot() {
    _undo.add(jsonEncode(state.toJson()));
    if (_undo.length > _undoLimit) _undo.removeAt(0);
    canUndo.value = true;
  }

  void _dropSnapshot() {
    if (_undo.isNotEmpty) _undo.removeLast();
    canUndo.value = _undo.isNotEmpty;
  }

  void _unassignMember(String id) {
    final slot = slotOf(id);
    if (slot == null) return;
    state.assignments.remove(slot);
    state.pinned.remove(slot);
  }

  /// 저장 파일을 손으로 고쳤거나 예전 형식일 때를 대비해 맞지 않는 값을 걷어낸다.
  void _sanitize() {
    final ids = state.members.map((m) => m.id).toSet();
    final seen = <String>{};
    state.assignments.removeWhere((slot, member) {
      if (!ids.contains(member) || !seen.add(member)) return true;
      final (bankId, index) = parseSlotKey(slot);
      final bank = bankById(bankId);
      return bank == null || index >= bank.size || bank.disabled.contains(index);
    });
    state.pinned.retainWhere(state.assignments.containsKey);
    for (final c in state.conditions) {
      c.memberIds.retainWhere(ids.contains);
      c.slots.retainWhere((slot) {
        final (bankId, index) = parseSlotKey(slot);
        final bank = bankById(bankId);
        return bank != null && index < bank.size;
      });
    }
  }

  void _changed() {
    _slotOfMember = null;
    version.value++;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), flush);
  }

  /// 미뤄 둔 저장을 바로 한다 (창을 닫을 때 등)
  Future<void> flush() async {
    _saveTimer?.cancel();
    try {
      await _repository.save(state);
    } catch (e) {
      Get.log('저장 실패: $e', isError: true);
    }
  }

  int _idSeq = 0;
  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${(_idSeq++).toRadixString(36)}';

  @override
  void onClose() {
    _revealTimer?.cancel();
    flush();
    super.onClose();
  }
}
