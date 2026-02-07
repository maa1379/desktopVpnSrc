import 'dart:io';
import 'dart:async';
import 'dart:convert';
export 'v2ray_parser.dart';
import 'utils/utils.dart';
import 'package:path/path.dart' as path;

/// Defines the type of delay measurement method for server latency checks.
///
/// - [http]: Measures HTTP connection delay
/// - [tcp]: Measures TCP connection establishment time
enum DelayType { http, tcp }

/// Defines how the V2Ray proxy connection is established.
///
/// - [proxy]: Direct proxy mode (application level)
/// - [systemProxy]: System-wide proxy configuration
/// - [vpn]: VPN/TUN mode (requires administrator/root privileges)
enum ConnectionType { proxy, systemProxy, vpn }

/// Represents the current state of the V2Ray connection.
///
/// - [connected]: V2Ray is actively connected
/// - [disconnected]: V2Ray is not connected
enum ConnectionState { connected, disconnected }

/// Default SOCKS5 proxy endpoint used by Xray core.
const String _proxyEndpoint = 'socks://127.0.0.1:10808';

/// Represents the current status and statistics of a V2Ray connection.
///
/// This class provides real-time information about connection state,
/// traffic usage, and connection duration.
class V2rayStatus {
  /// Time elapsed since the connection was established.
  final Duration duration;

  /// Current connection state (connected or disconnected).
  final ConnectionState state;

  /// Current download speed in bytes per second.
  final int download;

  /// Current upload speed in bytes per second.
  final int upload;

  /// Total bytes downloaded since connection started.
  final int totalDownload;

  /// Total bytes uploaded since connection started.
  final int totalUpload;

  /// Creates a new [V2rayStatus] instance.
  ///
  /// All parameters are optional and default to zero/disconnected state.
  const V2rayStatus({
    this.duration = const Duration(),
    this.state = ConnectionState.disconnected,
    this.download = 0,
    this.upload = 0,
    this.totalDownload = 0,
    this.totalUpload = 0,
  });

  @override
  String toString() {
    return 'V2rayStatus(duration: $duration, state: $state, download: $download, upload: $upload, totalDownload: $totalDownload, totalUpload: $totalUpload)';
  }
}

/// A Flutter plugin for integrating V2Ray/Xray proxy clients on desktop platforms.
///
/// This class manages V2Ray connections, system proxy configuration, and VPN/TUN
/// mode operations for Windows, macOS, and Linux platforms.
///
/// Features:
/// - Multiple connection types (proxy, system proxy, VPN)
/// - Real-time traffic statistics
/// - Server delay measurement
/// - Cross-platform support
///
/// Example:
/// ```dart
/// final client = FlutterV2rayClientDesktop(
///   logListener: (log) => print(log),
///   statusListener: (status) => print(status),
/// );
///
/// await client.startV2Ray(
///   config: configJson,
///   connectionType: ConnectionType.systemProxy,
/// );
/// ```
class FlutterV2rayClientDesktop {
  /// Callback function that receives log messages from Xray and Sing-Box cores.
  final void Function(String log) logListener;

  /// Callback function that receives real-time connection status updates.
  final void Function(V2rayStatus status) statusListener;

  /// Process handle for the Xray core instance.
  Process? _xray;

  /// Process handle for the Sing-Box core instance (used for VPN/TUN mode).
  Process? _singbox;

  /// Timer for periodic status updates.
  Timer? _statusTimer;

  /// Currently active connection type.
  ConnectionType _connectionType = ConnectionType.systemProxy;

  /// Creates a new instance of [FlutterV2rayClientDesktop].
  ///
  /// [logListener] receives all log messages from the proxy cores.
  /// [statusListener] receives periodic status updates including traffic stats.
  FlutterV2rayClientDesktop(
      {required this.logListener, required this.statusListener});

  /// Starts the Xray core process with the provided configuration.
  ///
  /// [config] is the JSON configuration string for Xray core.
  /// Returns early if Xray is already running or if the resource path is unavailable.
  Future<void> _runXRay(String config) async {
    // Prevent multiple instances
    if (_xray != null) {
      return;
    }

    // Get the path to Xray executable
    final xpath = await geResPath();
    if (xpath == null) return;

    // Write configuration to file
    await File(path.join(xpath, 'config.json')).writeAsString(config);

    // Start Xray process
    _xray = await Process.start(path.join(xpath, 'xray'), [
      'run',
      '-c',
      path.join(xpath, 'config.json'),
    ]);

    // Listen to stdout for logging
    _xray!.stdout.listen((event) {
      logListener.call("[Xray] ${utf8.decode(event)}");
    });
  }

  /// Stops the Xray core process if it's running.
  void _stopXRay() {
    if (_xray == null) {
      return;
    }
    _xray!.kill();
    _xray = null;
  }

  /// Starts the Sing-Box process for VPN/TUN mode operation.
  ///
  /// [sudoPassword] is required for Linux systems to grant necessary privileges.
  /// On Windows and macOS, the application should be run with elevated privileges.
  Future<void> _runSingBox({String? sudoPassword}) async {
    // Prevent multiple instances
    if (_singbox != null) {
      return;
    }

    final xpath = await geResPath();
    if (xpath == null) return;
    logListener.call("[sing-box] started");

    // On macOS, config files and resources are in the parent Resources directory
    // while binaries are in arch-specific subdirectories (arm64/x64)
    final resourcesPath = Platform.isMacOS ? path.dirname(xpath) : xpath;
    final configPath = path.join(resourcesPath, 'tun.json');

    // Linux and macOS require sudo for TUN device access
    if ((Platform.isLinux || Platform.isMacOS) && sudoPassword != null) {
      _singbox = await Process.start(
        'sudo',
        [
          '-S', // Read password from stdin
          path.join(xpath, 'sing-box'),
          'run',
          '-c',
          configPath,
        ],
        workingDirectory: resourcesPath,
        environment: {'ENABLE_DEPRECATED_SPECIAL_OUTBOUNDS': 'true'},
      );

      // Provide sudo password via stdin
      _singbox!.stdin.writeln(sudoPassword);
      _singbox!.stdin.close();
    } else {
      // Windows: Run with current privileges (must be elevated)
      _singbox = await Process.start(
        path.join(xpath, 'sing-box'),
        ['run', '-c', configPath],
        workingDirectory: resourcesPath,
        environment: {'ENABLE_DEPRECATED_SPECIAL_OUTBOUNDS': 'true'},
      );
    }

    // Listen to stdout for logging
    _singbox!.stdout.listen((event) {
      logListener.call("[sing-box] ${utf8.decode(event)}");
    });

    // Listen to stderr for error logging
    _singbox!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => logListener("[sing-box][err] $line"));
  }

  /// Stops the Sing-Box process if it's running.
  void _stopSingBox() {
    if (_singbox == null) {
      return;
    }
    _singbox!.kill();
    _singbox = null;
  }

  /// Starts a periodic timer that queries Xray's API for connection statistics.
  ///
  /// Updates are sent every second via the [statusListener] callback.
  /// Tracks both instantaneous speeds and cumulative traffic.
  _startStatusTimer() async {
    final xpath = await geResPath();
    if (xpath == null) return;

    // Track previous values to calculate speed deltas
    int previousDown = 0;
    int previousUp = 0;

    // Wait for Xray to fully initialize
    await Future.delayed(const Duration(seconds: 1));

    // Query stats every second
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        final exe = path.join(xpath, 'xray');

        // Query system uptime via Xray API
        final sysRes = await Process.run(exe, [
          'api',
          'statssys',
          '--server=127.0.0.1:10085',
        ]);
        final sysOut = ('${sysRes.stdout}${sysRes.stderr}').trim();
        int duration = 0;
        try {
          final sysJson = jsonDecode(sysOut) as Map<String, dynamic>;
          duration = (sysJson['Uptime'] as num?)?.toInt() ?? 0;
        } catch (_) {
          duration = 0;
        }

        // Query traffic statistics via Xray API
        final statsRes = await Process.run(exe, [
          'api',
          'statsquery',
          '--server=127.0.0.1:10085',
        ]);
        final statsOut = ('${statsRes.stdout}${statsRes.stderr}').trim();
        int upload = 0;
        int download = 0;
        try {
          final statsJson = jsonDecode(statsOut) as Map<String, dynamic>;
          final List<dynamic> statList =
              (statsJson['stat'] as List<dynamic>?) ?? const [];

          // Parse upload and download values from stats
          for (final item in statList) {
            if (item is Map<String, dynamic>) {
              final name = item['name']?.toString() ?? '';
              final value = (item['value'] as num?)?.toInt() ?? 0;
              if (name.contains('outbound>>>proxy>>>traffic>>>uplink') ||
                  name.endsWith('outbound>>>proxy>>>uplink')) {
                upload = value;
              }
              if (name.contains('outbound>>>proxy>>>traffic>>>downlink') ||
                  name.endsWith('outbound>>>proxy>>>downlink')) {
                download = value;
              }
            }
          }
        } catch (_) {
          upload = 0;
          download = 0;
        }

        // Calculate speed as delta from previous reading
        statusListener.call(
          V2rayStatus(
            upload: upload - previousUp,
            state: ConnectionState.connected,
            download: download - previousDown,
            totalUpload: upload,
            totalDownload: download,
            duration: Duration(seconds: duration),
          ),
        );

        // Update previous values for next iteration
        previousUp = upload;
        previousDown = download;
      } catch (_) {
        // Silently ignore errors (connection might be starting/stopping)
      }
    });
  }

  /// Configures system proxy settings on macOS using networksetup.
  ///
  /// [proxy] is the proxy URL (e.g., 'socks://127.0.0.1:10808').
  /// Pass an empty string to disable the proxy.
  ///
  /// Note: Currently targets Wi-Fi interface only.
  Future<void> _setDarwinSystemProxy(String proxy) async {
    if (proxy.isEmpty) {
      // Disable both SOCKS and web proxy
      await Process.run("networksetup", [
        "-setsocksfirewallproxystate",
        "wi-fi",
        "off",
      ]);
      await Process.run("networksetup", ["-setwebproxystate", "wi-fi", "off"]);
      return;
    }

    // Parse proxy URL
    final uri = Uri.tryParse(proxy);
    if (uri == null) {
      throw 'inbound proxy is not valid.';
    }

    // Configure web proxy
    await Process.run("networksetup", [
      "-setwebproxy",
      "wi-fi",
      uri.host,
      uri.port.toString(),
    ]);

    // Configure SOCKS proxy
    await Process.run("networksetup", [
      "-setsocksfirewallproxy",
      "wi-fi",
      uri.host,
      uri.port.toString(),
    ]);
  }

  /// Configures system proxy settings on Windows via registry and netsh.
  ///
  /// [proxy] is the proxy URL (e.g., 'socks://127.0.0.1:10808').
  /// Pass an empty string to disable the proxy.
  ///
  /// This method:
  /// - Modifies Internet Settings registry
  /// - Configures WinHTTP proxy
  /// - Sets environment variables for http_proxy and https_proxy
  Future<void> _setWindowsSystemProxy(String proxy) async {
    // Enable/disable proxy in registry
    await Process.run('reg', [
      'add',
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
      '/v',
      'ProxyEnable',
      '/t',
      'REG_DWORD',
      '/d',
      proxy.isEmpty ? '0' : '1',
      '/f',
    ]);

    if (proxy.isNotEmpty) {
      // Set proxy server address in registry
      await Process.run('reg', [
        'add',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        '/v',
        'ProxyServer',
        '/t',
        'REG_SZ',
        '/d',
        proxy,
        '/f',
      ]);

      // Configure WinHTTP proxy (for system services)
      await Process.run('netsh', [
        'winhttp',
        'set',
        'proxy',
        'proxy-server="$proxy"',
        'bypass-list="*.local;<local>"',
      ]);
    } else {
      // Reset WinHTTP proxy
      await Process.run('netsh', ['winhttp', 'reset', 'proxy']);
    }

    // Set environment variables for applications
    await Process.run('setx', ['http_proxy', proxy]);
    await Process.run('setx', ['https_proxy', proxy]);

    // Set session-level environment variables
    await Process.run('powershell', [
      '-Command',
      '[System.Environment]::SetEnvironmentVariable("http_proxy","$proxy")',
    ]);
    await Process.run('powershell', [
      '-Command',
      '[System.Environment]::SetEnvironmentVariable("https_proxy","$proxy")',
    ]);
  }

  /// Configures system proxy settings on Linux using gsettings (GNOME).
  ///
  /// [proxy] is the proxy URL (e.g., 'socks://127.0.0.1:10808').
  /// Pass an empty string to disable the proxy.
  ///
  /// Note: This currently only supports GNOME-based desktop environments.
  /// For other DEs, additional implementation may be needed.
  Future<void> _setLinuxSystemProxy(String proxy) async {
    // Use gsettings for GNOME-based desktops
    const schema = 'org.gnome.system.proxy';

    if (proxy.isEmpty) {
      // Disable proxy
      await Process.run('gsettings', ['set', schema, 'mode', 'none']);
      return;
    }

    // Parse proxy URL
    final uri = Uri.tryParse(proxy);
    if (uri == null) {
      throw 'inbound proxy is not valid.';
    }

    // Enable manual proxy mode
    await Process.run('gsettings', ['set', schema, 'mode', 'manual']);

    // Configure HTTP proxy
    await Process.run('gsettings', ['set', '$schema.http', 'host', uri.host]);
    await Process.run('gsettings', [
      'set',
      '$schema.http',
      'port',
      uri.port.toString(),
    ]);

    // Configure SOCKS proxy if scheme is 'socks'
    if (uri.scheme == 'socks') {
      await Process.run('gsettings', [
        'set',
        '$schema.socks',
        'host',
        uri.host,
      ]);
      await Process.run('gsettings', [
        'set',
        '$schema.socks',
        'port',
        uri.port.toString(),
      ]);
    }
  }

  /// Checks if a string is a domain name (not an IP address).
  ///
  /// Returns true if the address is a domain, false if it's an IP address.
  bool _isDomain(String address) {
    if (address.isEmpty) return false;
    
    // Check if it's an IPv4 address
    final ipv4Pattern = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (ipv4Pattern.hasMatch(address)) {
      return false;
    }
    
    // Check if it's an IPv6 address (contains colons)
    if (address.contains(':')) {
      return false;
    }
    
    // If it's not an IP, it's likely a domain
    return true;
  }

  /// Updates the tun.json file with the domain from V2Ray config.
  ///
  /// [config] is the V2Ray JSON configuration string.
  /// If the config has a domain address, it adds it to tun.json DNS rules.
  /// If it has an IP address, it removes any existing domain rules.
  Future<void> _updateTunJsonDomain(String config) async {
    try {
      final xpath = await geResPath();
      if (xpath == null) return;

      final resourcesPath = Platform.isMacOS ? path.dirname(xpath) : xpath;
      final tunJsonPath = path.join(resourcesPath, 'tun.json');

      // Read tun.json
      final tunFile = File(tunJsonPath);
      if (!tunFile.existsSync()) {
        logListener('[TUN] tun.json not found');
        return;
      }

      final tunContent = await tunFile.readAsString();
      final tunConfig = jsonDecode(tunContent) as Map<String, dynamic>;
      
      // Parse V2Ray config to extract domain
      final v2rayConfig = jsonDecode(config) as Map<String, dynamic>;
      String? domain;
      
      // Extract address from outbound configuration
      final outbounds = v2rayConfig['outbounds'] as List<dynamic>?;
      if (outbounds != null && outbounds.isNotEmpty) {
        final proxyOutbound = outbounds.firstWhere(
          (o) => o['tag'] == 'proxy',
          orElse: () => outbounds[0],
        ) as Map<String, dynamic>;
        
        // Try different protocol structures
        final settings = proxyOutbound['settings'] as Map<String, dynamic>?;
        if (settings != null) {
          // For vless, vmess, trojan protocols
          final vnext = settings['vnext'] as List<dynamic>?;
          if (vnext != null && vnext.isNotEmpty) {
            final server = vnext[0] as Map<String, dynamic>;
            final address = server['address'] as String?;
            if (address != null && _isDomain(address)) {
              domain = address;
            }
          }
          
          // For shadowsocks, socks protocols
          final servers = settings['servers'] as List<dynamic>?;
          if (servers != null && servers.isNotEmpty) {
            final server = servers[0] as Map<String, dynamic>;
            final address = server['address'] as String?;
            if (address != null && _isDomain(address)) {
              domain = address;
            }
          }
        }
      }
      
      // Update DNS rules in tun.json
      final dns = tunConfig['dns'] as Map<String, dynamic>?;
      if (dns != null) {
        final rules = dns['rules'] as List<dynamic>?;
        if (rules != null) {
          // Remove existing local_local domain rule if it exists
          rules.removeWhere((rule) {
            if (rule is Map<String, dynamic>) {
              return rule['server'] == 'local_local' && 
                     rule['domain'] != null;
            }
            return false;
          });
          
          // Add new domain rule if we have a domain
          if (domain != null) {
            rules.insert(0, {
              'server': 'local_local',
              'domain': [domain],
            });
            logListener('[TUN] Added domain to tun.json: $domain');
          } else {
            logListener('[TUN] No domain found, removed domain rule from tun.json');
          }
          
          // Write updated config back to file
          final encoder = JsonEncoder.withIndent('  ');
          await tunFile.writeAsString(encoder.convert(tunConfig));
        }
      }
    } catch (e) {
      logListener('[TUN] Error updating tun.json: $e');
    }
  }

  /// Manages Windows TUN/VPN tunnel via Sing-Box.
  ///
  /// [proxy] determines whether to start or stop the tunnel.
  /// [config] is the V2Ray configuration to extract domain from.
  /// Pass an empty string to stop, or a proxy URL to start.
  runWinTunnel(String proxy, {String? config}) async {
    if (proxy.isEmpty) {
      _stopSingBox();
    } else {
      // Update tun.json with domain from config before starting sing-box
      if (config != null) {
        await _updateTunJsonDomain(config);
      }
      await _runSingBox();
      // Allow time for TUN interface to initialize
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  /// Manages macOS TUN/VPN tunnel via Sing-Box.
  ///
  /// [proxy] determines whether to start or stop the tunnel.
  /// [sudoPassword] is required to grant necessary privileges for TUN device access.
  /// Pass an empty string for proxy to stop, or a proxy URL to start.
  runMacTunnel(String proxy, {String? sudoPassword}) async {
    if (proxy.isEmpty) {
      _stopSingBox();
    } else {
      await _runSingBox(sudoPassword: sudoPassword);
      // Allow time for TUN interface to initialize
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  /// Manages Linux TUN/VPN tunnel via Sing-Box.
  ///
  /// [proxy] determines whether to start or stop the tunnel.
  /// [sudoPassword] is required to grant necessary privileges for TUN device access.
  /// Pass an empty string for proxy to stop, or a proxy URL to start.
  runLinuxTunnel(String proxy, {String? sudoPassword}) async {
    if (proxy.isEmpty) {
      _stopSingBox();
    } else {
      await _runSingBox(sudoPassword: sudoPassword);
      // Allow time for TUN interface to initialize
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  /// Configures system-wide proxy settings for the current platform.
  ///
  /// [proxy] is the proxy URL (e.g., 'socks://127.0.0.1:10808').
  /// Pass an empty string to disable the system proxy.
  ///
  /// Supported protocols: http, https, socks
  ///
  /// Platform-specific behavior:
  /// - **Windows**: Modifies registry and WinHTTP settings
  /// - **macOS**: Uses networksetup for Wi-Fi interface
  /// - **Linux**: Uses gsettings (GNOME-based desktops)
  Future<void> setSystemProxy(String proxy) async {
    if (Platform.isMacOS) {
      await _setDarwinSystemProxy(proxy);
    } else if (Platform.isWindows) {
      _setWindowsSystemProxy(proxy);
    } else if (Platform.isLinux) {
      await _setLinuxSystemProxy(proxy);
    }
  }

  /// Starts the V2Ray/Xray service with the specified configuration.
  ///
  /// [config] is the JSON configuration string for Xray core.
  /// [connectionType] determines how the proxy connection is established:
  /// - [ConnectionType.proxy]: Direct proxy mode (application-level)
  /// - [ConnectionType.systemProxy]: System-wide proxy (default)
  /// - [ConnectionType.vpn]: VPN/TUN mode (requires elevated privileges)
  ///
  /// [sudoPassword] is required for Linux and macOS VPN mode to grant necessary privileges.
  ///
  /// **Important**: [ConnectionType.vpn] requires:
  /// - Administrator privileges on Windows
  /// - Root privileges (sudo password) on Unix-based systems (Linux/macOS)
  ///
  /// Example:
  /// ```dart
  /// await client.startV2Ray(
  ///   config: jsonConfig,
  ///   connectionType: ConnectionType.systemProxy,
  /// );
  /// ```
  Future<void> startV2Ray({
    required String config,
    ConnectionType connectionType = ConnectionType.systemProxy,
    String? sudoPassword,
  }) async {
    _connectionType = connectionType;
    const proxy = _proxyEndpoint;
    await _runXRay(config);
    _startStatusTimer();
    if (connectionType == ConnectionType.systemProxy) {
      await setSystemProxy(proxy);
    } else if (connectionType == ConnectionType.vpn) {
      await Future.delayed(const Duration(seconds: 3));
      if (Platform.isLinux) {
        await runLinuxTunnel(proxy, sudoPassword: sudoPassword);
      } else if (Platform.isMacOS) {
        await runMacTunnel(proxy, sudoPassword: sudoPassword);
      } else {
        await runWinTunnel(proxy, config: config);
      }
    }
  }

  /// Stops the V2Ray/Xray service and cleans up resources.
  ///
  /// This method:
  /// - Terminates the Xray core process
  /// - Disables system proxy or VPN tunnel based on the active connection type
  /// - Cancels the status update timer
  /// - Sends a disconnected status update
  Future<void> stopV2Ray() async {
    _stopXRay();
    if (_connectionType == ConnectionType.systemProxy) {
      await setSystemProxy('');
    } else if (_connectionType == ConnectionType.vpn) {
      if (Platform.isLinux) {
        await runLinuxTunnel('');
      } else if (Platform.isMacOS) {
        await runMacTunnel('');
      } else {
        await runWinTunnel('');
      }
    }
    _statusTimer?.cancel();
    statusListener.call(const V2rayStatus());
  }

  /// Parses delay measurement output from xray-knife tool.
  ///
  /// [output] is the raw output string from the xray-knife command.
  /// [type] specifies which delay measurement method was used.
  ///
  /// Returns the parsed delay in milliseconds, or -1 if parsing fails.
  int _getDelayFromOutput(String output, DelayType type) {
    switch (type) {
      case DelayType.http:
        {
          // Extract HTTP delay from "Real Delay: XXms" format
          final delayString = RegExp(
            r'Real Delay\: (\-)?\d*ms',
          ).stringMatch(output);
          if (delayString == null) return -1;
          return int.tryParse(
                delayString.substring(12, delayString.length - 2),
              ) ??
              -1;
        }
      case DelayType.tcp:
        {
          // Extract TCP delay from "Established TCP connection in XXms" format
          final delayString = RegExp(
            r'Established TCP connection in (\-)?\d*ms',
          ).stringMatch(output);
          if (delayString == null) return -1;
          return int.tryParse(
                delayString.substring(30, delayString.length - 2),
              ) ??
              -1;
        }
    }
  }

  /// Measures the network delay to a V2Ray server using the specified method.
  ///
  /// [url] is the V2Ray/Xray server configuration URL.
  /// [type] specifies the measurement method (default: [DelayType.tcp]).
  ///
  /// Returns the delay in milliseconds, or -1 if measurement fails.
  ///
  /// Example:
  /// ```dart
  /// final delay = await client.getServerDelay(
  ///   url: 'vmess://...',
  ///   type: DelayType.tcp,
  /// );
  /// print('Server delay: ${delay}ms');
  /// ```
  Future<int> getServerDelay({
    required String url,
    DelayType type = DelayType.http,
  }) async {
    String? host;
    int? port;

    try {
      // 1. استخراج هاست و پورت از لینک کانفیگ
      if (url.startsWith('vmess://')) {
        final decoded = utf8.decode(base64Decode(url.substring(8)));
        final json = jsonDecode(decoded);
        host = json['add'];
        port = int.tryParse(json['port'].toString());
      } else if (url.startsWith('vless://') || url.startsWith('trojan://')) {
        // پارس کردن ساده برای vless و trojan
        final uri = Uri.tryParse(url);
        if (uri != null) {
          host = uri.host;
          port = uri.port;
          // اگر هاست در پارامترها بود (مثلا در query params)
          if (host.isEmpty) {
            // هندل کردن حالت‌های خاص لینک‌های خراب
            final parts = url.split('@');
            if(parts.length > 1) {
              final address = parts[1].split(':')[0];
              final portPart = parts[1].split(':')[1].split('?')[0];
              host = address;
              port = int.tryParse(portPart);
            }
          }
        }
      } else if (url.startsWith('ss://')) {
        // پارس ss (معمولا base64 است)
        try {
          final uri = Uri.parse(url);
          host = uri.host;
          port = uri.port;
        } catch(e) {
          // اگر فرمت قدیمی بود و Uri پارس نکرد، نیاز به دیکد base64 است
          // برای سادگی فعلا فرض بر لینک استاندارد است
        }
      }

      // اگر جیسون کامل فرستاده شده بود (خروجی xray-knife یا parser)
      if (host == null && url.contains('{')) {
        // اگر ورودی جیسون خام بود
        try {
          final json = jsonDecode(url);
          // باید ساختار جیسون v2ray را پیمایش کنید تا outbounds -> settings -> vnext -> address را پیدا کنید
          // این بخش پیچیده است، پیشنهاد می‌شود همیشه لینک کانفیگ را بفرستید
        } catch(_) {}
      }

      if (host == null || port == null) {
        return -1;
      }

      // 2. انجام عملیات پینگ (TCP Handshake)
      final stopwatch = Stopwatch()..start();
      try {
        // پیدا کردن آی‌پی کارت شبکه اصلی (برای دور زدن VPN)
        InternetAddress? sourceAddress;

        // فقط اگر VPN وصل است، دنبال اینترفیس اصلی بگردیم
        // (فرض میکنیم متغیری دارید که وضعیت اتصال را نشان میدهد، اگر ندارید همیشه این کار را بکنید ضرر ندارد)
        sourceAddress = await _getPhysicalNetworkInterface();

        // اتصال با مشخص کردن sourceAddress
        // این باعث می‌شود ترافیک از تانل رد نشود و مستقیم برود
        final socket = await Socket.connect(
          host,
          port,
          sourceAddress: sourceAddress, // نکته کلیدی اینجاست
          timeout: Duration(seconds: 3),
        );

        socket.destroy();
        stopwatch.stop();
        return stopwatch.elapsedMilliseconds;
      } catch (e) {
        return -1;
      }

    } catch (e) {
      return -1;
    }
  }

  Future<InternetAddress?> _getPhysicalNetworkInterface() async {
    try {
      // لیست تمام اینترفیس‌های شبکه
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      for (var interface in interfaces) {
        // فیلتر کردن اینترفیس‌های VPN
        // در مک معمولا utun است، در ویندوز/لینوکس tun یا tap
        final name = interface.name.toLowerCase();

        if (name.contains('tun') ||
            name.contains('tap') ||
            name.contains('pptp') ||
            name.contains('vpn')) {
          continue; // این‌ها را رد کن
        }

        // معمولاً en0 در مک وای‌فای است، و wlan/eth در سایر سیستم‌ها
        // اولین اینترفیسی که آی‌پی معتبر داشته باشد را برمی‌گردانیم
        for (var addr in interface.addresses) {
          if (!addr.isLinkLocal && !addr.isLoopback) {
            return addr;
          }
        }
      }
    } catch (e) {
      // اگر نتوانست پیدا کند، نال برمی‌گرداند تا سیستم تصمیم بگیرد
      return null;
    }
    return null;
  }

  /// Returns version string of Xray core by running `xray --version`.
  Future<String> getXrayVersion() async {
    final xpath = await geResPath();
    if (xpath == null) return '';
    try {
      final exe = path.join(xpath, 'xray');
      final res = await Process.run(exe, ['--version']);
      final out = ('${res.stdout}${res.stderr}').trim().split('\n').first;
      return out;
    } catch (e) {
      return '';
    }
  }

  /// Returns version string of Sing-Box by running `sing-box version`.
  Future<String> getSingBoxVersion() async {
    final xpath = await geResPath();
    if (xpath == null) return '';
    try {
      final exe = path.join(xpath, 'sing-box');
      final res = await Process.run(exe, ['version']);
      final out = ('${res.stdout}${res.stderr}').trim().split('\n').first;
      return out;
    } catch (e) {
      return '';
    }
  }
}
