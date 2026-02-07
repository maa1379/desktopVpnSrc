import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'flutter_v2ray_client_desktop_method_channel.dart';

abstract class FlutterV2rayClientDesktopPlatform extends PlatformInterface {
  /// Constructs a FlutterV2rayClientDesktopPlatform.
  FlutterV2rayClientDesktopPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterV2rayClientDesktopPlatform _instance =
      MethodChannelFlutterV2rayClientDesktop();

  /// The default instance of [FlutterV2rayClientDesktopPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterV2rayClientDesktop].
  static FlutterV2rayClientDesktopPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterV2rayClientDesktopPlatform] when
  /// they register themselves.
  static set instance(FlutterV2rayClientDesktopPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> geResPath() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
