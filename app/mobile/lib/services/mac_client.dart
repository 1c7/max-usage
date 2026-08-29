import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/limits_response.dart';
import 'pairing_storage.dart';

/// A user-facing failure talking to the Mac — network, pairing, or auth. `message` is safe to
/// show directly in the UI.
class MacClientException implements Exception {
  final String message;
  MacClientException(this.message);

  @override
  String toString() => message;
}

class _PairingIntent {
  final String host;
  final int port;
  final String pairingToken;
  final String macName;

  _PairingIntent({
    required this.host,
    required this.port,
    required this.pairingToken,
    required this.macName,
  });
}

/// Talks to a single Mac's LAN Sync listener (see `docs/lan-sync.md` in the main app repo):
/// exchanging a scanned pairing QR for a bearer token, then polling `/v1/limits` with it.
class MacClient {
  final http.Client _client;
  static const _timeout = Duration(seconds: 8);

  MacClient({http.Client? client}) : _client = client ?? http.Client();

  static _PairingIntent _parseQrPayload(String raw) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      throw MacClientException("That QR code isn't a MaxUsage pairing code.");
    }
    final host = json['host'] as String?;
    final port = json['port'] as int?;
    final token = json['token'] as String?;
    if (host == null || port == null || token == null) {
      throw MacClientException("That QR code isn't a MaxUsage pairing code.");
    }
    return _PairingIntent(
      host: host,
      port: port,
      pairingToken: token,
      macName: json['name'] as String? ?? 'Mac',
    );
  }

  /// Exchanges a scanned QR payload for a long-lived bearer token via `POST /v1/pair`.
  Future<PairedMac> pair(String qrPayload, {required String deviceName}) async {
    final intent = _parseQrPayload(qrPayload);
    final uri = Uri.parse('http://${intent.host}:${intent.port}/v1/pair');
    final response = await _post(
      uri,
      body: {'pairingToken': intent.pairingToken, 'deviceName': deviceName},
    );

    if (response.statusCode == 403) {
      throw MacClientException(
        'This code expired or was already used. Generate a new one on your Mac.',
      );
    }
    if (response.statusCode != 200) {
      throw MacClientException(
        "Couldn't pair (${response.statusCode}). Make sure your phone and Mac are on the same Wi-Fi.",
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final deviceToken = body['deviceToken'] as String?;
    if (deviceToken == null) {
      throw MacClientException('Unexpected response from Mac.');
    }
    return PairedMac(
      host: intent.host,
      port: intent.port,
      deviceToken: deviceToken,
      macName: body['macName'] as String? ?? intent.macName,
    );
  }

  /// Polls the paired Mac for its current usage snapshot.
  Future<LimitsResponse> fetchLimits(PairedMac mac) async {
    final response = await _get(
      mac.limitsUri(),
      headers: {'Authorization': 'Bearer ${mac.deviceToken}'},
    );
    if (response.statusCode == 401) {
      throw MacClientException(
        'This phone is no longer paired with your Mac.',
      );
    }
    if (response.statusCode != 200) {
      throw MacClientException("Couldn't reach your Mac (${response.statusCode}).");
    }
    return LimitsResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<http.Response> _post(Uri uri, {required Map<String, dynamic> body}) async {
    try {
      return await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } catch (_) {
      throw MacClientException(
        "Couldn't reach your Mac. Make sure it's on and on the same Wi-Fi.",
      );
    }
  }

  Future<http.Response> _get(Uri uri, {required Map<String, String> headers}) async {
    try {
      return await _client.get(uri, headers: headers).timeout(_timeout);
    } catch (_) {
      throw MacClientException(
        "Couldn't reach your Mac. Make sure it's on and on the same Wi-Fi.",
      );
    }
  }
}
