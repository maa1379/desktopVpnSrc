#include "include/flutter_v2ray_client_desktop/flutter_v2ray_client_desktop_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_v2ray_client_desktop_plugin.h"

void FlutterV2rayClientDesktopPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_v2ray_client_desktop::FlutterV2rayClientDesktopPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
