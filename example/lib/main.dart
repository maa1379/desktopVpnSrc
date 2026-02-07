import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_v2ray_client_desktop/flutter_v2ray_client_desktop.dart'
    as v2;
import 'dart:io';

Future<void> main(List<String> args) async {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter V2Ray Client Desktop',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121016),
        cardColor: const Color(0xFF1C1822),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            backgroundColor: const Color(0xFF2A2433),
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late final v2ray = v2.FlutterV2rayClientDesktop(statusListener: (status) {
    debugPrint(status.toString());
    setState(() => _status = status);
  }, logListener: (log) {
    if (!_loggingEnabled) return;
    setState(() {
      if (logs.length >= maxLogLines) {
        logs.removeAt(0);
      }
      logs.add(log);
    });
  });

  final link = TextEditingController();
  final jsonCtrl = TextEditingController(
      text:
          '{\n  "log": {\n    "loglevel": "error",\n    "dnsLog": false\n  },\n  "inbounds": [],\n  "outbounds": []\n}');

  static const maxLogLines = 20;
  final List<String> logs = [];
  final ScrollController _logScrollController = ScrollController();
  v2.ConnectionType connectionType = v2.ConnectionType.systemProxy;
  v2.V2rayStatus _status = const v2.V2rayStatus();
  Future<String>? _xrayVersion;
  Future<String>? _singBoxVersion;
  bool _loggingEnabled = true;

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB', 'TB', 'PB'];
    double value = bytes / 1024;
    int unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    // Precision: 0 decimals for >= 100, 1 for >= 10, else 2
    String formatted = value >= 100
        ? value.toStringAsFixed(0)
        : value >= 10
            ? value.toStringAsFixed(1)
            : value.toStringAsFixed(2);
    return '$formatted ${units[unitIndex]}';
  }

  String _formatDuration(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hh = d.inHours;
    return hh > 0 ? '${hh.toString().padLeft(2, '0')}:$mm:$ss' : '$mm:$ss';
  }

  @override
  void initState() {
    super.initState();
    _xrayVersion = v2ray.getXrayVersion();
    _singBoxVersion = v2ray.getSingBoxVersion();
  }

  Future<String?> _promptForSudoPassword(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sudo Password Required'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'VPN mode requires sudo privileges on ${Platform.isMacOS ? 'macOS' : 'Linux'}.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your sudo password',
                ),
                onSubmitted: (value) {
                  Navigator.of(context).pop(value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Title
                        const Text(
                          'V2Ray Config (json):',
                          style: TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        // JSON panel
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1822),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white24),
                          ),
                          padding: const EdgeInsets.all(8),
                          height: 220,
                          child: TextField(
                            controller: jsonCtrl,
                            expands: true,
                            maxLines: null,
                            minLines: null,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              height: 1.2,
                            ),
                            decoration: const InputDecoration(
                              isCollapsed: true,
                              border: InputBorder.none,
                              hintText: '{ ... }',
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        // Status card
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF17131D),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: 18, horizontal: 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _status.state == v2.ConnectionState.connected
                                    ? 'CONNECTED'
                                    : 'DISCONNECTED',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _formatDuration(_status.duration),
                                style: const TextStyle(fontFeatures: []),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Speed:  ${_formatBytes(_status.download)}↓   ${_formatBytes(_status.upload)}↑',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Traffic:  ${_formatBytes(_status.totalDownload)}↓   ${_formatBytes(_status.totalUpload)}↑',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 10),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Column(
                                  children: [
                                    FutureBuilder<String>(
                                      future: _xrayVersion,
                                      builder: (context, snap) {
                                        final txt = (snap.data ?? '').isEmpty
                                            ? 'Xray: version unavailable'
                                            : 'Xray: ${snap.data}';
                                        return Text(
                                          txt,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 12),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 4),
                                    FutureBuilder<String>(
                                      future: _singBoxVersion,
                                      builder: (context, snap) {
                                        final txt = (snap.data ?? '').isEmpty
                                            ? 'Sing-Box: version unavailable'
                                            : 'Sing-Box: ${snap.data}';
                                        return Text(
                                          txt,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 12),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Actions rows
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            ElevatedButton(
                              onPressed: () async {
                                try {
                                  final config = jsonCtrl.text.trim();
                                  String? sudoPassword;

                                  // Prompt for sudo password if VPN mode on Linux or macOS
                                  if ((Platform.isLinux || Platform.isMacOS) &&
                                      connectionType == v2.ConnectionType.vpn) {
                                    sudoPassword =
                                        await _promptForSudoPassword(context);
                                    if (sudoPassword == null) {
                                      return; // User cancelled
                                    }
                                  }

                                  await v2ray.startV2Ray(
                                    config: config,
                                    connectionType: connectionType,
                                    sudoPassword: sudoPassword,
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Start failed: $e')),
                                  );
                                }
                              },
                              child: const Text('Connect'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                await v2ray.stopV2Ray();
                              },
                              child: const Text('Disconnect'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  final idx = connectionType.index;
                                  final last =
                                      v2.ConnectionType.values.length - 1;
                                  connectionType = v2.ConnectionType
                                      .values[idx == last ? 0 : idx + 1];
                                });
                              },
                              child: Text('VPN Mode (${connectionType.name})'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                final data =
                                    await Clipboard.getData('text/plain');
                                final text = data?.text?.trim();
                                if (text == null || text.isEmpty) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Clipboard empty')),
                                  );
                                  return;
                                }
                                link.text = text;
                                final parser = v2.V2rayParser();
                                await parser.parse(text);
                                jsonCtrl.text = parser.json();
                              },
                              child: const Text(
                                  'Import from v2ray share link (clipboard)'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                final target = link.text.isNotEmpty
                                    ? link.text
                                    : jsonCtrl.text;
                                final delay =
                                    await v2ray.getServerDelay(url: target);
                                if (!mounted) return;
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('Delay: ${delay}ms')),
                                  );
                                }
                              },
                              child: const Text('Server Delay'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Right: Live Logs panel
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'V2ray Logs:',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.white70),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => setState(
                                  () => _loggingEnabled = !_loggingEnabled),
                              icon: Icon(
                                  _loggingEnabled
                                      ? Icons.pause_circle
                                      : Icons.play_circle,
                                  size: 20),
                              color: _loggingEnabled
                                  ? Colors.red[400]
                                  : Colors.green[400],
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip:
                                  'Logs: ${_loggingEnabled ? 'On' : 'Off'}',
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () {
                                if (logs.isNotEmpty) {
                                  Clipboard.setData(
                                      ClipboardData(text: logs.join('\n')));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Logs copied to clipboard')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.copy, size: 18),
                              color: Colors.blue[400],
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Copy logs',
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  logs.clear();
                                });
                              },
                              icon: const Icon(Icons.delete_outline, size: 20),
                              color: Colors.grey[400],
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Clear logs',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C1822),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Scrollbar(
                              controller: _logScrollController,
                              thumbVisibility: false,
                              radius: const Radius.circular(6.0),
                              child: SingleChildScrollView(
                                controller: _logScrollController,
                                reverse: true,
                                child: SelectableText(
                                  logs.join('\n'),
                                  style: const TextStyle(
                                      fontFamily: 'monospace', fontSize: 12),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
