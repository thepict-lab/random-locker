import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/locker_models.dart';

/// 상태를 %APPDATA%\PICT\random_locker\state.json 에 둔다.
///
/// 설치 폴더가 아니라 사용자 프로필에 두는 이유: 앱을 다시 설치하거나 지워도
/// 명단과 배치가 남아야 한다. 쓰기는 임시 파일에 쓴 뒤 바꿔치기해서, 저장 도중
/// 꺼져도 이전 파일이 깨지지 않는다.
class LockerRepository {
  LockerRepository({Directory? directory}) : _dirOverride = directory;

  final Directory? _dirOverride;

  Directory get directory {
    if (_dirOverride != null) return _dirOverride;
    final base = Platform.environment['APPDATA'] ??
        Platform.environment['LOCALAPPDATA'] ??
        Directory.systemTemp.path;
    return Directory('$base${Platform.pathSeparator}PICT${Platform.pathSeparator}random_locker');
  }

  File get _file => File('${directory.path}${Platform.pathSeparator}state.json');

  Future<LockerState> load() async {
    try {
      final file = _file;
      if (!await file.exists()) return LockerState.initial();
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final state = LockerState.fromJson(json);
      return state.banks.isEmpty ? LockerState.initial() : state;
    } catch (e) {
      // 깨진 파일은 옆에 남겨 두고 처음 상태로 시작한다.
      debugPrint('state.json 읽기 실패: $e');
      try {
        await _file.copy('${_file.path}.broken');
      } catch (_) {}
      return LockerState.initial();
    }
  }

  Future<void> save(LockerState state) async {
    await directory.create(recursive: true);
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(state.toJson()),
      flush: true,
    );
    await tmp.rename(_file.path);
  }
}
