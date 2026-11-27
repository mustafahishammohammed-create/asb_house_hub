#include "flutter_window.h"

#include <commctrl.h>
#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {

// Firebase Windows plugins (such as firebase_auth and firebase_storage) post
// WM_APP+ dispatch messages to the child FlutterView HWND while listening via
// RegisterTopLevelWindowProcDelegate (which is only pumped for the parent
// top-level HWND). Forward WM_APP plugin messages so async Futures always resolve.
LRESULT CALLBACK ViewPluginMessageSubclassProc(HWND hwnd,
                                               UINT message,
                                               WPARAM wparam,
                                               LPARAM lparam,
                                               UINT_PTR subclass_id,
                                               DWORD_PTR ref_data) {
  if (message >= WM_APP && message <= 0xBFFF) {
    auto* controller =
        reinterpret_cast<flutter::FlutterViewController*>(ref_data);
    HWND parent = GetParent(hwnd);
    if (controller != nullptr && parent != nullptr) {
      std::optional<LRESULT> result =
          controller->HandleTopLevelWindowProc(parent, message, wparam, lparam);
      if (result) {
        return *result;
      }
    }
  }
  if (message == WM_NCDESTROY) {
    RemoveWindowSubclass(hwnd, ViewPluginMessageSubclassProc, subclass_id);
  }
  return DefSubclassProc(hwnd, message, wparam, lparam);
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  HWND view_hwnd = flutter_controller_->view()->GetNativeWindow();
  SetChildContent(view_hwnd);
  if (view_hwnd != nullptr) {
    SetWindowSubclass(view_hwnd, ViewPluginMessageSubclassProc, 1,
                      reinterpret_cast<DWORD_PTR>(flutter_controller_.get()));
  }
  RegisterPlugins(flutter_controller_->engine());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();
  this->Show();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    if (flutter_controller_->view()) {
      HWND view_hwnd = flutter_controller_->view()->GetNativeWindow();
      if (view_hwnd != nullptr) {
        RemoveWindowSubclass(view_hwnd, ViewPluginMessageSubclassProc, 1);
      }
    }
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
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
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
