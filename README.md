# 신발장 배치기 (random_locker)

사람을 등록하고 신발장 칸에 랜덤으로 배치하는 Windows 데스크톱 앱입니다.
기본 구성은 **A 신발장(가로 4 × 세로 7, 28칸)** 과 **B 신발장(가로 5 × 세로 8, 40칸)** 두 세트입니다.

## 기능

- **멤버 등록** — 이름 입력 후 Enter (쉼표로 여러 명), 이름 변경 · 삭제 · 배치 제외(휴가 · 외근)
- **명단 가져오기** — 잔디 등에서 복사한 목록 붙여넣기, 엑셀(.xlsx) · CSV · 텍스트 파일
  - "이름" 열을 자동으로 찾고 이메일 · 전화번호 칸은 걸러 냅니다
  - "홍길동 (개발팀)" 처럼 괄호 안 부서 · 직함은 빼고 등록(옵션)
  - 한국어 엑셀이 저장한 CP949 CSV 도 읽습니다
- **랜덤 배치** (F5 / Ctrl+Enter) — 칸이 하나씩 열리는 연출, 칸이 모자라면 남은 사람을 알려 줌
- **칸 메뉴** (칸 클릭) — 사람 지정, 고정(랜덤 배치에서 제외), 비우기, 사용 안 함(고장 · 공용)
- **끌어다 놓기** — 목록의 이름을 칸으로, 칸끼리는 맞바꾸기
- **되돌리기** (Ctrl+Z) — 최근 30단계
- **내보내기** — 배치표 이미지(PNG), 엑셀용 CSV, 메신저 공유용 글 복사
- **신발장 설정** — 세트 이름 · 가로 · 세로 · 개수, 빈 칸 남기는 방식(전체 무작위 / 앞 번호부터),
  번호 방향(가로 / 세로), 번호 이어 매기기
- 명단과 배치는 `%APPDATA%\PICT\random_locker\state.json` 에 자동 저장됩니다
  (앱을 지우거나 다시 설치해도 남습니다)

### 잔디 연동에 대해

잔디는 팀 멤버 목록을 조회하는 공개 API 를 제공하지 않습니다(웹훅은 메시지 보내기 전용).
그래서 직접 연동 대신, 잔디에서 복사한 명단이나 내려받은 엑셀 파일을 붙여넣으면
이름만 골라 등록하도록 했습니다. 배치 결과는 **내보내기 → 글로 복사** 로 잔디 토픽에 바로 붙여넣을 수 있습니다.

## 개발

Flutter 3.44 (Dart 3.12) · GetX. 아이콘과 스플래시는 PICTLAB PMS 의 PICT. 로고를 씁니다.

```bash
flutter run -d windows
```

```bash
flutter test
```

네이티브 플러그인을 쓰지 않습니다. Windows 는 플러그인이 하나라도 있으면 빌드에 개발자 모드
(심볼릭 링크)가 필요해서, 파일 대화상자는 `dart:ffi` 로 comdlg32 를 직접 부릅니다
(`lib/core/utils/win_file_dialog.dart`).

앱 아이콘을 바꾸려면 `assets/icon/app_icon.png` 를 교체하고:

```bash
dart run flutter_launcher_icons
```

## 설치 파일 만들기

[Inno Setup 6.3+](https://jrsoftware.org/isinfo.php) 가 필요합니다 (`winget install JRSoftware.InnoSetup --scope user`).

```bash
powershell -ExecutionPolicy Bypass -File installer/build-installer.ps1
```

- `pubspec.yaml` 의 `version: x.y.z+N` 을 읽어 빌드합니다
- 산출물: `build\installer\random_locker-setup-<버전>-<빌드>.exe`, 보관본은 `releases\`
- 관리자 권한 없이 사용자 계정에 설치됩니다(설치 화면에서 "모든 사용자" 선택 시에만 UAC)
- 설치 파일은 코드 서명이 되어 있지 않아, 처음 실행할 때 Windows SmartScreen 경고
  ("추가 정보 → 실행")가 뜰 수 있고, **스마트 앱 컨트롤**이 켜진 PC 에서는 실행이 차단됩니다
