# Windows 설치기 빌드 — pubspec.yaml 의 version 을 읽어 flutter build → ISCC.
# 산출물: build\installer\random_locker-setup-<version>-<build>.exe
# 사용: .\installer\build-installer.ps1        (또는 -SkipFlutterBuild 로 설치기만)
param([switch]$SkipFlutterBuild)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$line = (Get-Content pubspec.yaml | Where-Object { $_ -match '^version:\s*' } | Select-Object -First 1)
if (-not $line) { throw 'pubspec.yaml 에 version 이 없습니다' }
$full = ($line -replace '^version:\s*', '').Trim()
if ($full -notmatch '^(\d+\.\d+\.\d+)\+(\d+)$') { throw "version 은 x.y.z+N 형식이어야 합니다: $full" }
$version = $Matches[1]; $build = $Matches[2]
Write-Host "버전 $version (build $build)"

if (-not $SkipFlutterBuild) {
  flutter build windows --release
  if ($LASTEXITCODE -ne 0) { throw 'flutter build windows 실패' }
}

# -SkipFlutterBuild 로 pubspec 만 올리고 다시 빌드하지 않으면 예전 exe 가 새 버전 이름으로 나간다.
$exe = 'build\windows\x64\runner\Release\random_locker.exe'
if (-not (Test-Path $exe)) { throw "Release 빌드가 없습니다: $exe — -SkipFlutterBuild 를 빼고 실행하세요" }
$exeVer = [string](Get-Item $exe).VersionInfo.ProductVersion
if ($exeVer -and $exeVer -ne $full) {
  throw "Release 실행 파일은 $exeVer 인데 pubspec 은 $full 입니다 — -SkipFlutterBuild 를 빼고 다시 빌드하세요"
}

# ISCC 위치: PATH → 모든 사용자 설치 → 현재 사용자 설치(winget --scope user)
$iscc = (Get-Command iscc -ErrorAction SilentlyContinue).Source
foreach ($candidate in @(
  'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
  'C:\Program Files\Inno Setup 6\ISCC.exe',
  "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
)) {
  if (-not $iscc -and (Test-Path $candidate)) { $iscc = $candidate }
}
if (-not $iscc) { throw 'Inno Setup 6 이 없습니다: winget install JRSoftware.InnoSetup' }

& $iscc "/DMyAppVersion=$version" "/DMyAppBuild=$build" "installer\random_locker.iss"
if ($LASTEXITCODE -ne 0) { throw 'ISCC 실패' }

$out = "build\installer\random_locker-setup-$version-$build.exe"
$sha = (Get-FileHash $out -Algorithm SHA256).Hash.ToLower()
Write-Host "완료: $out"
Write-Host "sha256: $sha"
# build\ 는 flutter clean 이 지운다 — 배포본은 releases\ 에 따로 둔다(git 은 무시한다).
$keep = "releases\$version-$build"
New-Item -ItemType Directory -Force $keep | Out-Null
Copy-Item $out $keep -Force
Set-Content -Path "$keep\SHA256.txt" -Value "$sha  random_locker-setup-$version-$build.exe" -Encoding ascii
Write-Host "보관: $keep"
