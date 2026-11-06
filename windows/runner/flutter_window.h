#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>

#include <memory>
#include <string>
#include <vector>

#include "win32_window.h"

// A window that hosts a Flutter view and bridges platform channels.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

  // Handles incoming file paths from CLI, drag-drop or single-instance forwarding.
  void HandleIncomingFiles(const std::vector<std::string>& paths);

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  void SetupMethodChannel();

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Method channel for file opening and sharing
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> open_file_channel_;
  std::vector<std::string> pending_file_paths_;
  bool is_dart_ready_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
