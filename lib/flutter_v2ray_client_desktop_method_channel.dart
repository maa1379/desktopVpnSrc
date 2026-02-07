import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_v2ray_client_desktop_platform_interface.dart';

/// An implementation of [FlutterV2rayClientDesktopPlatform] that uses method channels.
class MethodChannelFlutterV2rayClientDesktop
    extends FlutterV2rayClientDesktopPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_v2ray_client_desktop');

  @override
  Future<String?> geResPath() async {
    final version = await methodChannel.invokeMethod<String>('geResPath');
    return version;
  }
}
