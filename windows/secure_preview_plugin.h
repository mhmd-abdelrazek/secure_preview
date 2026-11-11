#ifndef FLUTTER_PLUGIN_SECURE_PREVIEW_PLUGIN_H_
#define FLUTTER_PLUGIN_SECURE_PREVIEW_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>

namespace secure_preview {

class SecurePreviewPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  explicit SecurePreviewPlugin(flutter::PluginRegistrarWindows *registrar);
  ~SecurePreviewPlugin() override;

  // Disallow copy and assign.
  SecurePreviewPlugin(const SecurePreviewPlugin &) = delete;
  SecurePreviewPlugin &operator=(const SecurePreviewPlugin &) = delete;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  // Top-level window that hosts the Flutter view, or nullptr.
  HWND GetTopLevelWindow() const;

  // Hides (or un-hides) the window from screen capture. Returns true if the
  // requested state was applied.
  bool SetCaptureProtection(bool enabled);

  flutter::PluginRegistrarWindows *registrar_;
  HWND protected_window_ = nullptr;
};

}  // namespace secure_preview

#endif  // FLUTTER_PLUGIN_SECURE_PREVIEW_PLUGIN_H_
