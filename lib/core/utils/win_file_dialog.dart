import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Windows 기본 열기/저장 대화상자 (comdlg32 의 GetOpenFileNameW · GetSaveFileNameW).
///
/// file_selector 같은 플러그인을 쓰면 Windows 빌드에 심볼릭 링크(개발자 모드)가
/// 필요해진다 — 대화상자 두 개만 쓰니 직접 부른다.
abstract final class WinFileDialog {
  /// 파일 하나를 고른다. 취소하면 null.
  ///
  /// [filters] 는 (설명, 패턴) 쌍 — 예: ('명단 파일', '*.xlsx;*.csv;*.txt')
  static String? open({
    required String title,
    required List<(String, String)> filters,
  }) =>
      _run(title: title, filters: filters, save: false);

  /// 저장할 경로를 고른다. 취소하면 null. 같은 이름이 있으면 덮어쓸지 묻는다.
  static String? save({
    required String title,
    required List<(String, String)> filters,
    required String fileName,
    required String defaultExtension,
  }) =>
      _run(
        title: title,
        filters: filters,
        save: true,
        fileName: fileName,
        defaultExtension: defaultExtension,
      );

  /// 탐색기에서 파일을 선택한 채로 연다.
  static Future<void> reveal(String path) =>
      Process.run('explorer.exe', ['/select,', path]);

  static const _ofnOverwritePrompt = 0x00000002;
  static const _ofnNoChangeDir = 0x00000008;
  static const _ofnPathMustExist = 0x00000800;
  static const _ofnFileMustExist = 0x00001000;
  static const _ofnExplorer = 0x00080000;

  /// 경로 버퍼 길이(글자 수) — MAX_PATH 보다 넉넉하게
  static const _maxPath = 4096;

  static String? _run({
    required String title,
    required List<(String, String)> filters,
    required bool save,
    String fileName = '',
    String defaultExtension = '',
  }) {
    if (!Platform.isWindows) return null;
    return using((arena) {
      _coInitialize();

      // 필터 문자열은 "설명\0패턴\0...\0\0" 형식이다.
      final filter = StringBuffer();
      for (final (label, pattern) in filters) {
        filter
          ..write(label)
          ..write('\u0000')
          ..write(pattern)
          ..write('\u0000');
      }
      filter.write('\u0000');

      final fileBuffer = arena<Uint16>(_maxPath);
      final initial = fileName.codeUnits;
      for (var i = 0; i < initial.length && i < _maxPath - 1; i++) {
        fileBuffer[i] = initial[i];
      }

      final ofn = arena<_OpenFileNameW>();
      ofn.ref
        ..lStructSize = sizeOf<_OpenFileNameW>()
        ..hwndOwner = _getActiveWindow()
        ..lpstrFilter = _utf16(arena, filter.toString())
        ..nFilterIndex = 1
        ..lpstrFile = fileBuffer.cast()
        ..nMaxFile = _maxPath
        ..lpstrTitle = title.toNativeUtf16(allocator: arena)
        ..lpstrDefExt = defaultExtension.isEmpty
            ? nullptr
            : defaultExtension.toNativeUtf16(allocator: arena)
        ..flags = _ofnExplorer |
            _ofnNoChangeDir |
            _ofnPathMustExist |
            (save ? _ofnOverwritePrompt : _ofnFileMustExist);

      final ok = save ? _getSaveFileName(ofn) : _getOpenFileName(ofn);
      if (ok == 0) return null;
      final path = fileBuffer.cast<Utf16>().toDartString();
      return path.isEmpty ? null : path;
    });
  }

  /// '\0' 이 섞인 문자열은 toNativeUtf16 이 중간에서 끊으므로 직접 복사한다.
  static Pointer<Utf16> _utf16(Allocator allocator, String value) {
    final units = Uint16List.fromList([...value.codeUnits, 0]);
    final ptr = allocator<Uint16>(units.length);
    ptr.asTypedList(units.length).setAll(0, units);
    return ptr.cast();
  }

  static final _comdlg32 = DynamicLibrary.open('comdlg32.dll');
  static final _user32 = DynamicLibrary.open('user32.dll');
  static final _ole32 = DynamicLibrary.open('ole32.dll');

  static final _getOpenFileName = _comdlg32.lookupFunction<
      Int32 Function(Pointer<_OpenFileNameW>),
      int Function(Pointer<_OpenFileNameW>)>('GetOpenFileNameW');

  static final _getSaveFileName = _comdlg32.lookupFunction<
      Int32 Function(Pointer<_OpenFileNameW>),
      int Function(Pointer<_OpenFileNameW>)>('GetSaveFileNameW');

  static final _getActiveWindow = _user32
      .lookupFunction<Pointer Function(), Pointer Function()>('GetActiveWindow');

  static final _coInitializeEx = _ole32.lookupFunction<
      Int32 Function(Pointer, Uint32), int Function(Pointer, int)>('CoInitializeEx');

  /// 대화상자는 COM 을 쓴다. 이미 초기화된 스레드면 S_FALSE 가 돌아올 뿐이다.
  static void _coInitialize() => _coInitializeEx(nullptr, 0x2);
}

/// CP949(한국어 Windows 기본) 바이트를 문자열로 — 엑셀이 저장한 CSV 는 보통 이 인코딩이다.
abstract final class WinCodePage {
  static String? decodeCp949(List<int> bytes) {
    if (!Platform.isWindows || bytes.isEmpty) return null;
    return using((arena) {
      final src = arena<Uint8>(bytes.length);
      src.asTypedList(bytes.length).setAll(0, bytes);
      final len = _multiByteToWideChar(949, 0, src, bytes.length, nullptr, 0);
      if (len <= 0) return null;
      final dst = arena<Uint16>(len);
      _multiByteToWideChar(949, 0, src, bytes.length, dst, len);
      return String.fromCharCodes(dst.asTypedList(len));
    });
  }

  static final _multiByteToWideChar = DynamicLibrary.open('kernel32.dll')
      .lookupFunction<
          Int32 Function(Uint32, Uint32, Pointer<Uint8>, Int32, Pointer<Uint16>, Int32),
          int Function(int, int, Pointer<Uint8>, int, Pointer<Uint16>, int)>(
      'MultiByteToWideChar');
}

/// OPENFILENAMEW — https://learn.microsoft.com/windows/win32/api/commdlg/ns-commdlg-openfilenamew
final class _OpenFileNameW extends Struct {
  @Uint32()
  external int lStructSize;
  external Pointer hwndOwner;
  external Pointer hInstance;
  external Pointer<Utf16> lpstrFilter;
  external Pointer<Utf16> lpstrCustomFilter;
  @Uint32()
  external int nMaxCustFilter;
  @Uint32()
  external int nFilterIndex;
  external Pointer<Utf16> lpstrFile;
  @Uint32()
  external int nMaxFile;
  external Pointer<Utf16> lpstrFileTitle;
  @Uint32()
  external int nMaxFileTitle;
  external Pointer<Utf16> lpstrInitialDir;
  external Pointer<Utf16> lpstrTitle;
  @Uint32()
  external int flags;
  @Uint16()
  external int nFileOffset;
  @Uint16()
  external int nFileExtension;
  external Pointer<Utf16> lpstrDefExt;
  @IntPtr()
  external int lCustData;
  external Pointer lpfnHook;
  external Pointer<Utf16> lpTemplateName;
  external Pointer pvReserved;
  @Uint32()
  external int dwReserved;
  @Uint32()
  external int flagsEx;
}
