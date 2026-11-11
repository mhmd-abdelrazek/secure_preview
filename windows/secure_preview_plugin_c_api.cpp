#include "include/secure_preview/secure_preview_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "secure_preview_plugin.h"

void SecurePreviewPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  secure_preview::SecurePreviewPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
