; 신발장 배치기 — Windows 설치기 (Inno Setup 6.3+).
; 빌드 스크립트(build-installer.ps1)가 /DMyAppVersion=1.0.0 /DMyAppBuild=1 로 값을 넘긴다.
; 이 파일은 UTF-8(BOM) 으로 저장해야 한글이 깨지지 않는다.

#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif
#ifndef MyAppBuild
  #define MyAppBuild "0"
#endif
#define MyAppName "신발장 배치기"
#define MyAppExe "random_locker.exe"
#define MyAppPublisher "PICT"
#define FlutterOut "..\build\windows\x64\runner\Release"

[Setup]
; 레지스트리 언인스톨 키 이름이다. 한 번 배포한 뒤 바꾸면 업데이트가 기존 설치를
; 덮어쓰지 않고 두 번째 사본을 만든다 — 영구 고정.
AppId={{6B0F2C0E-3D7A-4F52-9C3B-1E8E5A7D4C21}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
VersionInfoVersion={#MyAppVersion}.{#MyAppBuild}
VersionInfoProductName={#MyAppName}
; 관리자 권한 없이 사용자 프로필 아래에 설치한다. 설치 화면에서 "모든 사용자" 를
; 고르면 그때만 UAC 를 묻는다.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
DefaultDirName={autopf}\PICT\RandomLocker
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\build\installer
OutputBaseFilename=random_locker-setup-{#MyAppVersion}-{#MyAppBuild}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExe}
UninstallDisplayName={#MyAppName}
WizardStyle=modern
WizardImageFile=wizard_large.bmp
WizardSmallImageFile=wizard_small.bmp
Compression=lzma2
SolidCompression=yes
; x64compatible 은 Inno Setup 6.3+ 문법이다.
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; 실행 중인 앱은 닫고 덮어쓴다(업데이트 설치).
CloseApplications=yes
RestartApplications=no

[Languages]
#ifexist "compiler:Languages\Korean.isl"
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"
#else
Name: "english"; MessagesFile: "compiler:Default.isl"
#endif

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#FlutterOut}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExe}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

; 명단 · 배치(%APPDATA%\PICT\random_locker)는 지우지 않는다 — 다시 설치하면 그대로 이어서 쓴다.
