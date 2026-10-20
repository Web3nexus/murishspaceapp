import 'dart:math' show min;

import 'package:flutter_contacts/flutter_contacts.dart';

import 'api_client.dart';

/// Contact model representing a phone contact matched on MurihSpace.
class MatchedContact {
  final int id;
  final String name;
  final String phone;
  final String username;
  final String? avatarUrl;
  final String avatarColorHex;
  final String status; // 'none', 'pending_sent', 'pending_received', 'accepted'
  final int mutualCount;
  final bool isAlreadyFriend;
  final int requestId;

  MatchedContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.username,
    this.avatarUrl,
    this.avatarColorHex = '0xFF38A8D8',
    this.status = 'none',
    this.mutualCount = 0,
    this.isAlreadyFriend = false,
    this.requestId = 0,
  });

  factory MatchedContact.fromJson(Map<String, dynamic> json) {
    final statusStr =
        json['status'] as String? ??
        (json['is_friend'] == true ? 'accepted' : 'none');
    return MatchedContact(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'Contact',
      phone: json['phone'] as String? ?? json['mobile_number'] as String? ?? '',
      username: json['username'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? json['avatar'] as String?,
      avatarColorHex: json['avatar_color'] as String? ?? '0xFF38A8D8',
      status: statusStr,
      mutualCount: (json['mutual_friends'] as num?)?.toInt() ?? 0,
      isAlreadyFriend:
          (json['is_friend'] as bool?) ?? (statusStr == 'accepted'),
      requestId: (json['request_id'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Reads the device address book and matches it against MurihSpace accounts.
///
/// Access is always asked for through the operating system. Nothing is read
/// until the OS reports read access, and a denial returns an empty result.
class ContactsService {
  ContactsService._();
  static final ContactsService instance = ContactsService._();

  /// Contacts sent per request, so large address books do not produce one huge body.
  static const int _batchSize = 500;

  /// Upper bound per sync, to keep a single sync bounded for very large books.
  static const int _maxEntries = 5000;

  /// Whether the OS currently grants read access to contacts.
  Future<bool> hasPermission() =>
      FlutterContacts.permissions.has(PermissionType.read);

  /// Asks the OS for read access. Returns true only when it is granted.
  Future<bool> requestPermission() async {
    final status = await FlutterContacts.permissions.request(
      PermissionType.read,
    );
    return status == PermissionStatus.granted ||
        status == PermissionStatus.limited;
  }

  /// Opens the system settings page, for users who denied access permanently.
  Future<void> openSettings() => FlutterContacts.permissions.openSettings();

  /// Reads name and phone number pairs from the device address book.
  Future<List<Map<String, String>>> readDeviceContacts() async {
    if (!await hasPermission()) return const [];

    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.name, ContactProperty.phone},
    );

    final entries = <Map<String, String>>[];
    for (final contact in contacts) {
      final name = contact.displayName ?? '';
      for (final phone in contact.phones) {
        final number = phone.number.trim();
        if (number.isEmpty) continue;
        entries.add({'name': name, 'phone': number});
        if (entries.length >= _maxEntries) return entries;
      }
    }
    return entries;
  }

  /// Matches contacts against MurihSpace accounts.
  ///
  /// With no arguments, the device address book is read first. Passing
  /// [contacts] or [phones] syncs exactly those entries instead.
  Future<List<MatchedContact>> syncContacts({
    List<Map<String, String>>? contacts,
    List<String>? phones,
  }) async {
    final fromDevice = contacts == null && phones == null;
    final entries = fromDevice
        ? await readDeviceContacts()
        : (contacts ?? const <Map<String, String>>[]);
    final extraPhones = phones ?? const <String>[];
    if (entries.isEmpty && extraPhones.isEmpty) return const [];

    final dio = ApiClient.instance.dio;
    final matches = <int, MatchedContact>{};
    final batches = entries.isEmpty
        ? <List<Map<String, String>>>[const []]
        : [
            for (var start = 0; start < entries.length; start += _batchSize)
              entries.sublist(start, min(start + _batchSize, entries.length)),
          ];
    try {
      for (var i = 0; i < batches.length; i++) {
        final payload = <String, dynamic>{};
        if (batches[i].isNotEmpty) payload['contacts'] = batches[i];
        // Plain phone strings are sent once, with the first batch.
        if (i == 0 && extraPhones.isNotEmpty) payload['phones'] = extraPhones;
        if (payload.isEmpty) continue;

        final response = await dio.post(
          '/friends/contacts/sync',
          data: payload,
        );
        final list = ApiClient.instance.unwrapList(
          response,
          MatchedContact.fromJson,
        );
        for (final match in list) {
          matches[match.id] = match;
        }
      }
    } catch (_) {
      // Keep what was matched before the failure; the caller shows what it has.
    }
    return matches.values.toList();
  }
}
