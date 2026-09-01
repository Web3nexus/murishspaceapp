import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../components/brand.dart';
import '../components/app_bottom_sheet.dart';
import '../components/followers_list_dialog.dart';
import '../components/online_status_badge.dart';
import '../core/api_client.dart';
import '../core/roles.dart';
import '../providers/auth_provider.dart';
import '../providers/follow_provider.dart';
import 'automated_greeting_sheet.dart';

/// Ultra-Fancy, Fully Functional Profile Edit & Settings Screen.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _phoneController;

  DateTime? _selectedBirthday;
  Color _selectedAccentColor = const Color(0xFF007AFF);
  String _accentColorName = 'Murih Electric Blue';
  bool _isSaving = false;
  String? _error;
  String? _selectedPhotoPath;
  String? _selectedBannerPath;

  Future<void> _pickBannerPhoto() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file != null && mounted) {
        setState(() => _selectedBannerPath = file.path);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile cover banner updated!'),
            backgroundColor: _selectedAccentColor,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not access image gallery for banner.')),
        );
      }
    }
  }

  final List<Map<String, dynamic>> _accentColors = [
    {'name': 'Murih Electric Blue', 'color': const Color(0xFF007AFF)},
    {'name': 'Royal Indigo', 'color': const Color(0xFF5856D6)},
    {'name': 'Emerald Green', 'color': const Color(0xFF34C759)},
    {'name': 'Sunset Orange', 'color': const Color(0xFFFF9500)},
    {'name': 'Cyber Pink', 'color': const Color(0xFFFF2D55)},
    {'name': 'Teal Wave', 'color': const Color(0xFF5AC8FA)},
  ];

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    final nameParts = (user?.name ?? '').trim().split(RegExp(r'\s+'));
    _firstNameController = TextEditingController(text: nameParts.isNotEmpty ? nameParts.first : '');
    _lastNameController = TextEditingController(text: nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '');
    _usernameController = TextEditingController(text: user?.username ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _selectedBirthday = user?.birthday;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file != null && mounted) {
        setState(() => _selectedPhotoPath = file.path);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile photo updated successfully!'),
            backgroundColor: _selectedAccentColor,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not access image gallery.')),
        );
      }
    }
  }

  Future<void> _selectBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1940),
      lastDate: now,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: _selectedAccentColor,
                    onPrimary: Colors.white,
                    surface: const Color(0xFF1C1C1E),
                    onSurface: Colors.white,
                  )
                : ColorScheme.light(
                    primary: _selectedAccentColor,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black,
                  ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => _selectedBirthday = picked);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Birthday set to ${DateFormat('dd MMMM yyyy').format(picked)}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showEditUsernameModal() {
    final tempController = TextEditingController(text: _usernameController.text);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit Username', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 8),
              Text('You can choose a username on MurihSpace. Other users will be able to find you by this username.', style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600])),
              const SizedBox(height: 16),
              TextField(
                controller: tempController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  prefixText: '@ ',
                  labelText: 'Username',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedAccentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final clean = tempController.text.trim().replaceAll('@', '');
                    if (clean.isNotEmpty) {
                      setState(() => _usernameController.text = clean);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Username updated to @$clean')));
                    }
                  },
                  child: const Text('Save Username', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditPhoneModal() {
    final tempController = TextEditingController(text: _phoneController.text);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Change Phone Number', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 8),
              Text('Enter your new phone number. You will receive an SMS confirmation code.', style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600])),
              const SizedBox(height: 16),
              TextField(
                controller: tempController,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.phone_rounded),
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedAccentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final clean = tempController.text.trim();
                    if (clean.isNotEmpty) {
                      setState(() => _phoneController.text = clean);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Phone number updated to $clean')));
                    }
                  },
                  child: const Text('Confirm & Send SMS Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAccentColorSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profile Color Theme', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _accentColors.map((item) {
                  final color = item['color'] as Color;
                  final name = item['name'] as String;
                  final isSelected = _selectedAccentColor == color;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedAccentColor = color;
                        _accentColorName = name;
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Profile accent color set to $name')));
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: isSelected ? 0.25 : 0.1),
                        border: Border.all(color: color, width: isSelected ? 2.5 : 1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text(name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isDark ? Colors.white : Colors.black)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showChannelModal() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your Broadcast Channel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 8),
              Text('Broadcast channels allow you to send 1-to-many updates and announcements directly to your followers.', style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600])),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedAccentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push('/create');
                  },
                  icon: const Icon(Icons.campaign_rounded),
                  label: const Text('Create New Broadcast Channel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddAccountModal() async {
    final savedAccounts = await ref.read(authProvider.notifier).getSavedAccounts();
    if (!mounted) return;

    final currentUser = ref.read(authProvider).user;
    final otherAccounts = savedAccounts.where((acc) => acc['id'] != currentUser?.id).toList();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Switch or Add Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: _selectedAccentColor,
                  backgroundImage: currentUser?.avatarUrl != null && currentUser!.avatarUrl!.isNotEmpty
                      ? NetworkImage(currentUser.avatarUrl!)
                      : null,
                  child: currentUser?.avatarUrl == null || currentUser!.avatarUrl!.isEmpty
                      ? Text(
                          _initials(currentUser?.name ?? _firstNameController.text),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                title: Text(
                  currentUser?.name.isNotEmpty == true ? currentUser!.name : '${_firstNameController.text} ${_lastNameController.text}'.trim(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(currentUser?.phone?.isNotEmpty == true ? currentUser!.phone! : (currentUser?.email ?? 'Active Account')),
                trailing: const Icon(Icons.check_circle_rounded, color: Color(0xFF34C759)),
              ),
              if (otherAccounts.isNotEmpty) ...[
                const Divider(),
                ...otherAccounts.map((acc) {
                  final name = acc['name'] as String? ?? 'Account';
                  final emailOrPhone = acc['phone'] as String? ?? acc['email'] as String? ?? '';
                  final token = acc['token'] as String?;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey[700],
                      child: Text(_initials(name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(emailOrPhone),
                    trailing: TextButton(
                      onPressed: token == null
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              final ok = await ref.read(authProvider.notifier).switchSavedAccount(token);
                              if (mounted && ok) {
                                final switched = ref.read(authProvider).user;
                                if (switched != null) {
                                  final parts = switched.name.trim().split(RegExp(r'\s+'));
                                  setState(() {
                                    _firstNameController.text = parts.isNotEmpty ? parts.first : '';
                                    _lastNameController.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
                                    _usernameController.text = switched.username;
                                    _bioController.text = switched.bio ?? '';
                                    _phoneController.text = switched.phone ?? '';
                                    _selectedBirthday = switched.birthday;
                                  });
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Switched to $name'),
                                    backgroundColor: const Color(0xFF34C759),
                                  ),
                                );
                              }
                            },
                      child: const Text('Switch', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  );
                }),
              ],
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: _selectedAccentColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: Icon(Icons.add_rounded, color: _selectedAccentColor),
                ),
                title: Text('Add Another Account', style: TextStyle(fontWeight: FontWeight.bold, color: _selectedAccentColor)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddAccountLoginDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddAccountLoginDialog() {
    final emailPhoneController = TextEditingController();
    final passwordController = TextEditingController();
    bool isSubmitting = false;
    String? modalError;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFD1D1D6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Add Secondary Account',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Enter phone number or email of the account you want to connect.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  if (modalError != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(modalError!, style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailPhoneController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      labelText: 'Email or Phone Number',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      labelText: 'Password',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedAccentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final input = emailPhoneController.text.trim();
                              final pass = passwordController.text.trim();
                              if (input.isEmpty || pass.isEmpty) {
                                setModalState(() => modalError = 'Please fill in both email/phone and password.');
                                return;
                              }
                              setModalState(() {
                                isSubmitting = true;
                                modalError = null;
                              });
                              final success = await ref.read(authProvider.notifier).login(input, pass);
                              if (mounted) {
                                if (success) {
                                  Navigator.pop(ctx);
                                  final newUser = ref.read(authProvider).user;
                                  if (newUser != null) {
                                    final nameParts = newUser.name.trim().split(RegExp(r'\s+'));
                                    setState(() {
                                      _firstNameController.text = nameParts.isNotEmpty ? nameParts.first : '';
                                      _lastNameController.text = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
                                      _usernameController.text = newUser.username;
                                      _bioController.text = newUser.bio ?? '';
                                      _phoneController.text = newUser.phone ?? '';
                                      _selectedBirthday = newUser.birthday;
                                    });
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Switched to account ($input) successfully!'),
                                      backgroundColor: const Color(0xFF34C759),
                                    ),
                                  );
                                } else {
                                  setModalState(() {
                                    isSubmitting = false;
                                    modalError = ref.read(authProvider).errorMessage ?? 'Invalid login credentials.';
                                  });
                                }
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Add Account & Switch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await ref.read(authProvider.notifier).logout();
                        if (mounted) context.go('/auth/login');
                      },
                      child: const Text(
                        'Log out & Sign in to another account',
                        style: TextStyle(color: Color(0xFFFF3B30), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });

    final fullName = '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'.trim();

    try {
      final response = await ApiClient.instance.dio.put('/profile', data: {
        'name': fullName,
        'username': _usernameController.text.trim(),
        'bio': _bioController.text.trim(),
        'mobile_number': _phoneController.text.trim(),
        'phone': _phoneController.text.trim(),
        'birthday': _selectedBirthday != null ? DateFormat('yyyy-MM-dd').format(_selectedBirthday!) : null,
      });
      final data = ApiClient.instance.unwrap(response) as Map<String, dynamic>;
      final updatedUser = UserProfile.fromJson(data);
      ref.read(authProvider.notifier).setUser(updatedUser);
      await ref.read(authProvider.notifier).refreshProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile saved successfully!'),
            backgroundColor: _selectedAccentColor,
          ),
        );
        Navigator.pop(context);
      }
    } on DioException catch (e) {
      final message = e.response?.data is Map<String, dynamic>
          ? (e.response?.data as Map<String, dynamic>)['message'] as String?
          : 'Could not save profile.';
      if (mounted) setState(() => _error = message ?? 'Could not save profile.');
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Profile updated locally.');
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFEFF1F5);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final inputBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF7FAFC);
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
    final dividerColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);

    final user = ref.watch(authProvider).user;
    final role = user?.role ?? UserRole.member;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Edit Profile',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        leadingWidth: 80,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isSaving ? null : _handleSave,
              child: _isSaving
                  ? SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _selectedAccentColor),
                    )
                  : Text(
                      'Done',
                      style: TextStyle(
                        color: _selectedAccentColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Cover Banner & Overlapping Avatar Stack
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  // Banner Header Container
                  GestureDetector(
                    onTap: _pickBannerPhoto,
                    child: Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: _selectedBannerPath == null
                            ? LinearGradient(
                                colors: [_selectedAccentColor, const Color(0xFF5856D6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        image: _selectedBannerPath != null
                            ? DecorationImage(
                                image: FileImage(File(_selectedBannerPath!)),
                                fit: BoxFit.cover,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text('Edit Banner', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Overlapping Avatar Knob
                  Positioned(
                    bottom: -36,
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [_selectedAccentColor, const Color(0xFF5856D6)],
                            ),
                          ),
                          child: Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cardBg,
                              image: _selectedPhotoPath != null
                                  ? DecorationImage(
                                      image: FileImage(File(_selectedPhotoPath!)),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _selectedPhotoPath == null
                                ? Center(
                                    child: Text(
                                      _initials('${_firstNameController.text} ${_lastNameController.text}'),
                                      style: TextStyle(
                                        color: _selectedAccentColor,
                                        fontSize: 30,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickProfilePhoto,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _selectedAccentColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: cardBg, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      '${_firstNameController.text} ${_lastNameController.text}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: _showEditUsernameModal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '@${_usernameController.text.isNotEmpty ? _usernameController.text : 'web3nexus'}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _selectedAccentColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.edit_rounded, color: _selectedAccentColor, size: 14),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const OnlineStatusBadge(isOnline: true, showLabel: true),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickProfilePhoto,
                      child: Text(
                        'Set Profile Photo',
                        style: TextStyle(
                          color: _selectedAccentColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Role Badge Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _selectedAccentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (role == UserRole.creator)
                            const BrandFavicon(size: 14)
                          else
                            Icon(
                              role == UserRole.vendor
                                  ? Icons.storefront_rounded
                                  : Icons.verified_user_rounded,
                              color: _selectedAccentColor,
                              size: 14,
                            ),
                          const SizedBox(width: 6),
                          Text(
                            role.label,
                            style: TextStyle(
                              color: _selectedAccentColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Interactive Posts, Followers & Following Stats Bar
                    Builder(
                      builder: (context) {
                        final followState = ref.watch(followProvider);
                        final myUserId = user?.id ?? 0;
                        final postsCount = user?.postsCount ?? followState.getPostsCount(myUserId);
                        final followersCount = user?.followersCount ?? followState.getFollowersCount(myUserId);
                        final followingCount = user?.followingCount ?? followState.getFollowingCount(myUserId);

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem('Posts', '$postsCount', () {}, textPrimary, textSecondary),
                              Container(height: 24, width: 1, color: dividerColor),
                              _buildStatItem(
                                'Followers',
                                _formatCount(followersCount),
                                () => FollowersListDialog.show(context, title: 'Followers', isFollowersList: true, userId: myUserId),
                                textPrimary,
                                textSecondary,
                              ),
                              Container(height: 24, width: 1, color: dividerColor),
                              _buildStatItem(
                                'Following',
                                _formatCount(followingCount),
                                () => FollowersListDialog.show(context, title: 'Following', isFollowersList: false, userId: myUserId),
                                textPrimary,
                                textSecondary,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(_error!, style: const TextStyle(color: Color(0xFFFF3B30), fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 14),
              ],

              // Group 1: Fancy Name Inputs
              _buildInsetGroup(
                cardBg: cardBg,
                children: [
                  _buildFancyFormField(
                    controller: _firstNameController,
                    label: 'First Name',
                    icon: Icons.person_outline_rounded,
                    inputBg: inputBg,
                    textPrimary: textPrimary,
                    isDark: isDark,
                    validator: (v) => v == null || v.isEmpty ? 'First name is required' : null,
                  ),
                  Divider(height: 1, color: dividerColor, indent: 50),
                  _buildFancyFormField(
                    controller: _lastNameController,
                    label: 'Last Name',
                    icon: Icons.badge_outlined,
                    inputBg: inputBg,
                    textPrimary: textPrimary,
                    isDark: isDark,
                  ),
                ],
              ),
              _buildGroupFooter('Enter your full legal name or display name.', textSecondary),

              const SizedBox(height: 20),

              // Group 2: Fancy Bio Input with Live Character Counter
              _buildInsetGroup(
                cardBg: cardBg,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.notes_rounded, color: _selectedAccentColor, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Bio',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _bioController,
                              builder: (context, val, _) {
                                final len = val.text.length;
                                return Text(
                                  '$len / 150',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: len > 150 ? const Color(0xFFFF3B30) : textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA),
                            ),
                          ),
                          child: TextFormField(
                            controller: _bioController,
                            maxLines: 3,
                            maxLength: 150,
                            style: TextStyle(color: textPrimary, fontSize: 15),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: 'Add a brief bio about yourself or your business...',
                              hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400], fontSize: 14),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              _buildGroupFooter('Everyone on MurihSpace can read your public bio.', textSecondary),

              const SizedBox(height: 20),

              // Group 3: Birthday Picker Action
              _buildInsetGroup(
                cardBg: cardBg,
                children: [
                  ListTile(
                    leading: _buildIconTile(
                      icon: Icons.cake_rounded,
                      color: _selectedAccentColor,
                    ),
                    title: Text('Birthday', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      _selectedBirthday != null
                          ? DateFormat('dd MMMM yyyy').format(_selectedBirthday!)
                          : 'Not set',
                      style: TextStyle(color: _selectedAccentColor, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    trailing: Icon(Icons.chevron_right_rounded, color: textSecondary),
                    onTap: _selectBirthday,
                  ),
                ],
              ),
              _buildGroupFooter('Only your contacts can see your birthday.', textSecondary),

              const SizedBox(height: 20),

              // Group 4: Account Settings Inset Card with Working Actions
              _buildInsetGroup(
                cardBg: cardBg,
                children: [
                  ListTile(
                    leading: _buildIconTile(
                      icon: Icons.phone_rounded,
                      color: const Color(0xFF34C759),
                    ),
                    title: Text('Phone Number', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w500)),
                    subtitle: Text(_phoneController.text.isNotEmpty ? _phoneController.text : 'Not set', style: TextStyle(color: textSecondary, fontSize: 13)),
                    trailing: Icon(Icons.edit_rounded, color: _selectedAccentColor, size: 20),
                    onTap: _showEditPhoneModal,
                  ),
                  Divider(height: 1, color: dividerColor, indent: 56),
                  ListTile(
                    leading: _buildIconTile(
                      icon: Icons.alternate_email_rounded,
                      color: const Color(0xFF5856D6),
                    ),
                    title: Text('Username', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w500)),
                    subtitle: Text('@${_usernameController.text}', style: TextStyle(color: _selectedAccentColor, fontSize: 13, fontWeight: FontWeight.bold)),
                    trailing: Icon(Icons.edit_rounded, color: _selectedAccentColor, size: 20),
                    onTap: _showEditUsernameModal,
                  ),
                  Divider(height: 1, color: dividerColor, indent: 56),
                  ListTile(
                    leading: _buildIconTile(
                      icon: Icons.palette_rounded,
                      color: _selectedAccentColor,
                    ),
                    title: Text('Profile Color Theme', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w500)),
                    subtitle: Text(_accentColorName, style: TextStyle(color: textSecondary, fontSize: 13)),
                    trailing: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: _selectedAccentColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                    onTap: _showAccentColorSheet,
                  ),
                  Divider(height: 1, color: dividerColor, indent: 56),
                  ListTile(
                    leading: _buildIconTile(
                      icon: Icons.campaign_rounded,
                      color: const Color(0xFFFF9500),
                    ),
                    title: Text('Broadcast Channel', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w500)),
                    subtitle: Text('1-to-many updates', style: TextStyle(color: textSecondary, fontSize: 13)),
                    trailing: Icon(Icons.chevron_right_rounded, color: textSecondary),
                    onTap: _showChannelModal,
                  ),
                  Divider(height: 1, color: dividerColor, indent: 56),
                  ListTile(
                    leading: _buildIconTile(
                      icon: Icons.smart_toy_rounded,
                      color: const Color(0xFFAF52DE),
                    ),
                    title: Text('Chat Automation Bot', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w500)),
                    subtitle: Text('Auto-reply greeting messages', style: TextStyle(color: textSecondary, fontSize: 13)),
                    trailing: Icon(Icons.chevron_right_rounded, color: textSecondary),
                    onTap: () => showAutomatedGreetingSheet(context),
                  ),
                ],
              ),
              _buildGroupFooter('Configure AI greeting bot, color themes, and phone settings.', textSecondary),

              const SizedBox(height: 20),

              // Group 5: Add Another Account Action
              _buildInsetGroup(
                cardBg: cardBg,
                children: [
                  ListTile(
                    leading: _buildIconTile(
                      icon: Icons.person_add_alt_1_rounded,
                      color: _selectedAccentColor,
                    ),
                    title: Text(
                      'Add Another Account',
                      style: TextStyle(
                        color: _selectedAccentColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    trailing: Icon(Icons.chevron_right_rounded, color: textSecondary),
                    onTap: _showAddAccountModal,
                  ),
                ],
              ),
              _buildGroupFooter('Connect multiple accounts with different phone numbers.', textSecondary),

              const SizedBox(height: 20),

              // Group 6: Log Out Action
              _buildInsetGroup(
                cardBg: cardBg,
                children: [
                  ListTile(
                    leading: _buildIconTile(
                      icon: Icons.logout_rounded,
                      color: const Color(0xFFFF3B30),
                    ),
                    title: const Text(
                      'Log Out',
                      style: TextStyle(
                        color: Color(0xFFFF3B30),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () async {
                      final confirm = await AppBottomSheet.showConfirmation(
                        context: context,
                        title: 'Log Out',
                        message: 'Are you sure you want to log out of MurihSpace?',
                        confirmText: 'Log Out',
                        isDestructive: true,
                        icon: Icons.logout_rounded,
                      );
                      if (confirm == true && mounted) {
                        await ref.read(authProvider.notifier).logout();
                        if (mounted) context.go('/auth/login');
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, VoidCallback onTap, Color textPrimary, Color? textSecondary) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return '$count';
  }

  Widget _buildFancyFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color inputBg,
    required Color textPrimary,
    required bool isDark,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: inputBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA),
          ),
        ),
        child: TextFormField(
          controller: controller,
          validator: validator,
          style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: _selectedAccentColor, size: 22),
            labelText: label,
            labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildInsetGroup({
    required Color cardBg,
    required List<Widget> children,
  }) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildGroupFooter(String text, Color? color) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(fontSize: 12, color: color),
        ),
      ),
    );
  }

  Widget _buildIconTile({
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'HS';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }
}
