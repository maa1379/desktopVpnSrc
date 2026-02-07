#include "flutter_v2ray_client_desktop/flutter_v2ray_client_desktop_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <cstring>
#include <memory>
#include <string>

#define FLUTTER_V2RAY_CLIENT_DESKTOP_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), flutter_v2ray_client_desktop_plugin_get_type(), \
                              FlutterV2rayClientDesktopPlugin))

struct _FlutterV2rayClientDesktopPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(FlutterV2rayClientDesktopPlugin, flutter_v2ray_client_desktop_plugin, g_object_get_type())

// Determine architecture similar to Windows implementation
static std::string GetArchitecture() {
#if defined(__x86_64__)
  return "64";
#elif defined(__i386__)
  return "32";
#elif defined(__aarch64__)
  return "arm64";
#elif defined(__arm__)
  return "arm32";
#else
  return "unknown";
#endif
}

// Called when a method is called on the plugin channel from Dart.
static void method_call_handler(FlMethodChannel* channel, FlMethodCall* method_call, gpointer user_data) {
  FlutterV2rayClientDesktopPlugin* plugin = FLUTTER_V2RAY_CLIENT_DESKTOP_PLUGIN(user_data);
  (void)plugin; // unused for now

  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "geResPath") == 0) {
    std::string arch = GetArchitecture();
    // Return absolute path to the architecture-specific resources directory
    gchar* plugin_dir = g_path_get_dirname(__FILE__);
    std::string resources_path = std::string(plugin_dir) + "/resources/" + arch;

    g_autoptr(FlValue) result_value = fl_value_new_string(resources_path.c_str());
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_success_response_new(result_value));
    fl_method_call_respond(method_call, response, nullptr);
    g_free(plugin_dir);
    return;
  }

  g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  fl_method_call_respond(method_call, response, nullptr);
}

static void flutter_v2ray_client_desktop_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(flutter_v2ray_client_desktop_plugin_parent_class)->dispose(object);
}

static void flutter_v2ray_client_desktop_plugin_class_init(FlutterV2rayClientDesktopPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = flutter_v2ray_client_desktop_plugin_dispose;
}

static void flutter_v2ray_client_desktop_plugin_init(FlutterV2rayClientDesktopPlugin* self) {}

void flutter_v2ray_client_desktop_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  FlutterV2rayClientDesktopPlugin* plugin = FLUTTER_V2RAY_CLIENT_DESKTOP_PLUGIN(
      g_object_new(flutter_v2ray_client_desktop_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar),
      "flutter_v2ray_client_desktop",
      FL_METHOD_CODEC(codec));

  fl_method_channel_set_method_call_handler(channel, method_call_handler, g_object_ref(plugin), g_object_unref);

  g_object_unref(plugin);
}
