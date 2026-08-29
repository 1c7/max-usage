import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/strings.dart';
import '../models/limits_response.dart';
import '../services/mac_client.dart';
import '../services/pairing_storage.dart';
import '../widgets/provider_card.dart';

/// The paired-Mac quota view: polls every 30s and shows the last-known snapshot even while
/// disconnected, rather than clearing the screen — the phone is a read-only mirror, not a live
/// guarantee. Body content only (no Scaffold/AppBar) — `MainScreen` owns those so the bottom tab bar
/// and title stay put while this tab's content refreshes underneath.
class DashboardScreen extends StatefulWidget {
  final PairedMac mac;
  final Strings strings;

  const DashboardScreen({super.key, required this.mac, required this.strings});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _pollInterval = Duration(seconds: 30);

  final MacClient _client = MacClient();
  Timer? _timer;
  LimitsResponse? _limits;
  String? _error;
  DateTime? _lastSuccessAt;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(_pollInterval, (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final limits = await _client.fetchLimits(widget.mac);
      if (!mounted) return;
      setState(() {
        _limits = limits;
        _error = null;
        _lastSuccessAt = DateTime.now();
        _isLoading = false;
      });
    } on MacClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(onRefresh: _refresh, child: _buildBody());
  }

  Widget _buildBody() {
    final strings = widget.strings;
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final limits = _limits;
    if (limits == null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.wifi_off, size: 48, color: Colors.grey[500]),
          const SizedBox(height: 16),
          Center(
            child: Text(_error ?? strings.notConnected, textAlign: TextAlign.center),
          ),
        ],
      );
    }

    // A provider the user enabled on the Mac but never actually fetched data for (no
    // credentials, never signed in) has no resources. The Mac's own dashboard doesn't show
    // those either — mirror that instead of rendering an empty "No data yet" card for it.
    final providers = limits.providers.values
        .where((provider) => provider.resources.isNotEmpty)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_error != null) _connectionBanner(strings),
        _lastUpdatedLabel(strings),
        if (providers.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Text(
                strings.noQuotasYet,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          )
        else
          _providerGrid(providers),
      ],
    );
  }

  /// Two columns instead of one full-width list, so a typical provider count fits on screen
  /// without scrolling. Cards vary in height (a provider's resource count differs), so this
  /// balances the columns by a rough height estimate rather than just alternating — a naive
  /// left/right/left/right split can easily stack every tall card into one column.
  Widget _providerGrid(List<ProviderLimits> providers) {
    final left = <ProviderLimits>[];
    final right = <ProviderLimits>[];
    var leftWeight = 0;
    var rightWeight = 0;
    for (final provider in providers) {
      final weight = provider.resources.length + 1;
      if (leftWeight <= rightWeight) {
        left.add(provider);
        leftWeight += weight;
      } else {
        right.add(provider);
        rightWeight += weight;
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [for (final provider in left) ProviderCard(provider: provider)],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            children: [for (final provider in right) ProviderCard(provider: provider)],
          ),
        ),
      ],
    );
  }

  Widget _connectionBanner(Strings strings) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(strings.notConnectedBanner, style: TextStyle(color: Colors.orange[900])),
          ),
        ],
      ),
    );
  }

  Widget _lastUpdatedLabel(Strings strings) {
    final lastSuccessAt = _lastSuccessAt;
    if (lastSuccessAt == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: _LiveRelativeTime(since: lastSuccessAt, strings: strings),
    );
  }
}

/// Ticks itself every second so "Updated Xs ago" visibly counts up, rather than sitting frozen on
/// "just now" for the entire minute before it would otherwise change — that read as broken even
/// though the data really was fresh.
class _LiveRelativeTime extends StatefulWidget {
  final DateTime since;
  final Strings strings;

  const _LiveRelativeTime({required this.since, required this.strings});

  @override
  State<_LiveRelativeTime> createState() => _LiveRelativeTimeState();
}

class _LiveRelativeTimeState extends State<_LiveRelativeTime> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      widget.strings.updated(_relativeTime(widget.since)),
      style: TextStyle(color: Colors.grey[600], fontSize: 12),
    );
  }

  String _relativeTime(DateTime time) {
    final strings = widget.strings;
    final seconds = DateTime.now().difference(time).inSeconds;
    if (seconds < 5) return strings.justNow;
    if (seconds < 60) return strings.secondsAgo(seconds);
    if (seconds < 3600) return strings.minutesAgo(seconds ~/ 60);
    return strings.hoursAgo(seconds ~/ 3600);
  }
}
