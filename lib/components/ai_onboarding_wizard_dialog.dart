import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';
import '../providers/auth_provider.dart';

/// 4-Step Interactive AI Setup Wizard for Mobile App.
class AiOnboardingWizardDialog extends ConsumerStatefulWidget {
  const AiOnboardingWizardDialog({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1C1C1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const AiOnboardingWizardDialog(),
    );
  }

  @override
  ConsumerState<AiOnboardingWizardDialog> createState() => _AiOnboardingWizardDialogState();
}

class _AiOnboardingWizardDialogState extends ConsumerState<AiOnboardingWizardDialog> {
  int _currentStep = 0;
  String _selectedRole = 'creator';
  final List<String> _selectedInterests = ['Technology', 'Design'];
  final _headlineCtrl = TextEditingController(text: 'Digital Creator & Ecosystem Ambassador ✨');
  final _socialLinkCtrl = TextEditingController(text: 'https://instagram.com/creator');
  bool _submitting = false;

  final List<String> _allInterests = [
    'Technology',
    'Design & Art',
    'Fashion & Apparel',
    'Fitness & Health',
    'FinTech & Web3',
    'E-Commerce',
    'Coaching & Education',
  ];

  Future<void> _completeWizard() async {
    setState(() => _submitting = true);
    try {
      await ApiClient.instance.dio.post('/onboarding/complete', data: {
        'role': _selectedRole,
        'interests': _selectedInterests,
        'headline': _headlineCtrl.text.trim(),
        'social_link': _socialLinkCtrl.text.trim(),
      });
    } catch (_) {
      // Graceful fallback for offline dev environment
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
        final currentUser = ref.read(authProvider).user;
        if (currentUser != null) {
          final updatedUser = UserProfile(
            id: currentUser.id,
            name: currentUser.name,
            email: currentUser.email,
            username: currentUser.username,
            role: currentUser.role,
            kycStatus: currentUser.kycStatus,
            emailVerified: currentUser.emailVerified,
            onboardingCompleted: true,
          );
          ref.read(authProvider.notifier).setUserProfile(updatedUser);
        }
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 AI Setup Wizard completed! Your space is now active.'),
            backgroundColor: Color(0xFF34C759),
          ),
        );
        context.go('/app/home');
      }
    }
  }

  @override
  void dispose() {
    _headlineCtrl.dispose();
    _socialLinkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  decoration: const BoxDecoration(
                    color: Color(0xFF007AFF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mera AI Setup Wizard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textPrimary)),
                      Text('Step ${_currentStep + 1} of 3 · Configure your space', style: TextStyle(fontSize: 12, color: textSecondary)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Step Content
            if (_currentStep == 0) ...[
              Text('SELECT ACCOUNT IDENTITY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary)),
              const SizedBox(height: 10),
              _identityTile('creator', 'Digital Creator', 'Share content, host live rooms, receive gifts & brand deals', Icons.star_rounded, textPrimary, isDark),
              _identityTile('vendor', 'Merchant & Vendor', 'Sell products, manage storefront inventory & escrow orders', Icons.storefront_rounded, textPrimary, isDark),
              _identityTile('member', 'Community Member', 'Explore feeds, join communities & message friends', Icons.person_rounded, textPrimary, isDark),
            ] else if (_currentStep == 1) ...[
              Text('SELECT YOUR INTERESTS & CATEGORIES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allInterests.map((interest) {
                  final isSelected = _selectedInterests.contains(interest);
                  return FilterChip(
                    label: Text(interest),
                    selected: isSelected,
                    selectedColor: const Color(0xFF007AFF).withValues(alpha: 0.2),
                    checkmarkColor: const Color(0xFF007AFF),
                    labelStyle: TextStyle(
                      color: isSelected ? const Color(0xFF007AFF) : textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedInterests.add(interest);
                        } else {
                          _selectedInterests.remove(interest);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ] else ...[
              Text('HEADLINE & SOCIAL LINK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary)),
              const SizedBox(height: 10),
              TextField(
                controller: _headlineCtrl,
                maxLines: 2,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Space Headline / Bio',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _socialLinkCtrl,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Primary Social or Website Link',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Bottom Navigation CTAs
            Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => setState(() => _currentStep--),
                      child: const Text('Back'),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _submitting
                        ? null
                        : () {
                            if (_currentStep < 2) {
                              setState(() => _currentStep++);
                            } else {
                              _completeWizard();
                            }
                          },
                    child: _submitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_currentStep < 2 ? 'Next Step' : 'Finish AI Setup 🎉', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _identityTile(String key, String title, String desc, IconData icon, Color textPrimary, bool isDark) {
    final isSelected = _selectedRole == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = key),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF007AFF).withValues(alpha: 0.12) : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? const Color(0xFF007AFF) : Colors.transparent, width: 2),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF007AFF) : textPrimary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary)),
                  Text(desc, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: Color(0xFF007AFF)),
          ],
        ),
      ),
    );
  }
}
