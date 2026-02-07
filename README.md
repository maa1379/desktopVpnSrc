# 🚀 flutter_v2ray_client_desktop

## ✨ Premium Features

> **🔒 2-Year Guarantee**  
> Free updates & maintenance included

> **💎 Priority Support**  
> Direct, fast help for all premium users

> **🚀 Advanced Features**  
> Unlock exclusive premium capabilities

> ⚠️ **Need help?** If you encounter any issues, please [open an issue](https://github.com/yourusername/flutter_v2ray_client_desktop/issues) or contact us directly on [Telegram](https://t.me/AmirZrDevv) for emergency support. We'll address your concerns ASAP!

---

A powerful Flutter plugin for desktop that lets you run V2Ray/Xray and Sing-Box (for VPN/TUN) with ease. Features system proxy management and a simple URL-to-config parser. Works seamlessly on Windows, macOS, and Linux. 🖥️

## 🛠️ Core Components

| Component     | Version    |
| ------------- | ---------- |
| **Xray Core** | `25.10.15` |
| **Sing-Box**  | `1.12.10`  |


## ✨ Features

- 🔌 **Connection modes**: `proxy`, `systemProxy`, `vpn` (TUN)
- 📊 **Live status**: speed, totals, duration, connection state
- ⚙️ **System proxy control**: Windows/macOS/Linux
- 🔒 **VPN/TUN** via Sing-Box
- ⏱️ **Server delay test**: HTTP/TCP
- 🔗 **Share-link parser**: vmess/vless/trojan/ss/socks → Xray JSON

## 🌐 Platform Support and Requirements

- **Windows**: Xray and Sing-Box binaries are bundled in `windows/resources/`
- **macOS**: binaries in `macos/Resources/`
- **Linux**: binaries in `linux/resources/`
- **Permissions**:
  - `ConnectionType.vpn` requires admin/root (Windows: run as Administrator; Linux/macOS: run with sudo/root). On Linux VPN mode, sudo password is needed at runtime.

## 📦 Install

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_v2ray_client_desktop:
    # Replace with the actual path to your local flutter_v2ray_client_desktop directory
    # Example (uncomment and modify as needed):
    # path: /path/to/your/local/flutter_v2ray_client_desktop
```

Then run `flutter pub get`.

### 🏃 Running the Example App on Windows

- When using `flutter run`, you might see an error like "ProcessException: The requested operation requires elevation" because the app requests admin privileges for features like VPN mode.
- To resolve this:
  - Run `flutter build windows` to build the app.
  - Manually execute the built file from `build\windows\x64\runner\Release\flutter_v2ray_client_desktop_example.exe` (or Debug folder) with admin rights by right-clicking and selecting "Run as administrator".

## 🚀 Quick Start

```dart
import 'package:flutter_v2ray_client_desktop/flutter_v2ray_client_desktop.dart';

final client = FlutterV2rayClientDesktop(
  logListener: (log) => print(log),
  statusListener: (status) => print(status),
);

Future<void> connect(String jsonConfig) async {
  await client.startV2Ray(
    config: jsonConfig,
    connectionType: ConnectionType.systemProxy, // proxy | systemProxy | vpn
  );
}

Future<void> disconnect() async {
  await client.stopV2Ray();
}
```

For a full runnable UI example, see `example/lib/main.dart`.

### 📝 Logs and Status Structure

- **logListener(String log)**
  - Raw lines from cores, e.g. `"[Xray] ..."`, `"[sing-box] ..."`, `"[sing-box][err] ..."`.
  - Useful for debugging and surfacing runtime issues in UI.

- **statusListener(V2rayStatus status)** (emitted ~every 1s)
  - `state`: `ConnectionState.connected | disconnected`
  - `duration`: `Duration` since Xray started (derived from API uptime)
  - `download` / `upload`: current speed in bytes per second (delta)
  - `totalDownload` / `totalUpload`: cumulative bytes since start

Example status printout:

```text
V2rayStatus(duration: 0:02:15.000000, state: ConnectionState.connected, download: 12456, upload: 2345, totalDownload: 3456789, totalUpload: 456789)
```

## 📚 API Reference (Client)

All symbols are in `lib/flutter_v2ray_client_desktop.dart`.

- **Enums**
  - `DelayType { http, tcp }`
  - `ConnectionType { proxy, systemProxy, vpn }`
  - `ConnectionState { connected, disconnected }`

- **Class**: `V2rayStatus`
  - Fields: `duration`, `state`, `download`, `upload`, `totalDownload`, `totalUpload`

- **Class**: `FlutterV2rayClientDesktop`
  - `FlutterV2rayClientDesktop({required void Function(String) logListener, required void Function(V2rayStatus) statusListener})`
  - `Future<void> startV2Ray({required String config, ConnectionType connectionType = ConnectionType.systemProxy, String? sudoPassword})`
    - Starts Xray with `config`.
    - If `systemProxy`, sets system proxy to `socks://127.0.0.1:10808`.
    - If `vpn`, starts Sing-Box TUN. Linux requires `sudoPassword`.
  - `Future<void> stopV2Ray()`
    - Stops Xray; disables system proxy or VPN tunnel; emits disconnected status.
  - `Future<void> setSystemProxy(String proxy)`
    - Cross-platform system proxy setter. Pass empty string to disable.
  - `runWinTunnel(String proxy)` / `runLinuxTunnel(String proxy, {String? sudoPassword})`
    - Manage Sing-Box TUN directly (normally handled by `startV2Ray`/`stopV2Ray`).
  - `Future<int> getServerDelay({required String url, DelayType type = DelayType.tcp})`
    - Accepts a share link or a JSON config string. Returns delay in ms or `-1`.
  - `Future<String> getXrayVersion()` / `Future<String> getSingBoxVersion()`

### 💻 Client Usage Examples

Start with system proxy:

```dart
await client.startV2Ray(
  config: jsonConfig,
  connectionType: ConnectionType.systemProxy,
);
```

Start with VPN/TUN (Linux):

```dart
await client.startV2Ray(
  config: jsonConfig,
  connectionType: ConnectionType.vpn,
  sudoPassword: yourSudoPassword,
);
```

Stop and clean up:

```dart
await client.stopV2Ray();
```

Manually set/clear system proxy:

```dart
await client.setSystemProxy('socks://127.0.0.1:10808');
await client.setSystemProxy(''); // disable
```

Measure delay:

```dart
final delay = await client.getServerDelay(
  url: 'vmess://... or full JSON config',
  type: DelayType.tcp, // http | tcp
);
print('Delay: ${delay}ms');
```

Get versions:

```dart
final xray = await client.getXrayVersion();
final sbox = await client.getSingBoxVersion();
```

## 🔍 Parser API (`V2rayParser`)

Publicly exported via `lib/v2ray_parser.dart`.

- **Class**: `V2rayParser` (`lib/parser/v2ray_parser.dart`)
  - Protocols: `vmess://`, `vless://`, `trojan://`, `ss://`, `socks://`
  - `Future<void> parse(String url)`
    - Throws `V2rayParserError` on invalid/unsupported URL.
  - `String json({int indent = 2})`
    - Returns full Xray configuration JSON. Requires `parse()` first.
  - Getters: `address`, `port`, `remark`, `fullConfiguration`, `outbound`

### 🔧 Parser Example

```dart
import 'package:flutter_v2ray_client_desktop/flutter_v2ray_client_desktop.dart';

final parser = V2rayParser();
await parser.parse('vmess://...');

final fullJson = parser.json();
final host = parser.address; // server address
final port = parser.port;    // server port
final name = parser.remark;  // optional remark

// Use the generated JSON with the client
await client.startV2Ray(
  config: fullJson,
  connectionType: ConnectionType.systemProxy,
);
```

## Logging and Status

- `logListener(String)` receives raw stdout/stderr from Xray/Sing-Box.
- `statusListener(V2rayStatus)` is called every second with:
  - `state`: `connected`/`disconnected`
  - `duration`: Xray uptime (derived from API)
  - `download`/`upload`: bytes per second (delta)
  - `totalDownload`/`totalUpload`: cumulative bytes

## Notes

- Binaries are expected in the plugin resources; they are invoked at runtime by the plugin. No extra install is needed in most cases.
- On Linux, system proxy changes use `gsettings` (GNOME). Other DEs may require manual configuration.
- On macOS, proxy controls target the Wi‑Fi interface via `networksetup`.
- On Windows, registry and WinHTTP settings are modified; environment variables `http_proxy`/`https_proxy` are also set for the session.

## License

See `LICENSE`.

