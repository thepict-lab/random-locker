import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:random_locker/core/utils/roster_parser.dart';
import 'package:random_locker/data/models/locker_models.dart';
import 'package:random_locker/data/repository/locker_repository.dart';
import 'package:random_locker/presentation/controller/locker_controller.dart';

void main() {
  late Directory dir;
  late LockerController c;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('random_locker_test');
    c = LockerController(LockerRepository(directory: dir));
    await c.ready;
  });

  tearDown(() async {
    // 미뤄 둔 저장이 끝난 뒤에 지운다.
    c.skipReveal();
    await c.flush();
    await dir.delete(recursive: true);
  });

  test('처음 실행하면 4×7, 5×8 두 세트(68칸)', () {
    expect(c.state.banks.map((b) => (b.cols, b.rows)), [(4, 7), (5, 8)]);
    expect(c.totalSlots, 68);
  });

  test('랜덤 배치는 모든 사람을 서로 다른 칸에 넣는다', () {
    c.addMembers(List.generate(50, (i) => '사람$i'));
    final report = c.shuffle();
    c.skipReveal();
    expect(report.placed, 50);
    expect(report.leftOver, isEmpty);
    expect(c.state.assignments.values.toSet().length, 50);
  });

  test('고정 칸과 사용 안 함 칸은 랜덤 배치에서 지켜진다', () {
    c.addMembers(['가', '나', '다', '라']);
    final ga = c.state.members.first.id;
    c.placeMember(ga, slotKey('B', 39));
    c.togglePin(slotKey('B', 39));
    c.toggleDisabled(slotKey('A', 0));
    for (var i = 0; i < 20; i++) {
      c.shuffle();
      c.skipReveal();
      expect(c.memberAt(slotKey('B', 39)), ga);
      expect(c.memberAt(slotKey('A', 0)), isNull);
    }
  });

  test('칸이 모자라면 남은 사람을 알려 준다', () {
    c.updateBanks([const BankEdit(id: 'A', name: 'A', cols: 2, rows: 2)]);
    c.addMembers(['1번', '2번', '3번', '4번', '5번', '6번']);
    final report = c.shuffle();
    c.skipReveal();
    expect(report.placed, 4);
    expect(report.leftOver.length, 2);
  });

  test('앞 번호부터 채우기', () {
    c.setFillMode(FillMode.sequential);
    c.addMembers(['가', '나', '다']);
    c.shuffle();
    c.skipReveal();
    expect(c.state.assignments.keys.toSet(), {'A:0', 'A:1', 'A:2'});
  });

  test('세로 번호 · 이어 매기기', () {
    final b = c.bankById('B')!;
    c.setNumbering(NumberingOrder.columnMajor);
    c.setContinuousNumbering(true);
    expect(c.numberOf(b, 0), 29); // A 28칸 다음
    expect(c.numberOf(b, 1), 29 + 8); // 오른쪽 칸은 한 줄(세로 8칸) 뒤
  });

  test('크기를 바꿔도 남는 칸의 사람은 자리를 지킨다', () {
    c.addMembers(['가']);
    final id = c.state.members.first.id;
    c.placeMember(id, slotKey('A', 5)); // 2행 2열 (cols 4)
    c.updateBanks([
      const BankEdit(id: 'A', name: 'A', cols: 3, rows: 7),
      const BankEdit(id: 'B', name: 'B', cols: 5, rows: 8),
    ]);
    expect(c.memberAt(slotKey('A', 4)), id); // 2행 2열 (cols 3)
  });

  group('배치 조건', () {
    test('제외한 자리에는 랜덤 배치하지 않는다', () {
      c.addMembers(List.generate(60, (i) => '사람$i'));
      final target = c.state.members.take(3).map((m) => m.id).toSet();
      final bottom = {for (var col = 0; col < 4; col++) slotKey('A', 6 * 4 + col)};
      c.replaceConditions([
        c.newCondition([])
          ..memberIds.addAll(target)
          ..slots.addAll({...bottom, for (var i = 0; i < 40; i++) slotKey('B', i)}),
      ]);
      for (var round = 0; round < 30; round++) {
        final report = c.shuffle();
        c.skipReveal();
        expect(report.placed, 60);
        for (final id in target) {
          final slot = c.slotOf(id)!;
          expect(slot.startsWith('A:'), isTrue);
          expect(bottom.contains(slot), isFalse);
        }
      }
    });

    test('이 자리에만 — 고른 칸 밖으로 나가지 않는다', () {
      c.addMembers(['가', '나', '다', '라', '마']);
      final ga = c.state.members.first.id;
      c.replaceConditions([
        c.newCondition([])
          ..type = ConditionType.only
          ..memberIds.add(ga)
          ..slots.addAll({'B:39', 'B:38'}),
      ]);
      for (var round = 0; round < 20; round++) {
        c.shuffle();
        c.skipReveal();
        expect({'B:39', 'B:38'}.contains(c.slotOf(ga)), isTrue);
      }
    });

    test('칸이 모자라도 조건 있는 사람이 밀려나지 않는다', () {
      c.updateBanks([const BankEdit(id: 'A', name: 'A', cols: 2, rows: 2)]);
      c.addMembers(['가', '나', '다', '라', '마', '바']);
      final ga = c.state.members.first.id;
      c.replaceConditions([
        c.newCondition([])
          ..type = ConditionType.only
          ..memberIds.add(ga)
          ..slots.add('A:3'),
      ]);
      for (var round = 0; round < 20; round++) {
        final report = c.shuffle();
        c.skipReveal();
        expect(c.slotOf(ga), 'A:3');
        expect(report.limitedByConditions, isFalse);
      }
    });

    test('조건 때문에 자리가 없으면 알려 준다', () {
      c.addMembers(['가', '나']);
      final ga = c.state.members.first.id;
      c.replaceConditions([
        c.newCondition([])
          ..type = ConditionType.only
          ..memberIds.add(ga)
          ..slots.add('A:3'),
      ]);
      c.toggleDisabled('A:3');
      final report = c.shuffle();
      c.skipReveal();
      expect(report.leftOver.map((m) => m.id), [ga]);
      expect(report.limitedByConditions, isTrue);
    });

    test('앞 번호부터 + 조건 — 막힌 앞 칸은 건너뛴다', () {
      c.setFillMode(FillMode.sequential);
      c.addMembers(['가', '나', '다']);
      final ids = c.state.members.map((m) => m.id).toSet();
      c.replaceConditions([
        c.newCondition([])
          ..memberIds.addAll(ids)
          ..slots.add('A:0'),
      ]);
      c.shuffle();
      c.skipReveal();
      expect(c.state.assignments.keys.toSet(), {'A:1', 'A:2', 'A:3'});
    });

    test('신발장 크기를 바꾸면 조건의 자리도 따라 옮긴다', () {
      c.replaceConditions([c.newCondition([])..slots.addAll({'A:5', 'A:3'})]);
      c.updateBanks([
        const BankEdit(id: 'A', name: 'A', cols: 3, rows: 7),
        const BankEdit(id: 'B', name: 'B', cols: 5, rows: 8),
      ]);
      // A:5 (2행 2열) → A:4, A:3 (1행 4열) 은 잘려 나간다
      expect(c.state.conditions.single.slots, {'A:4'});
    });

    test('멤버를 지우면 조건에서도 빠진다', () {
      c.addMembers(['가']);
      final ga = c.state.members.first.id;
      c.replaceConditions([c.newCondition([])..memberIds.add(ga)]);
      c.removeMember(ga);
      expect(c.state.conditions.single.memberIds, isEmpty);
    });
  });

  test('되돌리기', () {
    c.addMembers(['가', '나']);
    c.shuffle();
    c.skipReveal();
    c.undo();
    expect(c.state.assignments, isEmpty);
  });

  test('저장 후 다시 읽기', () async {
    c.addMembers(['가', '나']);
    c.shuffle();
    c.skipReveal();
    await c.flush();
    final again = LockerController(LockerRepository(directory: dir));
    await again.ready;
    expect(again.state.members.map((m) => m.name), ['가', '나']);
    expect(again.state.assignments, c.state.assignments);
  });

  group('명단 해석', () {
    test('머리글이 있는 표에서 이름 열만 읽는다', () {
      const csv = '번호\t이름\t이메일\n1\t홍길동\thong@pict.kr\n2\t김철수 (디자인팀)\tkim@pict.kr';
      expect(RosterParser.fromText(csv), ['홍길동', '김철수']);
    });

    test('머리글이 없으면 이메일 · 번호가 아닌 첫 칸', () {
      const text = 'lee@pict.kr, 이영희\n010-1234-5678, 박민수\n\n이영희';
      expect(RosterParser.fromText(text), ['이영희', '박민수']);
    });

    test('괄호 유지 옵션', () {
      expect(RosterParser.fromText('홍길동 (개발팀)', stripBrackets: false), ['홍길동 (개발팀)']);
    });

    test('따옴표 CSV', () {
      final bytes = utf8.encode('﻿이름,메모\r\n"홍, 길동","a"\r\n김철수,b\r\n');
      expect(RosterParser.fromFile('a.csv', bytes), ['홍, 길동', '김철수']);
    });
  });
}
