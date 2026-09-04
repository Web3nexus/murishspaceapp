import 'package:shared_preferences/shared_preferences.dart';
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
    this.avatarColorHex = '0xFF007AFF',
    this.status = 'none',
    this.mutualCount = 0,
    this.isAlreadyFriend = false,
    this.requestId = 0,
  });

  factory MatchedContact.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? (json['is_friend'] == true ? 'accepted' : 'none');
    return MatchedContact(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'Contact',
      phone: json['phone'] as String? ?? json['mobile_number'] as String? ?? '',
      username: json['username'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? json['avatar'] as String?,
      avatarColorHex: json['avatar_color'] as String? ?? '0xFF007AFF',
      status: statusStr,
      mutualCount: (json['mutual_friends'] as num?)?.toInt() ?? 0,
      isAlreadyFriend: (json['is_friend'] as bool?) ?? (statusStr == 'accepted'),
      requestId: (json['request_id'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Service for handling Contact Permissions & Sync matching against backend.
class ContactsService {
  ContactsService._();
  static final ContactsService instance = ContactsService._();

  static const String _permissionKey = 'contacts_permission_status';

  Future<bool> hasPermission() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_permissionKey) ?? false;
  }

  Future<bool> requestPermission() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_permissionKey, true);
    return true;
  }

  /// Syncs real device contact phone numbers to backend for matching.
  /// If no contacts match, returns an empty list (NO hardcoded fake contacts).
  Future<List<MatchedContact>> syncContacts({
    List<Map<String, String>>? contacts,
    List<String>? phones,
  }) async {
    final dio = ApiClient.instance.dio;
    try {
      final payload = <String, dynamic>{};
      if (contacts != null && contacts.isNotEmpty) {
        payload['contacts'] = contacts;
      }
      if (phones != null && phones.isNotEmpty) {
        payload['phones'] = phones;
      }

      final response = await dio.post('/friends/contacts/sync', data: payload);
      final list = ApiClient.instance.unwrapList(response, (item) {
        return MatchedContact.fromJson(item);
      });
      return list;
    } catch (_) {
      return const [];
    }
  }
}

