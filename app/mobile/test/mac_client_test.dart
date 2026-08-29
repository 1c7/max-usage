import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maxusage_mobile/services/mac_client.dart';
import 'package:maxusage_mobile/services/pairing_storage.dart';

void main() {
  const validQr =
      '{"v":1,"host":"192.168.1.5","port":6737,"token":"abc123","name":"Cheng’s Mac"}';

  group('pair', () {
    test('returns a PairedMac on success', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), 'http://192.168.1.5:6737/v1/pair');
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['pairingToken'], 'abc123');
        expect(body['deviceName'], 'Test Phone');
        return http.Response(
          jsonEncode({'deviceToken': 'device-token-1', 'macName': "Cheng's Mac"}),
          200,
        );
      });

      final mac = await MacClient(client: client).pair(
        validQr,
        deviceName: 'Test Phone',
      );

      expect(mac.host, '192.168.1.5');
      expect(mac.port, 6737);
      expect(mac.deviceToken, 'device-token-1');
      expect(mac.macName, "Cheng's Mac");
    });

    test('throws for a QR payload that is not JSON', () async {
      final client = MockClient((request) async => http.Response('', 200));
      expect(
        () => MacClient(client: client).pair('not json', deviceName: 'Phone'),
        throwsA(isA<MacClientException>()),
      );
    });

    test('throws for a QR payload missing required fields', () async {
      final client = MockClient((request) async => http.Response('', 200));
      expect(
        () => MacClient(
          client: client,
        ).pair('{"v":1,"host":"1.2.3.4"}', deviceName: 'Phone'),
        throwsA(isA<MacClientException>()),
      );
    });

    test('surfaces a specific message on 403 (expired/used token)', () async {
      final client = MockClient((request) async => http.Response('', 403));
      await expectLater(
        MacClient(client: client).pair(validQr, deviceName: 'Phone'),
        throwsA(
          isA<MacClientException>().having(
            (e) => e.message,
            'message',
            contains('expired'),
          ),
        ),
      );
    });
  });

  group('fetchLimits', () {
    final mac = PairedMac(
      host: '192.168.1.5',
      port: 6737,
      deviceToken: 'device-token-1',
      macName: "Cheng's Mac",
    );

    test('sends the bearer token and parses the response', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), 'http://192.168.1.5:6737/v1/limits');
        expect(request.headers['Authorization'], 'Bearer device-token-1');
        return http.Response(
          jsonEncode({
            'generatedAt': '2026-07-13T01:40:00.000Z',
            'providers': <String, dynamic>{},
            'errors': <dynamic>[],
          }),
          200,
        );
      });

      final limits = await MacClient(client: client).fetchLimits(mac);
      expect(limits.providers, isEmpty);
    });

    test('throws a specific message on 401 (revoked pairing)', () async {
      final client = MockClient((request) async => http.Response('', 401));
      await expectLater(
        MacClient(client: client).fetchLimits(mac),
        throwsA(
          isA<MacClientException>().having(
            (e) => e.message,
            'message',
            contains('no longer paired'),
          ),
        ),
      );
    });
  });
}
