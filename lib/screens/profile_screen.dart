import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../components/followers_list_dialog.dart';
import '../config/env.dart';
import '../core/api_client.dart';
import '../models/story_models.dart';
import '../providers/auth_provider.dart';
import '../providers/story_provider.dart';
import 'story_composer_sheet.dart';
import 'story_viewer_screen.dart';

/// Redesigned Edit Profile Screen & Popup Modal matching MurihSpace design reference:
/// Screen 1 & 3: Edit Profile (Personal tab with Cover & Avatar, Personal Information, Details, Profile Visibility)
/// Screen 2: Popup Modal (Unified Update Profile Photo & Update Cover Photo modal sheet)
/// Screen 4: Interests tab (Content Topics chips with checkmark/circle indicators, Languages, About Me toggle cards)
/// Screen 5: Preview Profile Screen (Public View / My View segmented control, live feed card, bottom Save Changes button)
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 4, vsync: this);
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _displayNameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _locationController;
  late TextEditingController _websiteController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;

  // Socials controllers
  late TextEditingController _twitterController;
  late TextEditingController _instagramController;
  late TextEditingController _youtubeController;
  late TextEditingController _tiktokController;
  late TextEditingController _githubController;

  DateTime? _selectedBirthday;
  String _selectedGender = '';
  String _selectedCategory = '';
  String _accountPrivacy = 'Public';
  bool _showContactInfo = true;
  bool _isCreatorAccount = true;
  bool _showInterests = true;
  bool _allowTagging = true;

  final Set<String> _selectedTopics = {};
  final Set<String> _selectedLanguages = {};

  String? _avatarUrl;
  String? _bannerUrl;
  bool _isUploadingPhoto = false;
  bool _isUploadingBanner = false;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;

  static const Color primaryBlue = Color(0xFF1B64F2);

  final List<String> _allTopics = [
    'Travel',
    'Food',
    'Technology',
    'Lifestyle',
    'Business',
    'Fitness',
    'Music',
    'Fashion',
    'Gaming',
    'Art',
    'Photography',
    'Culture',
  ];

  final List<String> _allCategories = [
    'Content Creator',
    'Digital Artist',
    'Tech Entrepreneur',
    'Musician / DJ',
    'Fitness Coach',
    'Traveler & Explorer',
    'Writer / Journalist',
    'Community Leader',
  ];

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _displayNameController = TextEditingController(text: user?.name ?? '');
    _usernameController = TextEditingController(text: user?.username ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _locationController = TextEditingController(
      text: [
        user?.state,
        user?.country,
      ].where((s) => s != null && s.isNotEmpty).join(', '),
    );
    _websiteController = TextEditingController(text: user?.website ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _selectedBirthday = user?.birthday;
    _selectedGender = user?.gender ?? '';
    _selectedCategory = user?.category ?? '';
    _accountPrivacy =
        (user?.accountPrivacy ?? 'public').toLowerCase() == 'private'
        ? 'Private'
        : 'Public';
    _showContactInfo = user?.showContactInfo ?? true;
    _isCreatorAccount = user?.isCreatorAccount ?? true;
    _showInterests = user?.showInterests ?? true;
    _allowTagging = user?.allowTagging ?? true;

    _selectedTopics
      ..clear()
      ..addAll(user?.interests ?? const []);
    _selectedLanguages
      ..clear()
      ..addAll(user?.languages ?? const []);

    _avatarUrl = user?.avatarUrl;
    _bannerUrl = user?.bannerUrl;

    _twitterController = TextEditingController();
    _instagramController = TextEditingController();
    _youtubeController = TextEditingController();
    _tiktokController = TextEditingController();
    _githubController = TextEditingController();

    _displayNameController.addListener(_markChanged);
    _usernameController.addListener(_markChanged);
    _bioController.addListener(_markChanged);
    _locationController.addListener(_markChanged);
    _websiteController.addListener(_markChanged);
    _phoneController.addListener(_markChanged);
  }

  void _markChanged() {
    if (!_hasUnsavedChanges && mounted) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    _displayNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _websiteController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _twitterController.dispose();
    _instagramController.dispose();
    _youtubeController.dispose();
    _tiktokController.dispose();
    _githubController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Popup Modal (Screen 2: Unified Photo Management Bottom Sheet)
  // ─────────────────────────────────────────────────────────────
  Future<void> _showPhotoManagerSheet({bool focusCover = false}) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

    final resolvedAvatar = _avatarUrl != null && _avatarUrl!.isNotEmpty
        ? (ApiClient.resolveUrl(_avatarUrl!) ?? _avatarUrl!)
        : null;
    final resolvedBanner = _bannerUrl != null && _bannerUrl!.isNotEmpty
        ? (ApiClient.resolveUrl(_bannerUrl!) ?? _bannerUrl!)
        : null;

    final scrollController = ScrollController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        if (focusCover) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (scrollController.hasClients) {
              scrollController.animateTo(
                260,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }

        return SafeArea(
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag handle
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),

                // ── SECTION 1: Update Profile Photo ──
                Text(
                  'Update Profile Photo',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 16),
                // Circular avatar preview with camera badge
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: cardBg,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 44,
                          backgroundColor: primaryBlue.withValues(alpha: 0.12),
                          backgroundImage: resolvedAvatar != null
                              ? CachedNetworkImageProvider(resolvedAvatar)
                              : null,
                          child: resolvedAvatar == null
                              ? Text(
                                  _displayNameController.text.isNotEmpty
                                      ? _displayNameController.text[0]
                                            .toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: primaryBlue,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0F172A),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _photoActionTile(
                  icon: Icons.photo_camera_outlined,
                  title: 'Take Photo',
                  color: textPrimary,
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadAvatar(ImageSource.camera);
                  },
                ),
                _photoActionTile(
                  icon: Icons.image_outlined,
                  title: 'Choose from Gallery',
                  color: textPrimary,
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadAvatar(ImageSource.gallery);
                  },
                ),
                _photoActionTile(
                  icon: Icons.crop_original_outlined,
                  title: 'Choose an Avatar Frame',
                  color: textPrimary,
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Avatar frames available for verified profiles!',
                        ),
                      ),
                    );
                  },
                ),
                if (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                  _photoActionTile(
                    icon: Icons.delete_outline_rounded,
                    title: 'Remove Photo',
                    color: const Color(0xFFEF4444),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _avatarUrl = null;
                        _hasUnsavedChanges = true;
                      });
                    },
                  ),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Divider(color: borderColor, height: 1),
                ),

                // ── SECTION 2: Update Cover Photo ──
                Text(
                  'Update Cover Photo',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 14),
                // Cover photo preview container
                Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFF0F172A),
                    image: resolvedBanner != null
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(resolvedBanner),
                            fit: BoxFit.cover,
                          )
                        : null,
                    gradient: resolvedBanner == null
                        ? const LinearGradient(
                            colors: [Color(0xFF0F2B48), Color(0xFF1B64F2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 14),
                _photoActionTile(
                  icon: Icons.photo_camera_outlined,
                  title: 'Take Photo',
                  color: textPrimary,
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadBanner(ImageSource.camera);
                  },
                ),
                _photoActionTile(
                  icon: Icons.image_outlined,
                  title: 'Choose from Gallery',
                  color: textPrimary,
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadBanner(ImageSource.gallery);
                  },
                ),
                if (_bannerUrl != null && _bannerUrl!.isNotEmpty)
                  _photoActionTile(
                    icon: Icons.delete_outline_rounded,
                    title: 'Remove Cover Photo',
                    color: const Color(0xFFEF4444),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _bannerUrl = null;
                        _hasUnsavedChanges = true;
                      });
                    },
                  ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _photoActionTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      visualDensity: VisualDensity.compact,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14.5,
          color: color,
        ),
      ),
      onTap: onTap,
    );
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: source, imageQuality: 85);
      if (file == null || !mounted) return;

      setState(() => _isUploadingPhoto = true);

      final bytes = await file.readAsBytes();
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: file.name),
      });

      final res = await ApiClient.instance.dio.post(
        '/profile/avatar',
        data: form,
      );
      final payload = ApiClient.instance.unwrap(res);
      final uploadedUrl = payload is Map<String, dynamic>
          ? (payload['avatar_url'] ?? payload['url'] ?? payload['avatar'])
                ?.toString()
          : payload?.toString();

      if (uploadedUrl != null && uploadedUrl.isNotEmpty && mounted) {
        setState(() {
          _avatarUrl = uploadedUrl;
          _hasUnsavedChanges = true;
        });
        await ref.read(authProvider.notifier).refreshProfile();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to upload photo: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _pickAndUploadBanner(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: source, imageQuality: 85);
      if (file == null || !mounted) return;

      setState(() => _isUploadingBanner = true);

      final bytes = await file.readAsBytes();
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: file.name),
      });

      final res = await ApiClient.instance.dio.post(
        '/profile/banner',
        data: form,
      );
      final payload = ApiClient.instance.unwrap(res);
      final uploadedUrl = payload is Map<String, dynamic>
          ? (payload['banner_url'] ?? payload['url'])?.toString()
          : payload?.toString();

      if (uploadedUrl != null && uploadedUrl.isNotEmpty && mounted) {
        setState(() {
          _bannerUrl = uploadedUrl;
          _hasUnsavedChanges = true;
        });
        await ref.read(authProvider.notifier).refreshProfile();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cover banner updated!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to upload banner: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploadingBanner = false);
    }
  }

  Future<void> _saveProfileChanges() async {
    if (!_formKey.currentState!.validate()) {
      _tab.animateTo(0);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final locationText = _locationController.text.trim();
      final countryParts = locationText
          .split(',')
          .map((s) => s.trim())
          .toList();
      final stateVal = countryParts.isNotEmpty ? countryParts.first : '';
      final countryVal = countryParts.length > 1
          ? countryParts.sublist(1).join(', ')
          : stateVal;

      final body = {
        'name': _displayNameController.text.trim(),
        'username': _usernameController.text.trim(),
        'bio': _bioController.text.trim(),
        'website': _websiteController.text.trim().isEmpty
            ? null
            : _websiteController.text.trim(),
        'category': _selectedCategory.isEmpty ? null : _selectedCategory,
        'gender': _selectedGender.isEmpty ? null : _selectedGender,
        'interests': _selectedTopics.toList(),
        'languages': _selectedLanguages.toList(),
        'is_creator_account': _isCreatorAccount,
        'show_interests': _showInterests,
        'allow_tagging': _allowTagging,
        'show_contact_info': _showContactInfo,
        'account_privacy': _accountPrivacy.toLowerCase(),
        'state': stateVal,
        'country': countryVal,
        'phone': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'birthday': _selectedBirthday != null
            ? DateFormat('yyyy-MM-dd').format(_selectedBirthday!)
            : null,
        'avatar_url': _avatarUrl,
        'banner_url': _bannerUrl,
      };

      await ApiClient.instance.dio.put('/profile', data: body);
      await ref.read(authProvider.notifier).refreshProfile();

      // Bust public profile cache
      try {
        await ApiClient.instance.dio.get(
          '/users/${_usernameController.text.trim()}/public',
          queryParameters: {'refresh': 1},
        );
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isSaving = false;
          _hasUnsavedChanges = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved successfully!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save profile: $e')));
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Discard changes?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text('You have unsaved changes that will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Keep Editing',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Discard',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    return shouldDiscard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

    final resolvedAvatar = _avatarUrl != null && _avatarUrl!.isNotEmpty
        ? (ApiClient.resolveUrl(_avatarUrl!) ?? _avatarUrl!)
        : null;
    final resolvedBanner = _bannerUrl != null && _bannerUrl!.isNotEmpty
        ? (ApiClient.resolveUrl(_bannerUrl!) ?? _bannerUrl!)
        : null;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: cardBg,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () async {
              if (await _onWillPop() && context.mounted) {
                context.pop();
              }
            },
          ),
          centerTitle: true,
          title: Text(
            'Edit Profile',
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: -0.3,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: SizedBox(
                height: 36,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: _isSaving ? null : _saveProfileChanges,
                  child: _isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(44),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: TabBar(
                controller: _tab,
                isScrollable: false,
                labelColor: primaryBlue,
                unselectedLabelColor: textSecondary,
                indicatorColor: primaryBlue,
                indicatorWeight: 2.5,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
                tabs: const [
                  Tab(text: 'Personal'),
                  Tab(text: 'Interests'),
                  Tab(text: 'Links'),
                  Tab(text: 'Socials'),
                ],
              ),
            ),
          ),
        ),
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _buildPersonalTab(
                      isDark,
                      cardBg,
                      textPrimary,
                      textSecondary,
                      borderColor,
                      resolvedAvatar,
                      resolvedBanner,
                    ),
                    _buildInterestsTab(
                      isDark,
                      cardBg,
                      textPrimary,
                      textSecondary,
                      borderColor,
                    ),
                    _buildLinksTab(
                      isDark,
                      cardBg,
                      textPrimary,
                      textSecondary,
                      borderColor,
                    ),
                    _buildSocialsTab(
                      isDark,
                      cardBg,
                      textPrimary,
                      textSecondary,
                      borderColor,
                    ),
                  ],
                ),
              ),
              // Floating Bottom Bar: Preview Profile mode
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryBlue,
                      side: const BorderSide(color: primaryBlue, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      final user = ref.read(authProvider).user;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PreviewProfileScreen(
                            userId: user?.id ?? 0,
                            displayName:
                                _displayNameController.text.trim().isNotEmpty
                                ? _displayNameController.text.trim()
                                : (user?.name ?? 'User'),
                            username: _usernameController.text.trim().isNotEmpty
                                ? _usernameController.text.trim()
                                : (user?.username ?? 'user'),
                            bio: _bioController.text.trim(),
                            location: _locationController.text.trim(),
                            website: _websiteController.text.trim(),
                            avatarUrl: resolvedAvatar,
                            bannerUrl: resolvedBanner,
                            onSaveChanges: _saveProfileChanges,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text(
                      'Preview Profile',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 1. Personal Tab (Screens 1 & 3: Hero Cover, Overlapping Avatar, Info, Details)
  // ─────────────────────────────────────────────────────────────
  Widget _buildPersonalTab(
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
    String? resolvedAvatar,
    String? resolvedBanner,
  ) {
    final bioLength = _bioController.text.length;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // A. Hero Cover Photo Banner with "Change Cover" pill
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 155,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                image: resolvedBanner != null
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(resolvedBanner),
                        fit: BoxFit.cover,
                      )
                    : null,
                gradient: resolvedBanner == null
                    ? const LinearGradient(
                        colors: [Color(0xFF0F2B48), Color(0xFF1B64F2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
              ),
              child: _isUploadingBanner
                  ? Container(
                      color: Colors.black45,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    )
                  : null,
            ),
            // "Change Cover" pill button (Screen 1)
            Positioned(
              right: 14,
              bottom: 12,
              child: GestureDetector(
                onTap: () => _showPhotoManagerSheet(focusCover: true),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6.5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Change Cover',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Overlapping Large Avatar with camera badge (Screen 1 & 3)
            Positioned(
              left: 20,
              bottom: -40,
              child: GestureDetector(
                onTap: () => _showPhotoManagerSheet(focusCover: false),
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3.5),
                      decoration: BoxDecoration(
                        color: cardBg,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: primaryBlue.withValues(alpha: 0.12),
                        backgroundImage: resolvedAvatar != null
                            ? CachedNetworkImageProvider(resolvedAvatar)
                            : null,
                        child: resolvedAvatar == null
                            ? Text(
                                _displayNameController.text.isNotEmpty
                                    ? _displayNameController.text[0]
                                          .toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: primaryBlue,
                                ),
                              )
                            : null,
                      ),
                    ),
                    if (_isUploadingPhoto)
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black38,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F172A),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 52),

        // B. Personal Information Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 14),

              // Display Name *
              _formField(
                label: 'Display Name *',
                controller: _displayNameController,
                hint: 'Lord Uzih',
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onClear: () => _displayNameController.clear(),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Display name is required'
                    : null,
              ),
              const SizedBox(height: 14),

              // Username *
              _formField(
                label: 'Username *',
                controller: _usernameController,
                hint: 'username',
                prefixText: '@ ',
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onClear: () => _usernameController.clear(),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Username is required'
                    : null,
              ),
              const SizedBox(height: 14),

              // Bio with live 0/200 counter
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bio',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        TextField(
                          controller: _bioController,
                          maxLines: 3,
                          maxLength: 200,
                          style: TextStyle(
                            fontSize: 14,
                            color: textPrimary,
                            height: 1.35,
                          ),
                          decoration: InputDecoration(
                            filled: false,
                            hintText:
                                'Creator • Entrepreneur • Tech • Travel • Good Life\nBuilding @MurihSpace | Food | Culture | Africa 🌍',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: textSecondary.withValues(alpha: 0.7),
                            ),
                            border: InputBorder.none,
                            counterText: '',
                            isDense: true,
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            '$bioLength/200',
                            style: TextStyle(
                              fontSize: 11,
                              color: textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Category Picker (Screen 1 & 3)
              _categoryRow(
                label: 'Category',
                value: _selectedCategory,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () => _showCategoryPicker(),
              ),
              const SizedBox(height: 14),

              // Location
              _formField(
                label: 'Location',
                controller: _locationController,
                hint: 'Calpe, Spain',
                prefixIcon: Icons.location_on_outlined,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onClear: () => _locationController.clear(),
              ),
              const SizedBox(height: 14),

              // Website (Screen 1)
              _formField(
                label: 'Website',
                controller: _websiteController,
                hint: 'https://example.com/links',
                prefixIcon: Icons.link_rounded,
                isLinkField: true,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: primaryBlue,
                textSecondary: textSecondary,
                onClear: () => _websiteController.clear(),
              ),

              const SizedBox(height: 26),

              // C. Details Section (Screen 3)
              Text(
                'Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 14),

              // Date of Birth
              _clickableRow(
                label: 'Date of Birth',
                value: _selectedBirthday != null
                    ? DateFormat('MMM d, yyyy').format(_selectedBirthday!)
                    : '',
                placeholder: 'Add date of birth',
                icon: Icons.calendar_today_outlined,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedBirthday ?? DateTime(2000, 1, 1),
                    firstDate: DateTime(1920),
                    lastDate: now,
                  );
                  if (picked != null && mounted) {
                    setState(() {
                      _selectedBirthday = picked;
                      _hasUnsavedChanges = true;
                    });
                  }
                },
              ),
              const SizedBox(height: 14),

              // Gender
              _clickableRow(
                label: 'Gender',
                value: _selectedGender,
                placeholder: 'Select gender',
                icon: Icons.person_outline_rounded,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () => _showGenderPicker(),
              ),
              const SizedBox(height: 14),

              // Phone Number
              _clickableRow(
                label: 'Phone Number',
                value: _phoneController.text.trim(),
                placeholder: 'Add phone number',
                icon: Icons.phone_outlined,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () => _editPhoneDialog(),
              ),
              const SizedBox(height: 14),

              // Email Address (read-only / protected)
              _formField(
                label: 'Email Address',
                controller: _emailController,
                hint: 'name@example.com',
                prefixIcon: Icons.email_outlined,
                suffixIcon: Icons.lock_outline_rounded,
                readOnly: true,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              const SizedBox(height: 14),

              // Show Contact Information toggle
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Show Contact Information',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Let people see your contact info on your profile',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _showContactInfo,
                      activeThumbColor: primaryBlue,
                      onChanged: (v) => setState(() {
                        _showContactInfo = v;
                        _hasUnsavedChanges = true;
                      }),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 26),

              // D. Profile Visibility Section (Screen 1)
              Text(
                'Profile Visibility',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 14),

              GestureDetector(
                onTap: () {
                  setState(() {
                    _accountPrivacy = _accountPrivacy == 'Public'
                        ? 'Private'
                        : 'Public';
                    _hasUnsavedChanges = true;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: textSecondary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_outline_rounded,
                          size: 16,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Account Privacy',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        _accountPrivacy,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: textSecondary,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 2. Interests Tab (Screen 4: Topics chips, Languages, About Me)
  // ─────────────────────────────────────────────────────────────
  Widget _buildInterestsTab(
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      children: [
        Text(
          'Interests & Content',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 14),

        Text(
          'Content Topics',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Choose the topics you create or are interested in',
          style: TextStyle(fontSize: 12, color: textSecondary),
        ),
        const SizedBox(height: 14),

        // Topic Chips with Selected Checkmark / Unselected Circle indicator
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: _allTopics.map((topic) {
            final isSelected = _selectedTopics.contains(topic);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedTopics.remove(topic);
                  } else {
                    _selectedTopics.add(topic);
                  }
                  _hasUnsavedChanges = true;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 7.5,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primaryBlue
                      : (isDark ? const Color(0xFF1E293B) : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? primaryBlue : borderColor,
                  ),
                  boxShadow: [
                    if (!isSelected)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
                      const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 14,
                      )
                    else
                      Icon(
                        Icons.radio_button_unchecked_rounded,
                        color: textSecondary.withValues(alpha: 0.7),
                        size: 14,
                      ),
                    const SizedBox(width: 5),
                    Text(
                      topic,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: isSelected ? Colors.white : textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),

        // Languages
        Text(
          'Languages',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: [
            for (final lang in ['English', 'Spanish', 'French', 'German'])
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (_selectedLanguages.contains(lang)) {
                      _selectedLanguages.remove(lang);
                    } else {
                      _selectedLanguages.add(lang);
                    }
                    _hasUnsavedChanges = true;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 7.5,
                  ),
                  decoration: BoxDecoration(
                    color: _selectedLanguages.contains(lang)
                        ? primaryBlue
                        : (isDark ? const Color(0xFF1E293B) : Colors.white),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _selectedLanguages.contains(lang)
                          ? primaryBlue
                          : borderColor,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_selectedLanguages.contains(lang))
                        const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 14,
                        )
                      else
                        Icon(
                          Icons.radio_button_unchecked_rounded,
                          color: textSecondary.withValues(alpha: 0.7),
                          size: 14,
                        ),
                      const SizedBox(width: 5),
                      Text(
                        lang,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: _selectedLanguages.contains(lang)
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: _selectedLanguages.contains(lang)
                              ? Colors.white
                              : textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // + Add Language button
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Additional languages can be selected in Account Settings!',
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7.5,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primaryBlue.withValues(alpha: 0.6)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: primaryBlue, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Add Language',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 28),

        // About Me Toggles (Screen 4)
        Text(
          'About Me',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 14),

        // 1. Creator Account
        _toggleCard(
          title: 'Creator Account',
          subtitle: 'Show creator label on your profile',
          icon: Icons.workspace_premium_rounded,
          iconBg: const Color(0xFFFEF3C7),
          iconColor: const Color(0xFFD97706),
          value: _isCreatorAccount,
          isDark: isDark,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          onChanged: (v) => setState(() {
            _isCreatorAccount = v;
            _hasUnsavedChanges = true;
          }),
        ),
        const SizedBox(height: 12),

        // 2. Show My Interests
        _toggleCard(
          title: 'Show My Interests',
          subtitle: 'Display your interests on your profile',
          icon: Icons.interests_rounded,
          iconBg: const Color(0xFFE0F2FE),
          iconColor: const Color(0xFF0284C7),
          value: _showInterests,
          isDark: isDark,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          onChanged: (v) => setState(() {
            _showInterests = v;
            _hasUnsavedChanges = true;
          }),
        ),
        const SizedBox(height: 12),

        // 3. Allow Tagging
        _toggleCard(
          title: 'Allow Tagging',
          subtitle: 'Let others tag you in their posts',
          icon: Icons.tag_rounded,
          iconBg: const Color(0xFFE0F2FE),
          iconColor: const Color(0xFF0284C7),
          value: _allowTagging,
          isDark: isDark,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          onChanged: (v) => setState(() {
            _allowTagging = v;
            _hasUnsavedChanges = true;
          }),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 3. Links Tab (Native MurihSpace Link-in-Bio)
  // ─────────────────────────────────────────────────────────────
  Widget _buildLinksTab(
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    final username = _usernameController.text.trim();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      children: [
        Text(
          'Integrated Link-in-Bio',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your personalized native linktree integrated directly inside MurihSpace.',
          style: TextStyle(fontSize: 12, color: textSecondary),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryBlue.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.link_rounded,
                      color: primaryBlue,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${Env.profileDomain}/@$username',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Active · Public link enabled',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF16A34A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => context.push('/link-in-bio'),
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text(
                    'Configure Link-in-Bio',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 4. Socials Tab
  // ─────────────────────────────────────────────────────────────
  Widget _buildSocialsTab(
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      children: [
        Text(
          'Connected Social Accounts',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Link your external profiles for automatic badge verification & cross-promotion.',
          style: TextStyle(fontSize: 12, color: textSecondary),
        ),
        const SizedBox(height: 16),

        _socialInput(
          label: 'Twitter / X',
          prefix: 'x.com/',
          controller: _twitterController,
          isDark: isDark,
          cardBg: cardBg,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
        const SizedBox(height: 12),
        _socialInput(
          label: 'Instagram',
          prefix: 'instagram.com/',
          controller: _instagramController,
          isDark: isDark,
          cardBg: cardBg,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
        const SizedBox(height: 12),
        _socialInput(
          label: 'YouTube',
          prefix: 'youtube.com/@',
          controller: _youtubeController,
          isDark: isDark,
          cardBg: cardBg,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
        const SizedBox(height: 12),
        _socialInput(
          label: 'TikTok',
          prefix: 'tiktok.com/@',
          controller: _tiktokController,
          isDark: isDark,
          cardBg: cardBg,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
        const SizedBox(height: 12),
        _socialInput(
          label: 'GitHub',
          prefix: 'github.com/',
          controller: _githubController,
          isDark: isDark,
          cardBg: cardBg,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Helper Form Widgets
  // ─────────────────────────────────────────────────────────────
  Widget _formField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    String? prefixText,
    IconData? prefixIcon,
    IconData? suffixIcon,
    bool isLinkField = false,
    VoidCallback? onClear,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              if (prefixIcon != null) ...[
                Icon(prefixIcon, color: textSecondary, size: 18),
                const SizedBox(width: 8),
              ],
              if (prefixText != null)
                Text(
                  prefixText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textSecondary,
                  ),
                ),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  readOnly: readOnly,
                  keyboardType: keyboardType,
                  validator: validator,
                  style: TextStyle(
                    fontSize: 14,
                    color: isLinkField ? primaryBlue : textPrimary,
                    fontWeight: isLinkField ? FontWeight.w600 : FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    filled: false,
                    hintText: hint,
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: textSecondary.withValues(alpha: 0.7),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (suffixIcon != null)
                Icon(suffixIcon, size: 16, color: textSecondary)
              else if (onClear != null &&
                  controller.text.isNotEmpty &&
                  !readOnly)
                GestureDetector(
                  onTap: onClear,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: textSecondary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _categoryRow({
    required String label,
    required String value,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.camera_alt_outlined, color: textSecondary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: textSecondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _clickableRow({
    required String label,
    required String value,
    String? placeholder,
    required IconData icon,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback onTap,
  }) {
    final displayValue = value.isNotEmpty ? value : (placeholder ?? '');
    final isPlaceholder =
        value.isEmpty || (placeholder != null && displayValue == placeholder);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(icon, color: textSecondary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    displayValue,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isPlaceholder ? textSecondary : textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: textSecondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _toggleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required bool value,
    required bool isDark,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11.5, color: textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: primaryBlue,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _socialInput({
    required String label,
    required String prefix,
    required TextEditingController controller,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text(
                prefix,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: TextStyle(fontSize: 14, color: textPrimary),
                  decoration: const InputDecoration(
                    filled: false,
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCategoryPicker() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Category',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            ..._allCategories.map(
              (c) => ListTile(
                title: Text(
                  c,
                  style: TextStyle(
                    fontWeight: c == _selectedCategory
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                trailing: c == _selectedCategory
                    ? const Icon(Icons.check_rounded, color: primaryBlue)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedCategory = c;
                    _hasUnsavedChanges = true;
                  });
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGenderPicker() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Gender',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            ...['Male', 'Female', 'Non-binary', 'Prefer not to say'].map(
              (g) => ListTile(
                title: Text(
                  g,
                  style: TextStyle(
                    fontWeight: g == _selectedGender
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                trailing: g == _selectedGender
                    ? const Icon(Icons.check_rounded, color: primaryBlue)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedGender = g;
                    _hasUnsavedChanges = true;
                  });
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editPhoneDialog() {
    final tempController = TextEditingController(text: _phoneController.text);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Phone Number',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: TextField(
          controller: tempController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            hintText: '+1 234 567 8900',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _phoneController.text = tempController.text.trim();
                _hasUnsavedChanges = true;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Screen 5: Preview Profile Screen (Public View / My View)
// ─────────────────────────────────────────────────────────────
class PreviewProfileScreen extends ConsumerStatefulWidget {
  final int userId;
  final String displayName;
  final String username;
  final String bio;
  final String location;
  final String website;
  final String? avatarUrl;
  final String? bannerUrl;
  final VoidCallback onSaveChanges;

  const PreviewProfileScreen({
    super.key,
    required this.userId,
    required this.displayName,
    required this.username,
    required this.bio,
    required this.location,
    required this.website,
    this.avatarUrl,
    this.bannerUrl,
    required this.onSaveChanges,
  });

  @override
  ConsumerState<PreviewProfileScreen> createState() =>
      _PreviewProfileScreenState();
}

class _PreviewProfileScreenState extends ConsumerState<PreviewProfileScreen> {
  String _viewMode = 'public'; // 'public' or 'my'
  int _activeContentTab = 0; // 0: Posts, 1: Reels, 2: Live, 3: Tagged

  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _userPosts = [];
  List<Map<String, dynamic>> _userReels = [];
  List<Map<String, dynamic>> _userLive = [];
  List<Map<String, dynamic>> _userTagged = [];
  List<Map<String, dynamic>> _userStories = [];
  bool _loadingPosts = false;

  static const Color primaryBlue = Color(0xFF1B64F2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchPublicProfile();
      _fetchUserStories();
      _fetchTabPosts(0);
    });
  }

  int get _effectiveUserId {
    if (widget.userId > 0) return widget.userId;
    final dynamicId = (_profileData?['id'] as num?)?.toInt();
    if (dynamicId != null && dynamicId > 0) return dynamicId;
    return ref.read(authProvider).user?.id ?? 0;
  }

  Future<void> _fetchPublicProfile() async {
    final handle = widget.username.isNotEmpty
        ? widget.username
        : (ref.read(authProvider).user?.username ?? '');
    if (handle.isEmpty) return;
    try {
      final res = await ApiClient.instance.dio.get('/users/$handle/public');
      final data = ApiClient.instance.unwrap(res);
      if (data is Map<String, dynamic> && mounted) {
        setState(() => _profileData = data);
        final dynamicId = (data['id'] as num?)?.toInt() ?? 0;
        if (dynamicId > 0 && widget.userId <= 0) {
          _fetchUserStories();
          _fetchTabPosts(_activeContentTab);
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchUserStories() async {
    final targetId = _effectiveUserId;
    if (targetId <= 0) return;
    try {
      final res = await ApiClient.instance.dio.get('/users/$targetId/stories');
      final payload = ApiClient.instance.unwrap(res);
      if (payload is List && mounted) {
        setState(() {
          _userStories = payload.whereType<Map<String, dynamic>>().toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchTabPosts(int tabIndex) async {
    final targetId = _effectiveUserId;
    if (targetId <= 0) return;

    setState(() => _loadingPosts = true);
    try {
      String type = 'all';
      if (tabIndex == 1) type = 'reels';
      if (tabIndex == 2) type = 'live';
      if (tabIndex == 3) type = 'mentions';

      final res = await ApiClient.instance.dio.get(
        '/users/$targetId/posts',
        queryParameters: {'type': type},
      );
      final payload = ApiClient.instance.unwrap(res);
      List<Map<String, dynamic>> list = [];
      if (payload is Map<String, dynamic>) {
        final raw = payload['data'];
        if (raw is List) {
          list = raw.whereType<Map<String, dynamic>>().toList();
        }
      } else if (payload is List) {
        list = payload.whereType<Map<String, dynamic>>().toList();
      }

      if (mounted) {
        setState(() {
          if (tabIndex == 0) _userPosts = list;
          if (tabIndex == 1) _userReels = list;
          if (tabIndex == 2) _userLive = list;
          if (tabIndex == 3) _userTagged = list;
          _loadingPosts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  List<Map<String, dynamic>> get _currentTabPosts {
    switch (_activeContentTab) {
      case 1:
        return _userReels;
      case 2:
        return _userLive;
      case 3:
        return _userTagged;
      case 0:
      default:
        return _userPosts;
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    }
    if (count >= 10000) {
      return '${(count / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
    }
    if (count >= 1000) {
      return NumberFormat('#,###').format(count);
    }
    return '$count';
  }

  void _handleStoryTap(Map<String, dynamic> story) {
    final storyState = ref.read(storyProvider);
    final myId = ref.read(authProvider).user?.id;
    final isMe = myId == _effectiveUserId;

    UserStoryGroup? matchedGroup;
    for (final g in storyState.groups) {
      if (g.userId == _effectiveUserId.toString() ||
          g.userName.toLowerCase() == widget.displayName.toLowerCase() ||
          (isMe && g.isMyStory)) {
        matchedGroup = g;
        break;
      }
    }

    if (matchedGroup != null && matchedGroup.stories.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StoryViewerScreen(group: matchedGroup!),
        ),
      );
    } else if (_userStories.isNotEmpty) {
      final group = UserStoryGroup(
        userId: _effectiveUserId.toString(),
        userName: widget.displayName,
        userAvatar: widget.avatarUrl ?? '',
        isMyStory: isMe,
        stories: _userStories.map((s) {
          final copy = Map<String, dynamic>.from(s);
          if (copy['media_url'] != null) {
            copy['media_url'] =
                ApiClient.resolveUrl(copy['media_url'].toString()) ??
                copy['media_url'];
          }
          return StoryItem.fromJson(copy);
        }).toList(),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StoryViewerScreen(group: group)),
      );
    }
  }

  void _showPostDetailModal(Map<String, dynamic> item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PreviewPostDetailSheet(
        postData: item,
        authorName: widget.displayName,
        authorUsername: widget.username,
        authorAvatar: widget.avatarUrl ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

    final currentUser = ref.watch(authProvider).user;
    final followersCount =
        (_profileData?['followers_count'] as num?)?.toInt() ??
        currentUser?.followersCount ??
        0;
    final followingCount =
        (_profileData?['following_count'] as num?)?.toInt() ??
        currentUser?.followingCount ??
        0;
    final postsCount =
        (_profileData?['posts_count'] as num?)?.toInt() ??
        currentUser?.postsCount ??
        _userPosts.length;
    final createdAt =
        currentUser?.createdAt ??
        (_profileData?['created_at'] != null
            ? DateTime.tryParse(_profileData!['created_at'].toString())
            : null);
    final joinedText = createdAt != null
        ? 'Joined ${DateFormat('MMMM yyyy').format(createdAt)}'
        : 'Joined ${DateTime.now().year}';

    final effectiveBio = widget.bio.trim().isNotEmpty
        ? widget.bio.trim()
        : (currentUser?.bio?.trim().isNotEmpty == true
              ? currentUser!.bio!.trim()
              : 'Digital Creator & Entrepreneur • Building on MurihSpace');

    final effectiveLocation = widget.location.trim().isNotEmpty
        ? widget.location.trim()
        : (currentUser?.country ?? currentUser?.state ?? '');

    final effectiveWebsite = widget.website.trim().isNotEmpty
        ? widget.website.trim()
        : (currentUser?.website ?? '');

    final showHighlights = _viewMode == 'my' || _userStories.isNotEmpty;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'Preview Profile',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: Column(
        children: [
          // Segmented Toggle: [ Public View | My View ]
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _viewMode = 'public'),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _viewMode == 'public'
                              ? primaryBlue
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'Public View',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _viewMode == 'public'
                                  ? Colors.white
                                  : textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _viewMode = 'my'),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _viewMode == 'my'
                              ? primaryBlue
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'My View',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _viewMode == 'my'
                                  ? Colors.white
                                  : textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Scrollable Profile View
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Cover photo with overlapping avatar
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        image:
                            widget.bannerUrl != null &&
                                widget.bannerUrl!.isNotEmpty
                            ? DecorationImage(
                                image: CachedNetworkImageProvider(
                                  widget.bannerUrl!,
                                ),
                                fit: BoxFit.cover,
                              )
                            : null,
                        gradient:
                            widget.bannerUrl == null ||
                                widget.bannerUrl!.isEmpty
                            ? const LinearGradient(
                                colors: [Color(0xFF0F2B48), Color(0xFF1B64F2)],
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      left: 20,
                      bottom: -36,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3.5),
                            decoration: BoxDecoration(
                              color: cardBg,
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              radius: 38,
                              backgroundColor: primaryBlue.withValues(
                                alpha: 0.12,
                              ),
                              backgroundImage:
                                  widget.avatarUrl != null &&
                                      widget.avatarUrl!.isNotEmpty
                                  ? CachedNetworkImageProvider(
                                      widget.avatarUrl!,
                                    )
                                  : null,
                              child:
                                  widget.avatarUrl == null ||
                                      widget.avatarUrl!.isEmpty
                                  ? Text(
                                      widget.displayName.isNotEmpty
                                          ? widget.displayName[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        color: primaryBlue,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: primaryBlue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 44),

                // Name, Handle, Bio
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.displayName,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.verified_rounded,
                            color: primaryBlue,
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${widget.username}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        effectiveBio,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: textPrimary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Location & Website
                      Row(
                        children: [
                          if (effectiveLocation.isNotEmpty) ...[
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              effectiveLocation,
                              style: TextStyle(
                                fontSize: 12,
                                color: textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 14),
                          ],
                          if (effectiveWebsite.isNotEmpty) ...[
                            const Icon(
                              Icons.link_rounded,
                              size: 14,
                              color: primaryBlue,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                effectiveWebsite,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: primaryBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 13,
                            color: textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            joinedText,
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Dynamic Stats Row: Followers | Following | Posts
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              final targetId = _effectiveUserId;
                              if (targetId > 0) {
                                FollowersListDialog.show(
                                  context,
                                  title: 'Followers',
                                  isFollowersList: true,
                                  userId: targetId,
                                );
                              }
                            },
                            child: _statItem(
                              _formatCount(followersCount),
                              'Followers',
                              textPrimary,
                              textSecondary,
                            ),
                          ),
                          const SizedBox(width: 24),
                          GestureDetector(
                            onTap: () {
                              final targetId = _effectiveUserId;
                              if (targetId > 0) {
                                FollowersListDialog.show(
                                  context,
                                  title: 'Following',
                                  isFollowersList: false,
                                  userId: targetId,
                                );
                              }
                            },
                            child: _statItem(
                              _formatCount(followingCount),
                              'Following',
                              textPrimary,
                              textSecondary,
                            ),
                          ),
                          const SizedBox(width: 24),
                          GestureDetector(
                            onTap: () {
                              setState(() => _activeContentTab = 0);
                              _fetchTabPosts(0);
                            },
                            child: _statItem(
                              _formatCount(postsCount),
                              'Posts',
                              textPrimary,
                              textSecondary,
                            ),
                          ),
                        ],
                      ),

                      // Story Highlights Row (Dynamic Stories from Backend)
                      if (showHighlights) ...[
                        const SizedBox(height: 18),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              if (_viewMode == 'my')
                                _highlightCircle(
                                  '+ New',
                                  isPlus: true,
                                  onTap: () => showStoryComposerSheet(context),
                                ),
                              ..._userStories.map((story) {
                                final caption =
                                    (story['caption'] as String? ?? '').trim();
                                final label = caption.isNotEmpty
                                    ? caption
                                    : 'Story';
                                final mediaUrl =
                                    story['media_url'] as String? ?? '';
                                return _highlightCircle(
                                  label,
                                  imageUrl: mediaUrl,
                                  onTap: () => _handleStoryTap(story),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Content Tabs: Posts | Reels | Live | Tagged
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: borderColor),
                      bottom: BorderSide(color: borderColor),
                    ),
                  ),
                  child: Row(
                    children: [
                      _tabHeaderItem(0, 'Posts', textPrimary, textSecondary),
                      _tabHeaderItem(1, 'Reels', textPrimary, textSecondary),
                      _tabHeaderItem(2, 'Live', textPrimary, textSecondary),
                      _tabHeaderItem(3, 'Tagged', textPrimary, textSecondary),
                    ],
                  ),
                ),

                // Dynamic 3-column media grid / empty state / loading state
                if (_loadingPosts)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: primaryBlue,
                        ),
                      ),
                    ),
                  )
                else if (_currentTabPosts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 40,
                      horizontal: 24,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _activeContentTab == 0
                                ? Icons.grid_on_outlined
                                : _activeContentTab == 1
                                ? Icons.movie_creation_outlined
                                : _activeContentTab == 2
                                ? Icons.videocam_outlined
                                : Icons.assignment_ind_outlined,
                            size: 32,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _activeContentTab == 0
                              ? 'No Posts Yet'
                              : _activeContentTab == 1
                              ? 'No Reels Yet'
                              : _activeContentTab == 2
                              ? 'No Live Streams'
                              : 'No Tagged Posts',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _activeContentTab == 0
                              ? 'When posts are published, they will appear here.'
                              : _activeContentTab == 1
                              ? 'Video reels will appear here.'
                              : _activeContentTab == 2
                              ? 'Recorded live streams will appear here.'
                              : 'Posts you are tagged in will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(2),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                          childAspectRatio: 1.0,
                        ),
                    itemCount: _currentTabPosts.length,
                    itemBuilder: (ctx, i) {
                      final item = _currentTabPosts[i];
                      final mediaUrls = item['media_urls'] is List
                          ? item['media_urls'] as List
                          : [];
                      final imageUrl = mediaUrls.isNotEmpty
                          ? mediaUrls.first.toString()
                          : null;
                      final content = item['content'] as String? ?? '';
                      final likes = (item['likes_count'] as num?)?.toInt() ?? 0;
                      final isPinned = item['is_pinned'] == true;
                      final isReel =
                          _activeContentTab == 1 ||
                          item['type'] == 'reel' ||
                          item['video_url'] != null;
                      final isCarousel = mediaUrls.length > 1;

                      return GestureDetector(
                        onTap: () => _showPostDetailModal(item),
                        child: Container(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF1F5F9),
                          child: imageUrl != null && imageUrl.isNotEmpty
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CachedNetworkImage(
                                      imageUrl:
                                          ApiClient.resolveUrl(imageUrl) ??
                                          imageUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: isDark
                                            ? const Color(0xFF1E293B)
                                            : const Color(0xFFE2E8F0),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                            color: isDark
                                                ? const Color(0xFF1E293B)
                                                : const Color(0xFFE2E8F0),
                                            child: const Icon(
                                              Icons.broken_image_outlined,
                                              color: Colors.grey,
                                              size: 20,
                                            ),
                                          ),
                                    ),
                                    if (isPinned)
                                      Positioned(
                                        top: 4,
                                        left: 4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: primaryBlue,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.push_pin_rounded,
                                                color: Colors.white,
                                                size: 9,
                                              ),
                                              SizedBox(width: 2),
                                              Text(
                                                'Pinned',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 8.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    if (isReel)
                                      const Positioned(
                                        top: 4,
                                        right: 4,
                                        child: Padding(
                                          padding: EdgeInsets.all(2),
                                          child: Icon(
                                            Icons.play_arrow_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                      )
                                    else if (isCarousel)
                                      const Positioned(
                                        top: 4,
                                        right: 4,
                                        child: Padding(
                                          padding: EdgeInsets.all(2),
                                          child: Icon(
                                            Icons.filter_none_rounded,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                        ),
                                      ),
                                    Positioned(
                                      left: 6,
                                      bottom: 6,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.favorite_rounded,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            '$likes',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.black54,
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Center(
                                    child: Text(
                                      content,
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 80),
              ],
            ),
          ),

          // Bottom Fixed Button: Save Changes
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onSaveChanges();
                },
                child: const Text(
                  'Save Changes',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(
    String count,
    String label,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Row(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _highlightCircle(
    String label, {
    String? imageUrl,
    bool isPlus = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isPlus
                      ? primaryBlue.withValues(alpha: 0.3)
                      : primaryBlue,
                  width: 2,
                ),
                color: isPlus
                    ? primaryBlue.withValues(alpha: 0.08)
                    : const Color(0xFF1E293B),
              ),
              child: isPlus
                  ? const Icon(Icons.add_rounded, color: primaryBlue, size: 26)
                  : ClipOval(
                      child: (imageUrl != null && imageUrl.isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl:
                                  ApiClient.resolveUrl(imageUrl) ?? imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: const Color(0xFF1E293B),
                                child: const Icon(
                                  Icons.image_outlined,
                                  color: Colors.white54,
                                  size: 18,
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: const Color(0xFF1E293B),
                                child: const Icon(
                                  Icons.image_outlined,
                                  color: Colors.white54,
                                  size: 18,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.photo_library_outlined,
                              color: Colors.white70,
                              size: 20,
                            ),
                    ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              width: 62,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabHeaderItem(
    int index,
    String title,
    Color textPrimary,
    Color textSecondary,
  ) {
    final isActive = _activeContentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_activeContentTab != index) {
            setState(() => _activeContentTab = index);
            _fetchTabPosts(index);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? primaryBlue : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive ? primaryBlue : textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewPostDetailSheet extends StatelessWidget {
  final Map<String, dynamic> postData;
  final String authorName;
  final String authorUsername;
  final String authorAvatar;

  const _PreviewPostDetailSheet({
    required this.postData,
    required this.authorName,
    required this.authorUsername,
    required this.authorAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    final mediaUrls = postData['media_urls'] is List
        ? postData['media_urls'] as List
        : [];
    final imageUrl = mediaUrls.isNotEmpty ? mediaUrls.first.toString() : null;
    final content = postData['content'] as String? ?? '';
    final likes = (postData['likes_count'] as num?)?.toInt() ?? 0;
    final commentsCount = (postData['comments_count'] as num?)?.toInt() ?? 0;
    final createdAtStr = postData['created_at']?.toString();
    final createdAt = createdAtStr != null
        ? DateTime.tryParse(createdAtStr)
        : null;
    final dateFormatted = createdAt != null
        ? DateFormat('MMM d, yyyy • h:mm a').format(createdAt)
        : '';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(
                    0xFF1B64F2,
                  ).withValues(alpha: 0.12),
                  backgroundImage: authorAvatar.isNotEmpty
                      ? CachedNetworkImageProvider(
                          ApiClient.resolveUrl(authorAvatar) ?? authorAvatar,
                        )
                      : null,
                  child: authorAvatar.isEmpty
                      ? Text(
                          authorName.isNotEmpty
                              ? authorName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1B64F2),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              authorName,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            size: 14,
                            color: Color(0xFF1B64F2),
                          ),
                        ],
                      ),
                      Text(
                        '@$authorUsername',
                        style: TextStyle(
                          fontSize: 12,
                          color: textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl != null && imageUrl.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: CachedNetworkImage(
                        imageUrl: ApiClient.resolveUrl(imageUrl) ?? imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 220,
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF1F5F9),
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 160,
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF1F5F9),
                          child: const Icon(
                            Icons.broken_image_rounded,
                            size: 36,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (content.isNotEmpty)
                    Text(
                      content,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: textPrimary,
                      ),
                    ),

                  const SizedBox(height: 14),

                  if (dateFormatted.isNotEmpty)
                    Text(
                      dateFormatted,
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),

                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // Interactions row
                  Row(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.favorite_rounded,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '$likes likes',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: textSecondary,
                            size: 18,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '$commentsCount comments',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
