import 'default_roster.dart';

/// 등록된 사람
class Member {
  Member({required this.id, required this.name, this.excluded = false, this.teamId});

  final String id;
  String name;

  /// 배치에서 뺀다 (휴가 · 외근 등) — 목록에는 남는다
  bool excluded;

  /// 소속 팀 — 없으면 null
  String? teamId;

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'excluded': excluded, 'team': ?teamId};

  factory Member.fromJson(Map<String, dynamic> json) => Member(
        id: json['id'] as String,
        name: json['name'] as String,
        excluded: json['excluded'] as bool? ?? false,
        teamId: json['team'] as String?,
      );
}

/// 팀 — 팀장이 추첨에 나가 영역을 고른다. 소속은 멤버의 [Member.teamId] 로 정한다.
class Team {
  Team({required this.id, required this.name, required this.color, this.leaderId});

  final String id;
  String name;

  /// [AppColors.team] 의 번호
  int color;

  String? leaderId;

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'color': color, 'leader': ?leaderId};

  factory Team.fromJson(Map<String, dynamic> json) => Team(
        id: json['id'] as String,
        name: json['name'] as String? ?? '팀',
        color: json['color'] as int? ?? 0,
        leaderId: json['leader'] as String?,
      );
}

/// 영역 — 미리 묶어 둔 칸들. 추첨 순위대로 팀이 하나씩 가져간다.
class LockerArea {
  LockerArea({
    required this.id,
    required this.name,
    required this.color,
    Set<SlotKey>? slots,
    this.teamId,
  }) : slots = slots ?? <SlotKey>{};

  final String id;
  String name;
  int color;
  final Set<SlotKey> slots;

  /// 이 영역을 가져간 팀
  String? teamId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'slots': slots.toList(),
        'team': ?teamId,
      };

  factory LockerArea.fromJson(Map<String, dynamic> json) => LockerArea(
        id: json['id'] as String,
        name: json['name'] as String? ?? '영역',
        color: json['color'] as int? ?? 0,
        slots: {...(json['slots'] as List? ?? const []).cast<String>()},
        teamId: json['team'] as String?,
      );

  LockerArea copy() =>
      LockerArea(id: id, name: name, color: color, slots: {...slots}, teamId: teamId);
}

/// 팀장 추첨 한 판 — 본선이거나, 동점 팀끼리의 재대결
class DrawRound {
  DrawRound({required this.teamIds, Map<String, List<int>>? picks, this.loadOrder, List<int>? drawn})
      : picks = picks ?? {},
        drawn = drawn ?? [];

  /// 이 판에 나간 팀 (숫자를 고르는 순서)
  final List<String> teamIds;

  /// 팀 → 고른 숫자 5개
  final Map<String, List<int>> picks;

  /// 추첨기에 구슬을 넣은 순서 (구슬 번호). 이 순서가 시드라 같은 순서면 같은 결과가 나온다.
  List<int>? loadOrder;

  /// 나온 숫자 (나온 순서대로)
  final List<int> drawn;

  Map<String, dynamic> toJson() => {
        'teams': teamIds,
        'picks': picks,
        'loadOrder': ?loadOrder,
        'drawn': drawn,
      };

  factory DrawRound.fromJson(Map<String, dynamic> json) => DrawRound(
        teamIds: (json['teams'] as List? ?? const []).cast<String>(),
        picks: {
          for (final e in (json['picks'] as Map? ?? const {}).entries)
            e.key as String: (e.value as List).cast<int>(),
        },
        loadOrder: (json['loadOrder'] as List?)?.cast<int>(),
        drawn: (json['drawn'] as List? ?? const []).cast<int>(),
      );
}

/// 팀장 추첨 기록 — 본선과 재대결 판들, 그리고 지금까지의 순위
class DrawRecord {
  DrawRecord({
    required this.teamIds,
    List<DrawRound>? rounds,
    List<List<String>>? standings,
    DateTime? at,
  })  : rounds = rounds ?? [],
        standings = standings ?? [],
        at = at ?? DateTime.now();

  /// 추첨에 나간 팀
  final List<String> teamIds;

  /// 판 — 첫 판이 본선, 그 뒤는 재대결
  final List<DrawRound> rounds;

  /// 순위 묶음 (위에서부터). 둘 이상인 묶음은 아직 재대결이 남은 동점.
  /// 본선이 끝나기 전에는 비어 있다.
  final List<List<String>> standings;

  final DateTime at;

  Map<String, dynamic> toJson() => {
        'teams': teamIds,
        'rounds': rounds.map((r) => r.toJson()).toList(),
        'standings': standings,
        'at': at.toIso8601String(),
      };

  factory DrawRecord.fromJson(Map<String, dynamic> json) => DrawRecord(
        teamIds: (json['teams'] as List? ?? const []).cast<String>(),
        rounds: [
          for (final r in json['rounds'] as List? ?? const [])
            DrawRound.fromJson((r as Map).cast<String, dynamic>()),
        ],
        standings: [
          for (final g in json['standings'] as List? ?? const []) (g as List).cast<String>(),
        ],
        at: DateTime.tryParse(json['at'] as String? ?? ''),
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

/// 배치 조건의 종류
enum ConditionType {
  /// 대상 멤버는 고른 자리에 배치하지 않는다
  exclude('이 자리 제외'),

  /// 대상 멤버는 고른 자리 중에서만 배치한다
  only('이 자리에만');

  const ConditionType(this.label);
  final String label;
}

/// 배치 조건 — "이 사람들은 이 자리를 빼고(또는 이 자리에만) 돌린다".
/// 랜덤 배치에만 적용한다. 고정한 칸과 손으로 놓은 배치는 그대로 두되 화면에 표시한다.
class LockerCondition {
  LockerCondition({
    required this.id,
    required this.name,
    this.type = ConditionType.exclude,
    this.enabled = true,
    Set<String>? memberIds,
    Set<SlotKey>? slots,
  })  : memberIds = memberIds ?? <String>{},
        slots = slots ?? <SlotKey>{};

  final String id;
  String name;
  ConditionType type;
  bool enabled;
  final Set<String> memberIds;
  final Set<SlotKey> slots;

  /// 이 조건이 [memberId] 를 [slot] 에 두는 것을 막는가
  bool forbids(String memberId, SlotKey slot) {
    if (!enabled || !memberIds.contains(memberId)) return false;
    return switch (type) {
      ConditionType.exclude => slots.contains(slot),
      ConditionType.only => !slots.contains(slot),
    };
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'enabled': enabled,
        'members': memberIds.toList(),
        'slots': slots.toList(),
      };

  factory LockerCondition.fromJson(Map<String, dynamic> json) => LockerCondition(
        id: json['id'] as String,
        name: json['name'] as String? ?? '조건',
        type: ConditionType.values.asNameMap()[json['type']] ?? ConditionType.exclude,
        enabled: json['enabled'] as bool? ?? true,
        memberIds: {...(json['members'] as List? ?? const []).cast<String>()},
        slots: {...(json['slots'] as List? ?? const []).cast<String>()},
      );

  LockerCondition copy() => LockerCondition(
        id: id,
        name: name,
        type: type,
        enabled: enabled,
        memberIds: {...memberIds},
        slots: {...slots},
      );
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
    List<LockerCondition>? conditions,
    List<Team>? teams,
    List<LockerArea>? areas,
    this.draw,
    this.fillMode = FillMode.scatter,
    this.numbering = NumberingOrder.rowMajor,
    this.continuousNumbering = false,
    this.lastShuffledAt,
  })  : conditions = conditions ?? [],
        teams = teams ?? [],
        areas = areas ?? [];

  final List<Member> members;
  final List<LockerBank> banks;
  final List<Team> teams;
  final List<LockerArea> areas;

  /// 가장 최근 팀장 추첨 (진행 중이거나 끝난 것)
  DrawRecord? draw;

  /// 칸 → 사람 id
  final Map<SlotKey, String> assignments;

  /// 랜덤 배치 때 그대로 두는 칸
  final Set<SlotKey> pinned;

  /// 랜덤 배치 조건
  final List<LockerCondition> conditions;

  FillMode fillMode;
  NumberingOrder numbering;

  /// 두 번째 신발장 번호를 첫 번째 다음 번호부터 이어서 매긴다
  bool continuousNumbering;

  DateTime? lastShuffledAt;

  /// 처음 실행 — 가로 4 × 세로 7, 가로 5 × 세로 7 두 세트, 페인터 구성원 명단
  factory LockerState.initial() => LockerState(
        members: [
          for (var i = 0; i < defaultRoster.length; i++)
            Member(id: 'p${i + 1}', name: defaultRoster[i]),
        ],
        banks: [
          LockerBank(id: 'A', name: 'A', cols: 4, rows: 7),
          LockerBank(id: 'B', name: 'B', cols: 5, rows: 7),
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
        'conditions': conditions.map((c) => c.toJson()).toList(),
        'teams': teams.map((t) => t.toJson()).toList(),
        'areas': areas.map((a) => a.toJson()).toList(),
        'draw': draw?.toJson(),
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
        conditions: [
          for (final c in json['conditions'] as List? ?? const [])
            LockerCondition.fromJson((c as Map).cast<String, dynamic>()),
        ],
        teams: [
          for (final t in json['teams'] as List? ?? const [])
            Team.fromJson((t as Map).cast<String, dynamic>()),
        ],
        areas: [
          for (final a in json['areas'] as List? ?? const [])
            LockerArea.fromJson((a as Map).cast<String, dynamic>()),
        ],
        draw: json['draw'] is Map
            ? DrawRecord.fromJson((json['draw'] as Map).cast<String, dynamic>())
            : null,
        fillMode: FillMode.values.asNameMap()[json['fillMode']] ?? FillMode.scatter,
        numbering: NumberingOrder.values.asNameMap()[json['numbering']] ??
            NumberingOrder.rowMajor,
        continuousNumbering: json['continuousNumbering'] as bool? ?? false,
        lastShuffledAt: DateTime.tryParse(json['lastShuffledAt'] as String? ?? ''),
      );
}
