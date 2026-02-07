#ifndef FLUTTER_PLUGIN_FLUTTER_V2RAY_CLIENT_DESKTOP_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_V2RAY_CLIENT_DESKTOP_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/types.h>

G_BEGIN_DECLS

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define FLUTTER_PLUGIN_EXPORT
#endif

typedef struct _FlutterV2rayClientDesktopPlugin FlutterV2rayClientDesktopPlugin;
typedef struct {
  GObjectClass parent_class;
} FlutterV2rayClientDesktopPluginClass;

FLUTTER_PLUGIN_EXPORT GType flutter_v2ray_client_desktop_plugin_get_type();

FLUTTER_PLUGIN_EXPORT void flutter_v2ray_client_desktop_plugin_register_with_registrar(
    FlPluginRegistrar* registrar);

G_END_DECLS

#endif  // FLUTTER_PLUGIN_FLUTTER_V2RAY_CLIENT_DESKTOP_PLUGIN_H_
