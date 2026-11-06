#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shellapi.h>

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

  std::vector<std::string> command_line_arguments = GetCommandLineArguments();

  // Check for single instance
  const wchar_t kMutexName[] = L"Folio_PDF_Reader_Single_Instance_Mutex";
  HANDLE hMutex = ::CreateMutexW(nullptr, TRUE, kMutexName);
  bool already_running = (::GetLastError() == ERROR_ALREADY_EXISTS);

  if (already_running) {
    HWND existing_hwnd = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"Folio - Modern PDF Reader");
    if (!existing_hwnd) {
      existing_hwnd = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", nullptr);
    }

    if (existing_hwnd) {
      std::wstring payload;
      for (const auto& arg : command_line_arguments) {
        if (!payload.empty()) payload += L"\n";
        payload += Utf16FromUtf8(arg);
      }

      if (!payload.empty()) {
        COPYDATASTRUCT cds;
        cds.dwData = 0x464F4C49; // 'FOLI'
        cds.cbData = static_cast<DWORD>((payload.length() + 1) * sizeof(wchar_t));
        cds.lpData = const_cast<wchar_t*>(payload.c_str());
        ::SendMessageW(existing_hwnd, WM_COPYDATA, 0, reinterpret_cast<LPARAM>(&cds));
      }

      if (::IsIconic(existing_hwnd)) {
        ::ShowWindow(existing_hwnd, SW_RESTORE);
      }
      ::SetForegroundWindow(existing_hwnd);
    }

    if (hMutex) {
      ::CloseHandle(hMutex);
    }
    ::CoUninitialize();
    return EXIT_SUCCESS;
  }

  flutter::DartProject project(L"data");

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Folio - Modern PDF Reader", origin, size)) {
    if (hMutex) ::CloseHandle(hMutex);
    ::CoUninitialize();
    return EXIT_FAILURE;
  }

  // Populate initial command line files for getInitialFiles
  int argc = 0;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv != nullptr) {
    std::vector<std::string> initial_files;
    for (int i = 1; i < argc; i++) {
      std::wstring warg(argv[i]);
      if (warg.length() >= 2 && warg.front() == L'"' && warg.back() == L'"') {
        warg = warg.substr(1, warg.length() - 2);
      }
      if (!warg.empty()) {
        initial_files.push_back(Utf8FromUtf16(warg.c_str()));
      }
    }
    ::LocalFree(argv);
    if (!initial_files.empty()) {
      window.HandleIncomingFiles(initial_files);
    }
  }

  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  if (hMutex) {
    ::CloseHandle(hMutex);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
