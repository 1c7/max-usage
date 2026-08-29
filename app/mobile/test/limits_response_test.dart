import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxusage_mobile/models/limits_response.dart';

void main() {
  // Sample lifted from docs/local-http-api.md in the main app repo — the exact shape the Mac's
  // LAN Sync `/v1/limits` route serves.
  const sampleJson = '''
  {
    "schema": "openusage.limits.v1",
    "generatedAt": "2026-07-13T01:40:00.000Z",
    "providers": {
      "codex": {
        "displayName": "Codex",
        "plan": "Pro 20x",
        "fetchedAt": "2026-07-13T01:39:30.000Z",
        "expiresAt": "2026-07-13T01:44:30.000Z",
        "stale": false,
        "resources": {
          "session": {
            "kind": "consumption",
            "unit": "percent",
            "used": 42,
            "limit": 100,
            "remaining": 58,
            "utilization": 0.42,
            "resetsAt": "2026-07-13T06:00:00.000Z",
            "windowSeconds": 18000
          },
          "credits": {
            "kind": "balance",
            "unit": "credits",
            "available": 821
          }
        }
      }
    },
    "errors": [{"providerId": "grok", "message": "auth expired"}]
  }
  ''';

  test('parses providers and both resource kinds', () {
    final response = LimitsResponse.fromJson(
      jsonDecode(sampleJson) as Map<String, dynamic>,
    );

    expect(response.generatedAt, DateTime.parse('2026-07-13T01:40:00.000Z'));
    expect(response.providers.keys, ['codex']);
    expect(response.errors, hasLength(1));
    expect(response.errors.single.providerId, 'grok');

    final codex = response.providers['codex']!;
    expect(codex.displayName, 'Codex');
    expect(codex.plan, 'Pro 20x');
    expect(codex.stale, isFalse);
    expect(codex.resources.keys, containsAll(['session', 'credits']));

    final session = codex.resources['session']!;
    expect(session.kind, 'consumption');
    expect(session.used, 42);
    expect(session.utilization, 0.42);
    expect(session.label, 'Session');

    final credits = codex.resources['credits']!;
    expect(credits.kind, 'balance');
    expect(credits.available, 821);
  });

  test('humanizes camelCase resource keys into readable labels', () {
    final resource = ResourceLimit.fromJson('geminiSession', const {
      'kind': 'consumption',
      'unit': 'percent',
    });
    expect(resource.label, 'Gemini Session');
  });

  test('tolerates a missing providers/errors object', () {
    final response = LimitsResponse.fromJson(const {
      'schema': 'openusage.limits.v1',
      'generatedAt': '2026-07-13T01:40:00.000Z',
    });
    expect(response.providers, isEmpty);
    expect(response.errors, isEmpty);
  });

  test('falls back to the provider id when displayName is missing', () {
    final response = LimitsResponse.fromJson(const {
      'generatedAt': '2026-07-13T01:40:00.000Z',
      'providers': {
        'devin': {'stale': false, 'resources': {}},
      },
    });
    expect(response.providers['devin']!.displayName, 'devin');
  });
}
