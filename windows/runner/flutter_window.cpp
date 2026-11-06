#include "flutter_window.h"

#include <optional>
#include <shellapi.h>
#include <shlobj.h>

#include "flutter/generated_plugin_registrant.h"
#include "utils.h"

namespace {

bool CopyFileToClipboard(const std::wstring& path) {
  if (!::OpenClipboard(nullptr)) return false;
  ::EmptyClipboard();

  SIZE_T size = sizeof(DROPFILES) + (path.length() + 2) * sizeof(wchar_t);
  HGLOBAL hGlobal = ::GlobalAlloc(GMEM_MOVEABLE, size);
  if (!hGlobal) {
    ::CloseClipboard();
    return false;
  }

  DROPFILES* df = static_cast<DROPFILES*>(::GlobalLock(hGlobal));
  if (!df) {
    ::GlobalFree(hGlobal);
    ::CloseClipboard();
    return false;
  }
  df->pFiles = sizeof(DROPFILES);
  df->fWide = TRUE;
  wchar_t* file_dest = reinterpret_cast<wchar_t*>(reinterpret_cast<BYTE*>(df) + sizeof(DROPFILES));
  wcscpy_s(file_dest, path.length() + 1, path.c_str());
  file_dest[path.length() + 1] = L'\0'; // Double null-terminated
  ::GlobalUnlock(hGlobal);

  ::SetClipboardData(CF_HDROP, hGlobal);
  ::CloseClipboard();
  return true;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

void FlutterWindow::SetupMethodChannel() {
  if (!flutter_controller_ || !flutter_controller_->engine()) return;

  open_file_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "folio/open_file",
      &flutter::StandardMethodCodec::GetInstance());

  open_file_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "getInitialFiles") {
          is_dart_ready_ = true;
          flutter::EncodableList files;
          for (const auto& path : pending_file_paths_) {
            files.push_back(flutter::EncodableValue(path));
          }
          pending_file_paths_.clear();
          result->Success(flutter::EncodableValue(files));
        } else if (call.method_name() == "shareFile") {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (!args) {
            result->Error("INVALID_ARGS", "Expected argument map");
            return;
          }
          auto path_it = args->find(flutter::EncodableValue("path"));
          if (path_it == args->end() || !std::holds_alternative<std::string>(path_it->second)) {
            result->Error("INVALID_ARGS", "Missing 'path' argument");
            return;
          }

          std::string path_utf8 = std::get<std::string>(path_it->second);
          std::wstring path_utf16 = Utf16FromUtf8(path_utf8);

          // Copy to clipboard as real file drop (CF_HDROP)
          CopyFileToClipboard(path_utf16);

          // Highlight/select file in Windows Explorer
          std::wstring explorer_args = L"/select,\"" + path_utf16 + L"\"";
          ::ShellExecuteW(nullptr, L"open", L"explorer.exe", explorer_args.c_str(), nullptr, SW_SHOWNORMAL);

          result->Success(flutter::EncodableValue(true));
        } else {
          result->NotImplemented();
        }
      });
}

void FlutterWindow::HandleIncomingFiles(const std::vector<std::string>& paths) {
  std::vector<std::string> valid_paths;
  for (const auto& p : paths) {
    if (!p.empty()) {
      valid_paths.push_back(p);
    }
  }
  if (valid_paths.empty()) return;

  if (is_dart_ready_ && open_file_channel_) {
    flutter::EncodableList list;
    for (const auto& p : valid_paths) {
      list.push_back(flutter::EncodableValue(p));
    }
    open_file_channel_->InvokeMethod(
        "onOpenFiles",
        std::make_unique<flutter::EncodableValue>(list));
  } else {
    pending_file_paths_.insert(pending_file_paths_.end(),
                               valid_paths.begin(), valid_paths.end());
  }
}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  SetupMethodChannel();

  // Accept file drag & drops from Windows Explorer
  ::DragAcceptFiles(GetHandle(), TRUE);

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;

    case WM_DROPFILES: {
      HDROP hDrop = reinterpret_cast<HDROP>(wparam);
      UINT file_count = ::DragQueryFileW(hDrop, 0xFFFFFFFF, nullptr, 0);
      std::vector<std::string> paths;
      for (UINT i = 0; i < file_count; ++i) {
        wchar_t buf[MAX_PATH];
        if (::DragQueryFileW(hDrop, i, buf, MAX_PATH)) {
          paths.push_back(Utf8FromUtf16(buf));
        }
      }
      ::DragFinish(hDrop);
      if (!paths.empty()) {
        HandleIncomingFiles(paths);
      }
      return 0;
    }

    case WM_COPYDATA: {
      PCOPYDATASTRUCT pcds = reinterpret_cast<PCOPYDATASTRUCT>(lparam);
      if (pcds && pcds->dwData == 0x464F4C49) {
        const wchar_t* wdata = reinterpret_cast<const wchar_t*>(pcds->lpData);
        if (wdata) {
          std::wstring data_str(wdata);
          std::vector<std::string> paths;
          size_t start = 0;
          while (start < data_str.length()) {
            size_t end = data_str.find(L'\n', start);
            if (end == std::wstring::npos) {
              end = data_str.length();
            }
            std::wstring item = data_str.substr(start, end - start);
            if (!item.empty()) {
              paths.push_back(Utf8FromUtf16(item.c_str()));
            }
            start = end + 1;
          }
          HandleIncomingFiles(paths);
          return TRUE;
        }
      }
      break;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
