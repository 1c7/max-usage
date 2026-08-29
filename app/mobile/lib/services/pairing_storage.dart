import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A Mac this phone has paired with: enough to poll `/v1/limits` without any further
/// configuration or sign-in on the phone.
class PairedMac {
  final String host;
  final int port;
  final String deviceToken;
  final String macName;

  const PairedMac({
    required this.host,
    required this.port,
    required this.deviceToken,
    required this.macName,
  });

  Uri limitsUri() => Uri.parse('http://$host:$port/v1/limits');
}

/// Persists the paired Mac's bearer token in the platform keystore (Android Keystore-backed
/// `EncryptedSharedPreferences` via `flutter_secure_storage`), so it survives app restarts
/// without the phone ever needing its own account or sign-in.
class PairingStorage {
  static const _storage = FlutterSecureStorage();
  static const _hostKey = 'lan_sync.host';
  static const _portKey = 'lan_sync.port';
  static const _tokenKey = 'lan_sync.device_token';
  static const _nameKey = 'lan_sync.mac_name';

  Future<PairedMac?> load() async {
    final host = await _storage.read(key: _hostKey);
    final portString = await _storage.read(key: _portKey);
    final token = await _storage.read(key: _tokenKey);
    if (host == null || portString == null || token == null) return null;
    final port = int.tryParse(portString);
    if (port == null) return null;
    final name = await _storage.read(key: _nameKey);
    return PairedMac(
      host: host,
      port: port,
      deviceToken: token,
      macName: name ?? 'Mac',
    );
  }

  Future<void> save(PairedMac mac) async {
    await _storage.write(key: _hostKey, value: mac.host);
    await _storage.write(key: _portKey, value: mac.port.toString());
    await _storage.write(key: _tokenKey, value: mac.deviceToken);
    await _storage.write(key: _nameKey, value: mac.macName);
  }

  Future<void> clear() async {
    await _storage.deleteAll();
  }
}
