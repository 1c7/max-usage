import 'package:flutter/material.dart';

import 'screens/dashboard_screen.dart';
import 'screens/pairing_screen.dart';
import 'services/pairing_storage.dart';

void main() {
  runApp(const MaxUsageApp());
}

/// Read-only Android companion for the MaxUsage macOS app. All data comes from a paired Mac over
/// the local network (see `docs/lan-sync.md` in the main app repo) — this app has no accounts,
/// no provider credentials, and no settings beyond "which Mac am I paired with".
class MaxUsageApp extends StatefulWidget {
  const MaxUsageApp({super.key});

  @override
  State<MaxUsageApp> createState() => _MaxUsageAppState();
}

class _MaxUsageAppState extends State<MaxUsageApp> {
  final PairingStorage _storage = PairingStorage();
  PairedMac? _mac;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPairedMac();
  }

  Future<void> _loadPairedMac() async {
    final mac = await _storage.load();
    if (!mounted) return;
    setState(() {
      _mac = mac;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MaxUsage',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final mac = _mac;
    if (mac == null) {
      return PairingScreen(
        storage: _storage,
        onPaired: (mac) => setState(() => _mac = mac),
      );
    }
    return DashboardScreen(
      mac: mac,
      storage: _storage,
      onUnpaired: () => setState(() => _mac = null),
    );
  }
}
