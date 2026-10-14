import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/api_client.dart';

/// "Link a device" — scan the QR code shown on the MurihSpace web login screen
/// and approve the desktop session from the trusted mobile app.
///
/// Flow: scan/enter code → POST /auth/qr/scan (claims the transaction) →
/// confirm the requesting device → POST /auth/qr/{id}/approve or /deny.
class LinkDeviceScreen extends ConsumerStatefulWidget {
  /// Optional token supplied by a `murihspace://qr-login?token=...` deep link.
  final String? initialToken;

  const LinkDeviceScreen({super.key, this.initialToken});

  @override
  ConsumerState<LinkDeviceScreen> createState() => _LinkDeviceScreenState();
}

enum _Stage { scanning, confirming, approved, denied }

class _LinkDeviceScreenState extends ConsumerState<LinkDeviceScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final TextEditingController _manualController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  _Stage _stage = _Stage.scanning;
  bool _busy = false;
  bool _showManual = false;
  String? _error;

  int? _transactionId;
  String _deviceName = 'Unknown device';
  String _platform = 'web';
  String _ip = '';
  String _location = '';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialToken;
    if (initial != null && initial.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _submitToken(initial.trim()));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _manualController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// Extracts the `token` query parameter from a QR payload, tolerating the
  /// `murihspace://` deep link, the web fallback URL, or a bare token string.
  String? _extractToken(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final uri = Uri.tryParse(value);
    if (uri != null) {
      final token = uri.queryParameters['token'];
      if (token != null && token.isNotEmpty) return token;
      if (uri.scheme == 'murihspace' && uri.host == 'qr-login') {
        // Malformed but recognisable — nothing to extract.
        return null;
      }
    }

    // Bare hex token (64 chars) as a last resort.
    if (RegExp(r'^[0-9a-fA-F]{32,128}$').hasMatch(value)) return value;
    return null;
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || _stage != _Stage.scanning) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final token = _extractToken(raw);
      if (token != null) {
        await _submitToken(token);
        return;
      }
    }
  }

  Future<void> _submitToken(String token) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final data = await api.unwrap(
        await api.post('/auth/qr/scan', data: {'qr_token': token}),
      );

      // The screen may have been popped while the request was in flight.
      if (!mounted) return;

      final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      final status = map['status']?.toString();
      final transactionId = (map['transaction_id'] as num?)?.toInt();
      if (status != 'scanned' || transactionId == null) {
        setState(() {
          _busy = false;
          _error = _messageForStatus(status);
        });
        return;
      }

      final device = map['device'] is Map
          ? Map<String, dynamic>.from(map['device'] as Map)
          : <String, dynamic>{};

      // A failure to stop the camera must not abort the already-claimed
      // transaction or surface as a "could not read code" error.
      try {
        await _controller.stop();
      } catch (_) {
        // Camera may already be stopping or disposed; ignore.
      }
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() {
        _transactionId = transactionId;
        _deviceName = device['device_name']?.toString() ?? 'Unknown device';
        _platform = device['platform']?.toString() ?? 'web';
        _ip = device['ip']?.toString() ?? '';
        _location = device['location']?.toString() ?? '';
        _stage = _Stage.confirming;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is ApiException ? e.message : 'Could not read that code. Try again.';
      });
    }
  }

  String _messageForStatus(String? status) {
    switch (status) {
      case 'invalid':
      case 'not_found':
        return 'This code is not valid. Refresh the QR code on your web browser and try again.';
      case 'expired':
        return 'This code has expired. Refresh the QR code on your web browser.';
      case 'approved':
      case 'consumed':
        return 'This code has already been used.';
      case 'denied':
        return 'This login was denied.';
      default:
        return 'Could not link this device. Please try again.';
    }
  }

  Future<void> _decide(bool approve) async {
    final id = _transactionId;
    if (id == null || _busy) return;

    final code = _codeController.text.replaceAll(RegExp(r'\D'), '');
    if (approve && code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code shown on the browser.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final path = approve ? '/auth/qr/$id/approve' : '/auth/qr/$id/deny';
      await api.unwrap(
        await api.post(path, data: approve ? {'confirmation_code': code} : null),
      );
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _stage = approve ? _Stage.approved : _Stage.denied;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is ApiException ? e.message : 'Something went wrong. Please try again.';
      });
    }
  }

  Future<void> _rescan() async {
    _codeController.clear();
    _manualController.clear();
    setState(() {
      _stage = _Stage.scanning;
      _error = null;
      _transactionId = null;
    });
    try {
      await _controller.start();
    } catch (_) {
      // Camera may be unavailable; the scanner's errorBuilder shows guidance.
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFF2F2F7);
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = (isDark ? Colors.grey[400] : Colors.grey[600]) ?? Colors.grey;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Link a device',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: switch (_stage) {
          _Stage.scanning => _buildScanner(textPrimary, textSecondary),
          _Stage.confirming => _buildConfirm(textPrimary, textSecondary),
          _Stage.approved => _buildResult(
              approved: true, textPrimary: textPrimary, textSecondary: textSecondary),
          _Stage.denied => _buildResult(
              approved: false, textPrimary: textPrimary, textSecondary: textSecondary),
        },
      ),
    );
  }

  Widget _buildScanner(Color textPrimary, Color textSecondary) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Open this screen on the browser where you want to sign in, then point your camera at the QR code.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary, fontSize: 14, height: 1.4),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  MobileScanner(
                    controller: _controller,
                    onDetect: _onDetect,
                    errorBuilder: (context, error) => _cameraError(error),
                  ),
                  IgnorePointer(
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  if (_busy)
                    Container(
                      color: Colors.black.withValues(alpha: 0.5),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              if (_showManual)
                TextField(
                  controller: _manualController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Paste the code from the browser',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onSubmitted: (value) {
                    final token = _extractToken(value);
                    if (token == null) {
                      setState(() => _error = 'That does not look like a valid code.');
                      return;
                    }
                    _submitToken(token);
                  },
                )
              else
                TextButton.icon(
                  onPressed: () => setState(() => _showManual = true),
                  icon: const Icon(Icons.keyboard_alt_outlined),
                  label: const Text('Enter code manually'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cameraError(MobileScannerException error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, size: 40, color: Colors.white70),
            const SizedBox(height: 12),
            Text(
              error.errorCode == MobileScannerErrorCode.permissionDenied
                  ? 'Camera permission is required to scan the QR code.'
                  : 'Camera unavailable on this device.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirm(Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Icon(Icons.computer_rounded, size: 56, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Approve this sign-in?',
            textAlign: TextAlign.center,
            style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'A browser is requesting access to your MurihSpace account.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _detailRow(Icons.devices_rounded, 'Device', _deviceName, textPrimary, textSecondary),
                const SizedBox(height: 12),
                _detailRow(Icons.laptop_mac_rounded, 'Platform', _platform, textPrimary, textSecondary),
                if (_ip.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _detailRow(Icons.public_rounded, 'IP address', _ip, textPrimary, textSecondary),
                ],
                if (_location.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _detailRow(Icons.place_rounded, 'Location', _location, textPrimary, textSecondary),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 8,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Confirmation code',
              hintText: '••••••',
              helperText: 'Enter the 6-digit code shown on the browser.',
              helperMaxLines: 2,
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onSubmitted: (_) => _decide(true),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Only approve if this request is yours and the code matches the browser screen. If you did not just try to sign in on a browser, deny it and secure your account.',
                    style: TextStyle(color: textSecondary, fontSize: 12, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
          FilledButton(
            onPressed: _busy ? null : () => _decide(true),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _busy
                ? const SizedBox(
                    height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Approve sign-in', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : () => _decide(false),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Deny'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, Color textPrimary, Color textSecondary) {
    return Row(
      children: [
        Icon(icon, size: 20, color: textSecondary),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: textSecondary, fontSize: 13)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildResult({required bool approved, required Color textPrimary, required Color textSecondary}) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            approved ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 72,
            color: approved ? Colors.green : Colors.redAccent,
          ),
          const SizedBox(height: 20),
          Text(
            approved ? 'Device linked' : 'Sign-in denied',
            style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            approved
                ? 'You can continue on your browser. Tap Done to finish here.'
                : 'The browser will not be signed in.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 32),
          if (!approved)
            FilledButton(
              onPressed: _rescan,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Scan another code'),
            )
          else
            OutlinedButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/app/chats');
                }
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Done'),
            ),
        ],
      ),
    );
  }
}
