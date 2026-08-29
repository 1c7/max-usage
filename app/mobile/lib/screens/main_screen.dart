import 'package:flutter/material.dart';

import '../localization/strings.dart';
import '../services/pairing_storage.dart';
import '../services/settings_controller.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';

/// The paired-phone shell: a bottom tab bar switching between the usage dashboard and settings.
/// Owns the single Scaffold/AppBar for both tabs so the bar and title stay in place while the tab
/// content underneath changes.
class MainScreen extends StatefulWidget {
  final PairedMac mac;
  final PairingStorage storage;
  final SettingsController settings;
  final VoidCallback onUnpaired;

  const MainScreen({
    super.key,
    required this.mac,
    required this.storage,
    required this.settings,
    required this.onUnpaired,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.settings,
      builder: (context, _) {
        final strings = Strings(widget.settings.effectiveLanguage);
        return Scaffold(
          appBar: AppBar(title: Text(_index == 0 ? strings.appTitle : strings.settingsTab)),
          body: IndexedStack(
            index: _index,
            children: [
              DashboardScreen(mac: widget.mac, strings: strings),
              SettingsScreen(
                settings: widget.settings,
                strings: strings,
                mac: widget.mac,
                storage: widget.storage,
                onUnpaired: widget.onUnpaired,
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (index) => setState(() => _index = index),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.dashboard_outlined),
                selectedIcon: const Icon(Icons.dashboard),
                label: strings.dashboardTab,
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                label: strings.settingsTab,
              ),
            ],
          ),
        );
      },
    );
  }
}
