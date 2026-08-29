import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maxusage_mobile/models/limits_response.dart';
import 'package:maxusage_mobile/widgets/provider_card.dart';

void main() {
  testWidgets('ProviderCard renders a consumption resource as a progress row', (
    tester,
  ) async {
    final provider = ProviderLimits(
      id: 'claude',
      displayName: 'Claude',
      plan: 'Pro 5x',
      stale: false,
      resources: {
        'session': ResourceLimit(
          key: 'session',
          kind: 'consumption',
          unit: 'percent',
          used: 42,
          limit: 100,
          remaining: 58,
          utilization: 0.42,
        ),
      },
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ProviderCard(provider: provider))),
    );

    expect(find.text('Claude'), findsOneWidget);
    expect(find.text('Pro 5x'), findsOneWidget);
    expect(find.text('Session'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
  });

  testWidgets('ProviderCard renders a balance resource as available/unit', (
    tester,
  ) async {
    final provider = ProviderLimits(
      id: 'openrouter',
      displayName: 'OpenRouter',
      plan: null,
      stale: false,
      resources: {
        'credits': ResourceLimit(
          key: 'credits',
          kind: 'balance',
          unit: 'credits',
          available: 821,
        ),
      },
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ProviderCard(provider: provider))),
    );

    expect(find.text('Credits'), findsOneWidget);
    expect(find.text('821 credits'), findsOneWidget);
  });

  testWidgets('ProviderCard shows a placeholder when a provider has no data yet', (
    tester,
  ) async {
    final provider = ProviderLimits(
      id: 'devin',
      displayName: 'Devin',
      plan: null,
      stale: false,
      resources: const {},
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ProviderCard(provider: provider))),
    );

    expect(find.text('No data yet'), findsOneWidget);
  });
}
