import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/mac_client.dart';
import '../services/pairing_storage.dart';

/// The only setup step this app ever asks for: scan the QR code MaxUsage shows on the Mac
/// (Settings → Allow Phone Sync → Add Phone…) to exchange it for a bearer token. No account, no
/// server address to type in.
class PairingScreen extends StatefulWidget {
  final PairingStorage storage;
  final void Function(PairedMac mac) onPaired;

  const PairingScreen({super.key, required this.storage, required this.onPaired});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final MacClient _client = MacClient();
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _isPairing = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_isPairing || capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null) return;

    setState(() {
      _isPairing = true;
      _error = null;
    });
    try {
      final mac = await _client.pair(raw, deviceName: _deviceName());
      await widget.storage.save(mac);
      if (!mounted) return;
      widget.onPaired(mac);
    } on MacClientException catch (e) {
      setState(() {
        _error = e.message;
        _isPairing = false;
      });
    }
  }

  String _deviceName() => Platform.isAndroid ? 'Android Phone' : 'Phone';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pair with Mac')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(controller: _controller, onDetect: _handleDetect),
                if (_isPairing)
                  Container(
                    color: Colors.black54,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  'On your Mac: Settings → Allow Phone Sync → Add Phone…\nThen scan the code shown there.',
                  textAlign: TextAlign.center,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
