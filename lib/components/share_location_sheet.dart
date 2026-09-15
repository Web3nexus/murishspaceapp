import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationShareData {
  final double latitude;
  final double longitude;
  final bool isLive;
  final int durationMinutes;
  final DateTime? expiresAt;
  final String title;

  const LocationShareData({
    required this.latitude,
    required this.longitude,
    required this.isLive,
    this.durationMinutes = 0,
    this.expiresAt,
    this.title = 'Location',
  });
}

/// WhatsApp-style Location Sharing sheet with Current & Live Location support.
class ShareLocationSheet extends StatefulWidget {
  final ValueChanged<LocationShareData> onShare;

  const ShareLocationSheet({super.key, required this.onShare});

  static Future<void> show(BuildContext context, {required ValueChanged<LocationShareData> onShare}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareLocationSheet(onShare: onShare),
    );
  }

  @override
  State<ShareLocationSheet> createState() => _ShareLocationSheetState();
}

class _ShareLocationSheetState extends State<ShareLocationSheet> {
  bool _loading = true;
  Position? _currentPosition;
  String? _error;
  int _selectedLiveMinutes = 60; // 1 hour default for live

  @override
  void initState() {
    super.initState();
    _requestAndGetLocation();
  }

  Future<void> _requestAndGetLocation() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final status = await Permission.location.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        if (mounted) {
          setState(() {
            _error = 'Location permission is required to share your location.';
            _loading = false;
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unable to determine current location. Please ensure GPS is enabled.';
          _loading = false;
        });
      }
    }
  }

  void _shareCurrent() {
    final pos = _currentPosition;
    if (pos == null) return;
    Navigator.of(context).pop();
    widget.onShare(LocationShareData(
      latitude: pos.latitude,
      longitude: pos.longitude,
      isLive: false,
      title: 'Current Location',
    ));
  }

  void _shareLive() {
    final pos = _currentPosition;
    if (pos == null) return;
    final expires = DateTime.now().add(Duration(minutes: _selectedLiveMinutes));
    Navigator.of(context).pop();
    widget.onShare(LocationShareData(
      latitude: pos.latitude,
      longitude: pos.longitude,
      isLive: true,
      durationMinutes: _selectedLiveMinutes,
      expiresAt: expires,
      title: 'Live Location',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
    final cardBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F4F7);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFCC00).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_on_rounded, color: Color(0xFFFF9500), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Share Location',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      'Share real-time or current GPS coordinates',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: textSecondary, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(strokeWidth: 2),
                    SizedBox(height: 12),
                    Text('Acquiring high-accuracy GPS signal…', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.location_off_rounded, size: 36, color: Color(0xFFFF3B30)),
                    const SizedBox(height: 8),
                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 13)),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: _requestAndGetLocation,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007AFF)),
                      child: const Text('Try Again', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Current Location Option
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                onTap: _shareCurrent,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF34C759),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 20),
                ),
                title: Text(
                  'Send Your Current Location',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary),
                ),
                subtitle: Text(
                  'Accurate to ${_currentPosition?.accuracy.round() ?? 10} meters',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 14),

            // Live Location Option with duration pills
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Color(0xFF007AFF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.radar_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Share Live Location',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary),
                            ),
                            Text(
                              'Updates automatically as you move',
                              style: TextStyle(fontSize: 12, color: textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'SHARE DURATION',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary, letterSpacing: 0.6),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _durationPill(label: '15 Mins', minutes: 15, isDark: isDark),
                      const SizedBox(width: 6),
                      _durationPill(label: '1 Hour', minutes: 60, isDark: isDark),
                      const SizedBox(width: 6),
                      _durationPill(label: '8 Hours', minutes: 480, isDark: isDark),
                      const SizedBox(width: 6),
                      _durationPill(label: '24 Hours', minutes: 1440, isDark: isDark),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _shareLive,
                      icon: const Icon(Icons.share_location_rounded, size: 18),
                      label: Text('Share Live Location for ${_durationText(_selectedLiveMinutes)}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _durationText(int mins) {
    if (mins < 60) return '$mins mins';
    final hrs = mins ~/ 60;
    return hrs == 1 ? '1 hour' : '$hrs hours';
  }

  Widget _durationPill({required String label, required int minutes, required bool isDark}) {
    final selected = _selectedLiveMinutes == minutes;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedLiveMinutes = minutes),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF007AFF)
                : (isDark ? const Color(0xFF3A3A3C) : Colors.white),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? const Color(0xFF007AFF) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                color: selected
                    ? Colors.white
                    : (isDark ? Colors.grey[300] : const Color(0xFF1E293B)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

