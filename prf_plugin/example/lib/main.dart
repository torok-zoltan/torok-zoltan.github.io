import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:prf_plugin/prf_plugin.dart';

void main() {
  runApp(const PrfExampleApp());
}

class PrfExampleApp extends StatelessWidget {
  const PrfExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PRF Plugin POC',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const PrfHomePage(),
    );
  }
}

class PrfHomePage extends StatefulWidget {
  const PrfHomePage({super.key});

  @override
  State<PrfHomePage> createState() => _PrfHomePageState();
}

enum PrfStatus { idle, running, success, error }

class _PrfHomePageState extends State<PrfHomePage> {
  PrfStatus _status = PrfStatus.idle;
  String _statusMessage = '';
  bool _isRegistered = false;
  bool _useFixedSalt = false;
  bool? _prfSupported;
  PrfResult? _lastResult;

  /// Fixed salt for determinism testing: 32 bytes of 0x01.
  /// Using a fixed salt with the same credential should always
  /// produce the same PRF output.
  static final _fixedSalt = Uint8List.fromList(List.filled(32, 0x01));

  @override
  void initState() {
    super.initState();
    _checkPrfSupport();
  }

  Future<void> _checkPrfSupport() async {
    try {
      final supported = await PrfPlugin.isPrfSupported();
      setState(() => _prfSupported = supported);
    } catch (_) {
      // Best-effort check; ignore errors
    }
  }

  Future<void> _registerPasskey() async {
    setState(() {
      _status = PrfStatus.running;
      _statusMessage = 'Registering passkey...';
      _lastResult = null;
    });
    try {
      final prfEnabled = await PrfPlugin.registerPasskey();
      setState(() {
        _isRegistered = true;
        _status = PrfStatus.success;
        _statusMessage = prfEnabled
            ? 'Passkey registered! PRF is supported.'
            : 'Passkey registered, but PRF may not be supported on this device.';
      });
    } on PrfError catch (e) {
      setState(() {
        _status = PrfStatus.error;
        _statusMessage = 'Registration failed: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _status = PrfStatus.error;
        _statusMessage = 'Unexpected error: $e';
      });
    }
  }

  Future<void> _derivePrf() async {
    setState(() {
      _status = PrfStatus.running;
      _statusMessage = 'Deriving PRF output...';
      _lastResult = null;
    });
    try {
      final result = await PrfPlugin.derivePrf(
        salt: _useFixedSalt ? _fixedSalt : null,
      );
      setState(() {
        _lastResult = result;
        _status = PrfStatus.success;
        _statusMessage = 'PRF output derived successfully!';
      });
    } on PrfError catch (e) {
      setState(() {
        _status = PrfStatus.error;
        _statusMessage = 'PRF derivation failed: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _status = PrfStatus.error;
        _statusMessage = 'Unexpected error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebAuthn PRF POC'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Platform support banner
            if (_prfSupported != null)
              Card(
                color: _prfSupported!
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        _prfSupported!
                            ? Icons.check_circle_outline
                            : Icons.warning_amber_outlined,
                        color: _prfSupported!
                            ? Colors.green
                            : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _prfSupported!
                              ? 'PRF is likely supported on this device.'
                              : 'PRF may not be supported on this device. '
                                  'Requires Android 14+ with Chrome 130+, '
                                  'or iOS 18+.',
                          style: TextStyle(
                            color: _prfSupported!
                                ? Colors.green.shade900
                                : Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Step 1: Register Passkey
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Step 1: Register Passkey',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text(
                      'Create a passkey with PRF extension enabled. '
                      'This step is needed once per RP ID.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _status == PrfStatus.running
                          ? null
                          : _registerPasskey,
                      icon: Icon(_isRegistered
                          ? Icons.check_circle
                          : Icons.fingerprint),
                      label: Text(_isRegistered
                          ? 'Re-register Passkey'
                          : 'Register Passkey'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Step 2: Derive PRF
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Step 2: Derive PRF',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text(
                      'Authenticate with the passkey to derive a '
                      'pseudo-random value using the PRF extension.',
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('Use fixed salt'),
                      subtitle: const Text(
                        'For determinism testing — same salt should '
                        'produce same PRF output every time.',
                      ),
                      value: _useFixedSalt,
                      onChanged: (v) => setState(() => _useFixedSalt = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _status == PrfStatus.running
                          ? null
                          : _derivePrf,
                      icon: const Icon(Icons.vpn_key),
                      label: const Text('Generate PRF'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Status display
            Card(
              color: _statusColor,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _statusIcon,
                        const SizedBox(width: 8),
                        Text(
                          'Status: ${_status.name}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                    if (_statusMessage.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(_statusMessage),
                    ],
                  ],
                ),
              ),
            ),

            // PRF Result display
            if (_lastResult != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PRF Result',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      _resultRow(
                        'Byte Length',
                        '${_lastResult!.prfOutput.length} bytes',
                      ),
                      _resultRow(
                        'Base64url',
                        _lastResult!.prfOutputBase64Url,
                      ),
                      _resultRow(
                        'Hex (full)',
                        _lastResult!.prfOutputHex,
                      ),
                      _resultRow(
                        'Hex Preview (first 16 bytes)',
                        _lastResult!.prfOutputHexPreview,
                      ),
                      const Divider(),
                      _resultRow(
                        'Salt (base64url)',
                        _lastResult!.saltBase64Url,
                      ),
                      if (_lastResult!.credentialId != null)
                        _resultRow(
                          'Credential ID',
                          _lastResult!.credentialId!,
                        ),
                    ],
                  ),
                ),
              ),
            ],

            // Extra bottom spacing for devices with gesture bars
            const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ],
      ),
    );
  }

  Color get _statusColor => switch (_status) {
        PrfStatus.idle => Colors.grey.shade100,
        PrfStatus.running => Colors.blue.shade50,
        PrfStatus.success => Colors.green.shade50,
        PrfStatus.error => Colors.red.shade50,
      };

  Widget get _statusIcon => switch (_status) {
        PrfStatus.idle =>
          const Icon(Icons.hourglass_empty, color: Colors.grey),
        PrfStatus.running => const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2)),
        PrfStatus.success =>
          const Icon(Icons.check_circle, color: Colors.green),
        PrfStatus.error => const Icon(Icons.error, color: Colors.red),
      };
}
