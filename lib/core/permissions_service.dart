import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppPermissionType {
  notifications,
  camera,
  microphone,
  photos,
  contacts,
  location,
  biometrics,
}

class PermissionStatusState {
  final bool notificationsGranted;
  final bool cameraGranted;
  final bool microphoneGranted;
  final bool photosGranted;
  final bool contactsGranted;
  final bool locationGranted;
  final bool biometricsGranted;

  const PermissionStatusState({
    this.notificationsGranted = false,
    this.cameraGranted = false,
    this.microphoneGranted = false,
    this.photosGranted = false,
    this.contactsGranted = false,
    this.locationGranted = false,
    this.biometricsGranted = false,
  });

  PermissionStatusState copyWith({
    bool? notificationsGranted,
    bool? cameraGranted,
    bool? microphoneGranted,
    bool? photosGranted,
    bool? contactsGranted,
    bool? locationGranted,
    bool? biometricsGranted,
  }) {
    return PermissionStatusState(
      notificationsGranted: notificationsGranted ?? this.notificationsGranted,
      cameraGranted: cameraGranted ?? this.cameraGranted,
      microphoneGranted: microphoneGranted ?? this.microphoneGranted,
      photosGranted: photosGranted ?? this.photosGranted,
      contactsGranted: contactsGranted ?? this.contactsGranted,
      locationGranted: locationGranted ?? this.locationGranted,
      biometricsGranted: biometricsGranted ?? this.biometricsGranted,
    );
  }
}

class PermissionsNotifier extends Notifier<PermissionStatusState> {
  static const String _notificationsKey = 'perm_notifications_prompted';
  static const String _cameraKey = 'perm_camera_prompted';
  static const String _micKey = 'perm_mic_prompted';
  static const String _photosKey = 'perm_photos_prompted';
  static const String _contactsKey = 'perm_contacts_prompted';
  static const String _locationKey = 'perm_location_prompted';

  @override
  PermissionStatusState build() {
    _loadStoredStates();
    return const PermissionStatusState();
  }

  Future<void> _loadStoredStates() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      notificationsGranted: prefs.getBool(_notificationsKey) ?? false,
      cameraGranted: prefs.getBool(_cameraKey) ?? false,
      microphoneGranted: prefs.getBool(_micKey) ?? false,
      photosGranted: prefs.getBool(_photosKey) ?? false,
      contactsGranted: prefs.getBool(_contactsKey) ?? false,
      locationGranted: prefs.getBool(_locationKey) ?? false,
    );
  }

  Future<bool> requestPermission(BuildContext context, AppPermissionType type) async {
    final prefs = await SharedPreferences.getInstance();
    switch (type) {
      case AppPermissionType.notifications:
        await prefs.setBool(_notificationsKey, true);
        state = state.copyWith(notificationsGranted: true);
        return true;
      case AppPermissionType.camera:
        await prefs.setBool(_cameraKey, true);
        state = state.copyWith(cameraGranted: true);
        return true;
      case AppPermissionType.microphone:
        await prefs.setBool(_micKey, true);
        state = state.copyWith(microphoneGranted: true);
        return true;
      case AppPermissionType.photos:
        await prefs.setBool(_photosKey, true);
        state = state.copyWith(photosGranted: true);
        return true;
      case AppPermissionType.contacts:
        await prefs.setBool(_contactsKey, true);
        state = state.copyWith(contactsGranted: true);
        return true;
      case AppPermissionType.location:
        await prefs.setBool(_locationKey, true);
        state = state.copyWith(locationGranted: true);
        return true;
      case AppPermissionType.biometrics:
        state = state.copyWith(biometricsGranted: true);
        return true;
    }
  }

  /// Show a rationale sheet before requesting critical permissions
  Future<bool> showPermissionRationaleSheet({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required AppPermissionType type,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        final bg = isDark ? const Color(0xFF161F2E) : Colors.white;
        final fg = isDark ? Colors.white : const Color(0xFF0F172A);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFF09A3E).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFFF09A3E), size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Not Now',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF09A3E),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Allow',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(ctx).padding.bottom),
            ],
          ),
        );
      },
    );

    if (result == true) {
      return requestPermission(context, type);
    }
    return false;
  }

  Future<bool> ensureCamera(BuildContext context) async {
    if (state.cameraGranted) return true;
    return showPermissionRationaleSheet(
      context: context,
      title: 'Camera Access Needed',
      description: 'MurihSpace requires camera access to take photos, record stories, and join video calls.',
      icon: Icons.camera_alt_rounded,
      type: AppPermissionType.camera,
    );
  }

  Future<bool> ensurePhotos(BuildContext context) async {
    if (state.photosGranted) return true;
    return showPermissionRationaleSheet(
      context: context,
      title: 'Photo Library Access',
      description: 'MurihSpace needs photo library access to upload avatars, banners, post media, and product images.',
      icon: Icons.photo_library_rounded,
      type: AppPermissionType.photos,
    );
  }

  Future<bool> ensureMicrophone(BuildContext context) async {
    if (state.microphoneGranted) return true;
    return showPermissionRationaleSheet(
      context: context,
      title: 'Microphone Access',
      description: 'MurihSpace needs microphone access to record voice notes and participate in live audio spaces.',
      icon: Icons.mic_rounded,
      type: AppPermissionType.microphone,
    );
  }

  Future<bool> ensureContacts(BuildContext context) async {
    if (state.contactsGranted) return true;
    return showPermissionRationaleSheet(
      context: context,
      title: 'Contacts Sync & Discovery',
      description: 'MurihSpace securely hashes and matches your address book to connect you with friends, creators, and vendors already on the platform.',
      icon: Icons.contacts_rounded,
      type: AppPermissionType.contacts,
    );
  }

  Future<bool> ensureLocation(BuildContext context) async {
    if (state.locationGranted) return true;
    return showPermissionRationaleSheet(
      context: context,
      title: 'Location Permission',
      description: 'MurihSpace uses your location to show local marketplace items and nearby community members.',
      icon: Icons.location_on_rounded,
      type: AppPermissionType.location,
    );
  }

  Future<bool> ensureNotifications(BuildContext context) async {
    if (state.notificationsGranted) return true;
    return showPermissionRationaleSheet(
      context: context,
      title: 'Enable Notifications',
      description: 'Get instant alerts for messages, escrow updates, friend requests, and order notifications.',
      icon: Icons.notifications_active_rounded,
      type: AppPermissionType.notifications,
    );
  }
}

final permissionsProvider =
    NotifierProvider<PermissionsNotifier, PermissionStatusState>(PermissionsNotifier.new);

