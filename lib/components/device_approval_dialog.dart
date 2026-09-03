import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';

class DeviceApprovalDialog extends ConsumerStatefulWidget {
  final int requestId;
  final String deviceName;
  final String platform;
  final String ip;
  final String? requestedAt;

  const DeviceApprovalDialog({
    super.key,
    required this.requestId,
    required this.deviceName,
    required this.platform,
    required this.ip,
    this.requestedAt,
  });

  static Future<bool?> show(
    BuildContext context, {
    required int requestId,
    required String deviceName,
    required String platform,
    required String ip,
    String? requestedAt,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DeviceApprovalDialog(
        requestId: requestId,
        deviceName: deviceName,
        platform: platform,
        ip: ip,
        requestedAt: requestedAt,
      ),
    );
  }

  @override
  ConsumerState<DeviceApprovalDialog> createState() => _DeviceApprovalDialogState();
}

class _DeviceApprovalDialogState extends ConsumerState<DeviceApprovalDialog> {
  bool _loading = false;
  String? _error;

  Future<void> _approve() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      await api.post('/auth/device-approval/${widget.requestId}/approve');
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to approve login: $e';
        });
      }
    }
  }

  Future<void> _deny() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      await api.post('/auth/device-approval/${widget.requestId}/deny');
      HapticFeedback.heavyImpact();
      if (mounted) Navigator.of(context).pop(false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to deny login: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return AlertDialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9500).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.security_rounded, color: Color(0xFFFF9500), size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'New Login Attempt',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: textPrimary),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A new device is attempting to sign into your MurihSpace account:',
            style: TextStyle(fontSize: 14, color: textSecondary),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('Device', widget.deviceName, Icons.devices_rounded, textPrimary),
                const SizedBox(height: 6),
                _infoRow('Platform', widget.platform.toUpperCase(), Icons.computer_rounded, textPrimary),
                const SizedBox(height: 6),
                _infoRow('IP Address', widget.ip, Icons.location_on_rounded, textPrimary),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 12),
            ),
          ],
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        if (_loading)
          const Center(child: CircularProgressIndicator.adaptive())
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF3B30),
                    side: const BorderSide(color: Color(0xFFFF3B30)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _deny,
                  child: const Text('Deny', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF34C759),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _approve,
                  child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _infoRow(String label, String value, IconData icon, Color textColor) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF007AFF)),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
