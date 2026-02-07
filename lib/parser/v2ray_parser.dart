import '../errors/errors.dart';
import 'url.dart';

/// Main parser class for V2Ray URLs.
///
/// This class provides a unified interface for parsing various V2Ray protocol URLs
/// (vmess, vless, trojan, shadowsocks, socks) and generating V2Ray configuration.
class V2rayParser {
  V2RayURL? _parsedUrl;

  /// Parses a V2Ray URL and stores the parsed configuration.
  ///
  /// Supports the following protocols:
  /// - vmess://
  /// - vless://
  /// - trojan://
  /// - ss:// (shadowsocks)
  /// - socks://
  ///
  /// Throws [V2rayParserError] if the URL format is invalid or unsupported.
  Future<void> parse(String url) async {
    try {
      if (url.startsWith('vmess://')) {
        _parsedUrl = VmessURL(url: url);
      } else if (url.startsWith('vless://')) {
        _parsedUrl = VlessURL(url: url);
      } else if (url.startsWith('trojan://')) {
        _parsedUrl = TrojanURL(url: url);
      } else if (url.startsWith('ss://')) {
        _parsedUrl = ShadowSocksURL(url: url);
      } else if (url.startsWith('socks://')) {
        _parsedUrl = SocksURL(url: url);
      } else {
        throw V2rayParserError(V2rayParserErrorType.parseURI);
      }
    } catch (e) {
      if (e is V2rayParserError) {
        rethrow;
      }
      throw V2rayParserError(V2rayParserErrorType.parseURI);
    }
  }

  /// Returns the full V2Ray configuration as a JSON string.
  ///
  /// Must call [parse] before calling this method.
  /// Throws [StateError] if no URL has been parsed yet.
  String json({int indent = 2}) {
    if (_parsedUrl == null) {
      throw StateError('No URL has been parsed. Call parse() first.');
    }
    return _parsedUrl!.getFullConfiguration(indent: indent);
  }

  /// Returns the server address from the parsed URL.
  ///
  /// Returns empty string if no URL has been parsed.
  String get address => _parsedUrl?.address ?? '';

  /// Returns the server port from the parsed URL.
  ///
  /// Returns 0 if no URL has been parsed.
  int get port => _parsedUrl?.port ?? 0;

  /// Returns the remark/name from the parsed URL.
  ///
  /// Returns empty string if no URL has been parsed.
  String get remark => _parsedUrl?.remark ?? '';

  /// Returns the full configuration as a Map.
  ///
  /// Returns null if no URL has been parsed.
  Map<String, dynamic>? get fullConfiguration => _parsedUrl?.fullConfiguration;

  /// Returns the outbound configuration.
  ///
  /// Returns null if no URL has been parsed.
  Map<String, dynamic>? get outbound => _parsedUrl?.outbound1;
}
