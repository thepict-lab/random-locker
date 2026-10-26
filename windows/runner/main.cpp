#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter_windows.h>
#include <windows.h>

#include <algorithm>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  // 주 모니터 작업 영역 가운데에 1440×900(논리 픽셀)으로 띄운다.
  // 화면이 작으면 작업 영역의 92% 로 줄인다.
  RECT work_area{};
  ::SystemParametersInfo(SPI_GETWORKAREA, 0, &work_area, 0);
  HMONITOR primary = ::MonitorFromPoint(POINT{0, 0}, MONITOR_DEFAULTTOPRIMARY);
  double scale = FlutterDesktopGetDpiForMonitor(primary) / 96.0;
  double work_w = (work_area.right - work_area.left) / scale;
  double work_h = (work_area.bottom - work_area.top) / scale;
  unsigned int width = static_cast<unsigned int>((std::min)(1440.0, work_w * 0.92));
  unsigned int height = static_cast<unsigned int>((std::min)(900.0, work_h * 0.92));
  Win32Window::Point origin(
      static_cast<unsigned int>(work_area.left / scale + (work_w - width) / 2),
      static_cast<unsigned int>(work_area.top / scale + (work_h - height) / 2));
  Win32Window::Size size(width, height);

  FlutterWindow window(project);
  // "신발장 배치기" — 소스 인코딩에 흔들리지 않게 유니코드 이스케이프로 적는다.
  if (!window.Create(L"\uC2E0\uBC1C\uC7A5 \uBC30\uCE58\uAE30", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
