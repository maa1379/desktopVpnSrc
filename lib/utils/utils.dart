import 'dart:convert';
import 'dart:io';

import 'package:flutter_v2ray_client_desktop/flutter_v2ray_client_desktop_platform_interface.dart';

import '../flutter_v2ray_client_desktop_platform_interface.dart';

String safeBase64Decode(String source) {
  final l = source.length % 4;
  if (l != 0) {
    source += '=' * (4 - l);
  }
  return utf8.decode(base64Decode(source));
}

Future<String?> geResPath() async {
  if (Platform.isMacOS) {
    return await FlutterV2rayClientDesktopPlatform.instance.geResPath();
  }
  return File(Platform.resolvedExecutable).parent.path;
}
