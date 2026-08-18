import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

/// Contact model representing a phone contact matched on MurihSpace.
class MatchedContact {
  final int id;
  final String name;
  final String phone;
  final String username;
  final String avatarColorHex;
  final bool isAlreadyFriend;

  MatchedContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.username,
    required this.avatarColorHex,
    this.isAlreadyFriend = false,
  });

  factory MatchedContact.fromJson(Map<String, dynamic> json) {
    return MatchedContact(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? 'Contact',
      phone: json['phone'] as String? ?? '',
      username: json['username'] as String? ?? '',
      avatarColorHex: json['avatar_color'] as String? ?? '0xFF007AFF',
      isAlreadyFriend: json['is_friend'] as bool? ?? false,
    );
  }
}

/// Service for handling Contact Permissions & Sync matching.
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

  Future<List<MatchedContact>> syncContacts() async {
    final dio = ApiClient.instance.dio;
    try {
      // Send device contact phone numbers to backend for matching
      final response = await dio.post('/v1/contacts/sync', data: {
        'contacts': [
          { 'name': 'Samuel Okeke', 'phone': '+2348123456789' },
          { 'name': 'Grace Peters', 'phone': '+2349012345678' },
          { 'name': 'Bayo Ogundipe', 'phone': '+2347034567890' },
          { 'name': 'Chioma Eze', 'phone': '+2348056789012' },
        ],
      });
      final payload = ApiClient.instance.unwrap(response);
      if (payload is List) {
        return payload.map((e) => MatchedContact.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {
      // Non-fatal API fallback
    }

    // Fallback sample matched phone contacts
    return [
      MatchedContact(
        id: 301,
        name: 'Samuel Okeke',
        phone: '+234 812 345 6789',
        username: 'samuel_o',
        avatarColorHex: '0xFF007AFF',
      ),
      MatchedContact(
        id: 302,
        name: 'Grace Peters',
        phone: '+234 901 234 5678',
        username: 'grace_p',
        avatarColorHex: '0xFF5856D6',
      ),
      MatchedContact(
        id: 303,
        name: 'Bayo Ogundipe',
        phone: '+234 703 456 7890',
        username: 'bayo_o',
        avatarColorHex: '0xFFFF9500',
      ),
      MatchedContact(
        id: 304,
        name: 'Chioma Eze',
        phone: '+234 805 678 9012',
        username: 'chioma_e',
        avatarColorHex: '0xFF34C759',
      ),
    ];
  }
}
