import 'package:flutter/material.dart';

import '../localization/strings.dart';
import '../services/pairing_storage.dart';
import '../services/settings_controller.dart';

/// Appearance, language, a plain-language explanation of where the dashboard's data comes from and
/// how fresh it is, and the one destructive action this app has (unpairing).
class SettingsScreen extends StatelessWidget {
  final SettingsController settings;
  final Strings strings;
  final PairedMac mac;
  final PairingStorage storage;
  final VoidCallback onUnpaired;

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.strings,
    required this.mac,
    required this.storage,
    required this.onUnpaired,
  });

  Future<void> _confirmUnpair(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.unpairTitle),
        content: Text(strings.unpairBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel),
          ),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(strings.unpair)),
        ],
      ),
    );
    if (confirmed != true) return;
    await storage.clear();
    onUnpaired();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return ListView(
          children: [
            _sectionHeader(context, strings.appearance),
            RadioGroup<ThemeMode>(
              groupValue: settings.themeMode,
              onChanged: (value) {
                if (value != null) settings.setThemeMode(value);
              },
              child: Column(
                children: [
                  _themeTile(ThemeMode.system, strings.themeSystem),
                  _themeTile(ThemeMode.light, strings.themeLight),
                  _themeTile(ThemeMode.dark, strings.themeDark),
                ],
              ),
            ),
            const Divider(height: 32),
            _sectionHeader(context, strings.languageSectionTitle),
            RadioGroup<AppLanguage>(
              groupValue: settings.language,
              onChanged: (value) {
                if (value != null) settings.setLanguage(value);
              },
              child: Column(
                children: [
                  _languageTile(AppLanguage.system, strings.languageSystem),
                  _languageTile(AppLanguage.zh, strings.languageZh),
                  _languageTile(AppLanguage.en, strings.languageEn),
                ],
              ),
            ),
            const Divider(height: 32),
            _sectionHeader(context, strings.aboutData),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                strings.aboutDataBody,
                style: TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.5),
              ),
            ),
            const Divider(height: 32),
            ListTile(
              title: Text(strings.unpairedFrom),
              subtitle: Text(mac.macName),
            ),
            ListTile(
              leading: const Icon(Icons.link_off, color: Colors.red),
              title: Text(strings.unpair, style: const TextStyle(color: Colors.red)),
              onTap: () => _confirmUnpair(context),
            ),
          ],
        );
      },
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _themeTile(ThemeMode mode, String label) {
    return RadioListTile<ThemeMode>(value: mode, title: Text(label));
  }

  Widget _languageTile(AppLanguage language, String label) {
    return RadioListTile<AppLanguage>(value: language, title: Text(label));
  }
}
