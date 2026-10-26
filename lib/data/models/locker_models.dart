/// 등록된 사람
class Member {
  Member({required this.id, required this.name, this.excluded = false});

  final String id;
  String name;

  /// 배치에서 뺀다 (휴가 · 외근 등) — 목록에는 남는다
  bool excluded;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'excluded': excluded};

  factory Member.fromJson(Map<String, dynamic> json) => Member(
        id: json['id'] as String,
        name: json['name'] as String,
        excluded: json['excluded'] as bool? ?? false,
      );
}

/// 신발장 한 세트. 칸 번호(index)는 왼쪽 위에서부터 가로로 0, 1, 2 …
class LockerBank {
  LockerBank({
    required this.id,
    required this.name,
    required this.cols,
    required this.rows,
    Set<int>? disabled,
  }) : disabled = disabled ?? <int>{};

  final String id;
  String name;
  int cols;
  int rows;

  /// 쓰지 않는 칸 (고장 · 공용 등)
  final Set<int> disabled;

  int get size => cols * rows;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'cols': cols,
        'rows': rows,
        'disabled': disabled.toList()..sort(),
      };

  factory LockerBank.fromJson(Map<String, dynamic> json) => LockerBank(
        id: json['id'] as String,
        name: json['name'] as String,
        cols: json['cols'] as int,
        rows: json['rows'] as int,
        disabled: {...(json['disabled'] as List? ?? const []).cast<int>()},
      );
}

/// 칸 위치. 저장할 때는 "bankId:index" 문자열로 쓴다.
typedef SlotKey = String;

SlotKey slotKey(String bankId, int index) => '$bankId:$index';

(String bankId, int index) parseSlotKey(SlotKey key) {
  final i = key.lastIndexOf(':');
  return (key.substring(0, i), int.parse(key.substring(i + 1)));
}

/// 빈 칸을 고르는 방식
enum FillMode {
  /// 남는 칸이 신발장 곳곳에 흩어진다
  scatter('전체 무작위'),

  /// 앞 번호부터 차례로 채우고, 사람만 섞는다
  sequential('앞 번호부터');

  const FillMode(this.label);
  final String label;
}

/// 칸 번호를 매기는 방향
enum NumberingOrder {
  rowMajor('가로 방향 (→)'),
  columnMajor('세로 방향 (↓)');

  const NumberingOrder(this.label);
  final String label;
}

/// 앱 전체 상태 — %APPDATA% 의 state.json 하나에 통째로 저장한다.
class LockerState {
  LockerState({
    required this.members,
    required this.banks,
    required this.assignments,
    required this.pinned,
    this.fillMode = FillMode.scatter,
    this.numbering = NumberingOrder.rowMajor,
    this.continuousNumbering = false,
    this.lastShuffledAt,
  });

  final List<Member> members;
  final List<LockerBank> banks;

  /// 칸 → 사람 id
  final Map<SlotKey, String> assignments;

  /// 랜덤 배치 때 그대로 두는 칸
  final Set<SlotKey> pinned;

  FillMode fillMode;
  NumberingOrder numbering;

  /// 두 번째 신발장 번호를 첫 번째 다음 번호부터 이어서 매긴다
  bool continuousNumbering;

  DateTime? lastShuffledAt;

  /// 처음 실행 — 가로 4 × 세로 7, 가로 5 × 세로 8 두 세트
  factory LockerState.initial() => LockerState(
        members: [],
        banks: [
          LockerBank(id: 'A', name: 'A', cols: 4, rows: 7),
          LockerBank(id: 'B', name: 'B', cols: 5, rows: 8),
        ],
        assignments: {},
        pinned: {},
      );

  Map<String, dynamic> toJson() => {
        'version': 1,
        'members': members.map((m) => m.toJson()).toList(),
        'banks': banks.map((b) => b.toJson()).toList(),
        'assignments': assignments,
        'pinned': pinned.toList(),
        'fillMode': fillMode.name,
        'numbering': numbering.name,
        'continuousNumbering': continuousNumbering,
        'lastShuffledAt': lastShuffledAt?.toIso8601String(),
      };

  factory LockerState.fromJson(Map<String, dynamic> json) => LockerState(
        members: [
          for (final m in json['members'] as List? ?? const [])
            Member.fromJson((m as Map).cast<String, dynamic>()),
        ],
        banks: [
          for (final b in json['banks'] as List? ?? const [])
            LockerBank.fromJson((b as Map).cast<String, dynamic>()),
        ],
        assignments:
            (json['assignments'] as Map? ?? const {}).cast<String, String>(),
        pinned: {...(json['pinned'] as List? ?? const []).cast<String>()},
        fillMode: FillMode.values.asNameMap()[json['fillMode']] ?? FillMode.scatter,
        numbering: NumberingOrder.values.asNameMap()[json['numbering']] ??
            NumberingOrder.rowMajor,
        continuousNumbering: json['continuousNumbering'] as bool? ?? false,
        lastShuffledAt: DateTime.tryParse(json['lastShuffledAt'] as String? ?? ''),
      );
}
