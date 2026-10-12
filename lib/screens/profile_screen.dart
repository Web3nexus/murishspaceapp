import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../core/design_tokens.dart';
import '../providers/auth_provider.dart';
import 'user_profile_screen.dart';

/// Complete Redesigned Edit Profile Screen matching MurihSpace visual reference:
/// Tabs: Personal, Interests, Links, Socials ·
/// Action Sheets: Update Profile Photo, Update Cover Photo ·
/// Details: Name, Username, Bio (0/200 live counter), Category, Location, DOB, Gender, Phone, Email, Toggles ·
/// Preview Profile mode synchronization.
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
  late TextEditingController _phoneController;
  late TextEditingController _emailController;

  // Socials controllers
  late TextEditingController _twitterController;
  late TextEditingController _instagramController;
  late TextEditingController _youtubeController;
  late TextEditingController _tiktokController;
  late TextEditingController _githubController;

  DateTime? _selectedBirthday;
  String _selectedGender = 'Male';
  String _selectedCategory = 'Content Creator';
  bool _showContactInfo = true;
  bool _isCreatorAccount = true;
  bool _showInterests = true;
  bool _allowTagging = true;

  final Set<String> _selectedTopics = {'Travel', 'Food', 'Technology', 'Photography'};
  final Set<String> _selectedLanguages = {'English', 'Spanish'};

  String? _avatarUrl;
  String? _bannerUrl;
  bool _isUploadingPhoto = false;
  bool _isUploadingBanner = false;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;

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
      text: [user?.state, user?.country].where((s) => s != null && s.isNotEmpty).join(', '),
    );
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _selectedBirthday = user?.birthday;
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
    _phoneController.dispose();
    _emailController.dispose();
    _twitterController.dispose();
    _instagramController.dispose();
    _youtubeController.dispose();
    _tiktokController.dispose();
    _githubController.dispose();
    super.dispose();
  }

  Future<void> _showProfilePhotoSheet() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2638) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Update Profile Photo',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              // Big circle preview with camera badge
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: DesignTokens.primary.withValues(alpha: 0.15),
                    backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(ApiClient.resolveUrl(_avatarUrl!) ?? _avatarUrl!)
                        : null,
                    child: _avatarUrl == null || _avatarUrl!.isEmpty
                        ? Text(
                            _displayNameController.text.isNotEmpty
                                ? _displayNameController.text[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: DesignTokens.primary),
                          )
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: DesignTokens.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: DesignTokens.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_camera_rounded, color: DesignTokens.primary, size: 20),
                ),
                title: Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadAvatar(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: DesignTokens.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: DesignTokens.primary, size: 20),
                ),
                title: Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadAvatar(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.crop_square_rounded, color: Color(0xFF8B5CF6), size: 20),
                ),
                title: Text('Choose an Avatar Frame', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Avatar frames available in VIP customization!')),
                  );
                },
              ),
              if (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
                  ),
                  title: const Text('Remove Photo', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _avatarUrl = null;
                      _hasUnsavedChanges = true;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
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

      final res = await ApiClient.instance.dio.post('/profile/avatar', data: form);
      final payload = ApiClient.instance.unwrap(res);
      final uploadedUrl = payload is Map<String, dynamic>
          ? (payload['avatar_url'] ?? payload['url'] ?? payload['avatar'])?.toString()
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload photo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _showCoverPhotoSheet() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2638) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Update Cover Photo',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              // Cover banner preview
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: const Color(0xFF161B26),
                  image: _bannerUrl != null && _bannerUrl!.isNotEmpty
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(ApiClient.resolveUrl(_bannerUrl!) ?? _bannerUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                  gradient: _bannerUrl == null || _bannerUrl!.isEmpty
                      ? const LinearGradient(colors: [Color(0xFF0F2B48), Color(0xFF1A68D4)])
                      : null,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: DesignTokens.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_camera_rounded, color: DesignTokens.primary, size: 20),
                ),
                title: Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadBanner(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: DesignTokens.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: DesignTokens.primary, size: 20),
                ),
                title: Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadBanner(ImageSource.gallery);
                },
              ),
              if (_bannerUrl != null && _bannerUrl!.isNotEmpty)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
                  ),
                  title: const Text('Remove Cover Photo', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _bannerUrl = null;
                      _hasUnsavedChanges = true;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
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

      final res = await ApiClient.instance.dio.post('/profile/banner', data: form);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload banner: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingBanner = false);
    }
  }

  Future<void> _saveProfileChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final countryParts = _locationController.text.split(',').map((s) => s.trim()).toList();
      final stateVal = countryParts.isNotEmpty ? countryParts.first : '';
      final countryVal = countryParts.length > 1 ? countryParts.sublist(1).join(', ') : stateVal;

      final body = {
        'name': _displayNameController.text.trim(),
        'username': _usernameController.text.trim(),
        'bio': _bioController.text.trim(),
        'state': stateVal,
        'country': countryVal,
        'phone': _phoneController.text.trim(),
        if (_selectedBirthday != null)
          'birthday': DateFormat('yyyy-MM-dd').format(_selectedBirthday!),
        if (_avatarUrl != null) 'avatar_url': _avatarUrl,
        if (_bannerUrl != null) 'banner_url': _bannerUrl,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes that will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Editing'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return shouldDiscard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F141C) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF161B26) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0);

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
                height: 34,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _isSaving ? null : _saveProfileChanges,
                  child: _isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(44),
            child: Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: TabBar(
                controller: _tab,
                isScrollable: false,
                labelColor: DesignTokens.primary,
                unselectedLabelColor: textSecondary,
                indicatorColor: DesignTokens.primary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
                    _buildPersonalTab(isDark, cardBg, textPrimary, textSecondary, borderColor, resolvedAvatar, resolvedBanner),
                    _buildInterestsTab(isDark, cardBg, textPrimary, textSecondary, borderColor),
                    _buildLinksTab(isDark, cardBg, textPrimary, textSecondary, borderColor),
                    _buildSocialsTab(isDark, cardBg, textPrimary, textSecondary, borderColor),
                  ],
                ),
              ),
              // Floating Bottom Bar: Preview Profile mode
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DesignTokens.primary,
                      side: const BorderSide(color: DesignTokens.primary, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final user = ref.read(authProvider).user;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserProfileScreen(
                            userId: user?.id ?? 0,
                            name: _displayNameController.text.trim().isNotEmpty
                                ? _displayNameController.text.trim()
                                : (user?.name ?? 'You'),
                            username: _usernameController.text.trim().isNotEmpty
                                ? _usernameController.text.trim()
                                : (user?.username ?? 'you'),
                            avatarUrl: resolvedAvatar ?? '',
                            bio: _bioController.text.trim(),
                            isPreview: true,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.visibility_rounded, size: 18),
                    label: const Text(
                      'Preview Profile',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
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
  // 1. Personal Tab (Hero Cover, Overlapping Avatar, Form Details)
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
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF161B26),
                image: resolvedBanner != null
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(resolvedBanner),
                        fit: BoxFit.cover,
                      )
                    : null,
                gradient: resolvedBanner == null
                    ? const LinearGradient(colors: [Color(0xFF0F2B48), Color(0xFF1A68D4)])
                    : null,
              ),
              child: _isUploadingBanner
                  ? Container(
                      color: Colors.black45,
                      child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                    )
                  : null,
            ),
            // "Change Cover" pill button
            Positioned(
              right: 14,
              bottom: 12,
              child: GestureDetector(
                onTap: _showCoverPhotoSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.camera_alt_outlined, color: Colors.white, size: 14),
                      SizedBox(width: 5),
                      Text(
                        'Change Cover',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Overlapping Large Avatar with camera badge
            Positioned(
              left: 20,
              bottom: -36,
              child: GestureDetector(
                onTap: _showProfilePhotoSheet,
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
                        backgroundColor: DesignTokens.primary.withValues(alpha: 0.15),
                        backgroundImage: resolvedAvatar != null ? CachedNetworkImageProvider(resolvedAvatar) : null,
                        child: resolvedAvatar == null
                            ? Text(
                                _displayNameController.text.isNotEmpty
                                    ? _displayNameController.text[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: DesignTokens.primary),
                              )
                            : null,
                      ),
                    ),
                    if (_isUploadingPhoto)
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: DesignTokens.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 48),

        // B. Personal Information Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 14),

              // Display Name
              _formField(
                label: 'Display Name *',
                controller: _displayNameController,
                hint: 'e.g. Lord Uzih',
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onClear: () => _displayNameController.clear(),
                validator: (v) => v == null || v.trim().isEmpty ? 'Display name is required' : null,
              ),
              const SizedBox(height: 12),

              // Username
              _formField(
                label: 'Username *',
                controller: _usernameController,
                hint: 'e.g. lorduzih',
                prefixText: '@ ',
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onClear: () => _usernameController.clear(),
                validator: (v) => v == null || v.trim().isEmpty ? 'Username is required' : null,
              ),
              const SizedBox(height: 12),

              // Bio with live 0/200 counter
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textSecondary)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF8FAFC),
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
                          style: TextStyle(fontSize: 14, color: textPrimary, height: 1.35),
                          decoration: InputDecoration(
                            hintText: 'Share a brief summary about who you are, what you build or create...',
                            hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                            border: InputBorder.none,
                            counterText: '',
                            isDense: true,
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            '$bioLength/200',
                            style: TextStyle(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Category Picker
              _clickableRow(
                label: 'Category',
                value: _selectedCategory,
                icon: Icons.work_outline_rounded,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () => _showCategoryPicker(),
              ),
              const SizedBox(height: 12),

              // Location
              _formField(
                label: 'Location',
                controller: _locationController,
                hint: 'e.g. Calpe, Spain',
                prefixIcon: Icons.location_on_outlined,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onClear: () => _locationController.clear(),
              ),

              const SizedBox(height: 24),

              // C. Details Section
              Text(
                'Details',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 14),

              // Date of Birth
              _clickableRow(
                label: 'Date of Birth',
                value: _selectedBirthday != null
                    ? DateFormat('MMM d, yyyy').format(_selectedBirthday!)
                    : 'Select Birthday',
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
              const SizedBox(height: 12),

              // Gender
              _clickableRow(
                label: 'Gender',
                value: _selectedGender,
                icon: Icons.person_outline_rounded,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () => _showGenderPicker(),
              ),
              const SizedBox(height: 12),

              // Phone Number
              _formField(
                label: 'Phone Number',
                controller: _phoneController,
                hint: '+34 612 345 678',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onClear: () => _phoneController.clear(),
              ),
              const SizedBox(height: 12),

              // Email Address (read-only / protected)
              _formField(
                label: 'Email Address',
                controller: _emailController,
                hint: 'user@example.com',
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF8FAFC),
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
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Let people see your contact info on your profile',
                            style: TextStyle(fontSize: 11, color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _showContactInfo,
                      activeColor: DesignTokens.primary,
                      onChanged: (v) => setState(() {
                        _showContactInfo = v;
                        _hasUnsavedChanges = true;
                      }),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 2. Interests Tab (Content Topics chips, Languages, About Me)
  // ─────────────────────────────────────────────────────────────
  Widget _buildInterestsTab(
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        Text(
          'Interests & Content',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose the topics you create or are interested in',
          style: TextStyle(fontSize: 12, color: textSecondary),
        ),
        const SizedBox(height: 14),

        // Topic chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? DesignTokens.primary : (isDark ? const Color(0xFF1E2638) : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? DesignTokens.primary : borderColor,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      topic,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textPrimary),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _selectedLanguages.contains(lang)
                        ? DesignTokens.primary
                        : (isDark ? const Color(0xFF1E2638) : Colors.white),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _selectedLanguages.contains(lang) ? DesignTokens.primary : borderColor,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_selectedLanguages.contains(lang)) ...[
                        const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        lang,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _selectedLanguages.contains(lang) ? Colors.white : textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // + Add Language
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('More languages coming soon!')),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: DesignTokens.primary),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: DesignTokens.primary, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Add Language',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: DesignTokens.primary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 28),

        // About Me Toggles
        Text(
          'About Me',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textPrimary),
        ),
        const SizedBox(height: 12),

        _toggleCard(
          title: 'Creator Account',
          subtitle: 'Show creator label on your profile',
          icon: Icons.workspace_premium_rounded,
          iconColor: const Color(0xFFF59E0B),
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
        const SizedBox(height: 10),
        _toggleCard(
          title: 'Show My Interests',
          subtitle: 'Display your interests on your profile',
          icon: Icons.interests_rounded,
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
        const SizedBox(height: 10),
        _toggleCard(
          title: 'Allow Tagging',
          subtitle: 'Let others tag you in their posts',
          icon: Icons.tag_rounded,
          iconColor: const Color(0xFF8B5CF6),
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
        const SizedBox(height: 30),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        Text(
          'Integrated Link-in-Bio',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textPrimary),
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
            color: isDark ? const Color(0xFF1E2638) : Colors.white,
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
                      color: DesignTokens.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.link_rounded, color: DesignTokens.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'murih.me/@$username',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textPrimary),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Active · Public link enabled',
                          style: TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.w600),
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
                    backgroundColor: DesignTokens.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => context.push('/link-in-bio'),
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text('Configure Link-in-Bio', style: TextStyle(fontWeight: FontWeight.w700)),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        Text(
          'Connected Social Accounts',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          'Display your connected social profiles on your MurihSpace profile.',
          style: TextStyle(fontSize: 12, color: textSecondary),
        ),
        const SizedBox(height: 16),

        _socialInput(label: 'X (Twitter)', prefix: '@', controller: _twitterController, isDark: isDark, cardBg: cardBg, borderColor: borderColor, textPrimary: textPrimary, textSecondary: textSecondary),
        const SizedBox(height: 12),
        _socialInput(label: 'Instagram', prefix: '@', controller: _instagramController, isDark: isDark, cardBg: cardBg, borderColor: borderColor, textPrimary: textPrimary, textSecondary: textSecondary),
        const SizedBox(height: 12),
        _socialInput(label: 'YouTube', prefix: 'youtube.com/', controller: _youtubeController, isDark: isDark, cardBg: cardBg, borderColor: borderColor, textPrimary: textPrimary, textSecondary: textSecondary),
        const SizedBox(height: 12),
        _socialInput(label: 'TikTok', prefix: '@', controller: _tiktokController, isDark: isDark, cardBg: cardBg, borderColor: borderColor, textPrimary: textPrimary, textSecondary: textSecondary),
        const SizedBox(height: 12),
        _socialInput(label: 'GitHub', prefix: 'github.com/', controller: _githubController, isDark: isDark, cardBg: cardBg, borderColor: borderColor, textPrimary: textPrimary, textSecondary: textSecondary),
      ],
    );
  }

  // Helpers
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
    VoidCallback? onClear,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textSecondary)),
        const SizedBox(height: 6),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF8FAFC),
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
                Text(prefixText, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textSecondary)),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  readOnly: readOnly,
                  keyboardType: keyboardType,
                  validator: validator,
                  style: TextStyle(fontSize: 14, color: textPrimary, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (suffixIcon != null)
                Icon(suffixIcon, size: 16, color: textSecondary)
              else if (onClear != null && controller.text.isNotEmpty && !readOnly)
                GestureDetector(
                  onTap: onClear,
                  child: Icon(Icons.cancel_rounded, size: 16, color: textSecondary),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _clickableRow({
    required String label,
    required String value,
    required IconData icon,
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
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textSecondary)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF8FAFC),
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
                    value,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textSecondary),
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
    required Color iconColor,
    required bool value,
    required bool isDark,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 11, color: textSecondary)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: DesignTokens.primary,
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
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textSecondary)),
        const SizedBox(height: 6),
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text(prefix, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary)),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: TextStyle(fontSize: 14, color: textPrimary),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true),
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
              child: Text('Select Category', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            ..._allCategories.map((c) => ListTile(
                  title: Text(c, style: TextStyle(fontWeight: c == _selectedCategory ? FontWeight.bold : FontWeight.normal)),
                  trailing: c == _selectedCategory ? const Icon(Icons.check_rounded, color: DesignTokens.primary) : null,
                  onTap: () {
                    setState(() {
                      _selectedCategory = c;
                      _hasUnsavedChanges = true;
                    });
                    Navigator.pop(ctx);
                  },
                )),
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
              child: Text('Select Gender', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            ...['Male', 'Female', 'Non-binary', 'Prefer not to say'].map((g) => ListTile(
                  title: Text(g, style: TextStyle(fontWeight: g == _selectedGender ? FontWeight.bold : FontWeight.normal)),
                  trailing: g == _selectedGender ? const Icon(Icons.check_rounded, color: DesignTokens.primary) : null,
                  onTap: () {
                    setState(() {
                      _selectedGender = g;
                      _hasUnsavedChanges = true;
                    });
                    Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );
  }
}
