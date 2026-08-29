import 'package:flutter/material.dart';

import 'localization/strings.dart';
import 'screens/main_screen.dart';
import 'screens/pairing_screen.dart';
import 'services/pairing_storage.dart';
import 'services/settings_controller.dart';

void main() {
  runApp(const MaxUsageApp());
}

/// Read-only Android companion for the MaxUsage macOS app. All data comes from a paired Mac over
/// the local network (see `docs/lan-sync.md` in the main app repo) — this app has no accounts and
/// no provider credentials; its only settings are appearance, language, and which Mac it's paired
/// with.
class MaxUsageApp extends StatefulWidget {
  const MaxUsageApp({super.key});

  @override
  State<MaxUsageApp> createState() => _MaxUsageAppState();
}

class _MaxUsageAppState extends State<MaxUsageApp> {
  final PairingStorage _storage = PairingStorage();
  final SettingsController _settings = SettingsController();
  PairedMac? _mac;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([_storage.load(), _settings.load()]);
    if (!mounted) return;
    setState(() {
      _mac = results[0] as PairedMac?;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) {
        return MaterialApp(
          title: 'MaxUsage',
          debugShowCheckedModeBanner: false,
          themeMode: _settings.themeMode,
          theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
          darkTheme: ThemeData(
            colorSchemeSeed: Colors.deepPurple,
            brightness: Brightness.dark,
            useMaterial3: true,
          ),
          home: _buildHome(),
        );
      },
    );
  }

  Widget _buildHome() {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final strings = Strings(_settings.effectiveLanguage);
    final mac = _mac;
    if (mac == null) {
      return PairingScreen(
        storage: _storage,
        strings: strings,
        onPaired: (mac) => setState(() => _mac = mac),
      );
    }
    return MainScreen(
      mac: mac,
      storage: _storage,
      settings: _settings,
      onUnpaired: () => setState(() => _mac = null),
    );
  }
}
