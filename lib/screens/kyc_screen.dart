import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../components/ui_states.dart';
import '../core/design_tokens.dart';
import '../core/permissions_service.dart';
import '../providers/auth_provider.dart';
import '../providers/kyc_provider.dart';
import '../providers/platform_provider.dart';

enum KycDocumentType {
  nationalId('national_id', 'National ID Card', Icons.badge_outlined, true),
  passport('passport', 'International Passport', Icons.flight_takeoff_rounded, false),
  driversLicense('drivers_license', "Driver's License", Icons.directions_car_outlined, true),
  voterCard('voter_card', "Voter's Card / NIN Slip", Icons.how_to_vote_outlined, true);

  final String value;
  final String label;
  final IconData icon;
  final bool requiresBack;

  const KycDocumentType(this.value, this.label, this.icon, this.requiresBack);
}

class KycScreen extends ConsumerStatefulWidget {
  const KycScreen({super.key});

  @override
  ConsumerState<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends ConsumerState<KycScreen> {
  int _currentStep = 0;
  KycDocumentType _selectedDocType = KycDocumentType.nationalId;

  final _nameController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  String _selectedCountry = 'Nigeria';

  XFile? _frontImage;
  XFile? _backImage;
  XFile? _selfieImage;

  bool _isSubmitting = false;
  bool _consentAgreed = true;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null && _nameController.text.isEmpty) {
        _nameController.text = user.name;
        if (user.country != null && user.country!.isNotEmpty) {
          _selectedCountry = user.country!;
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idNumberController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  Future<void> _pickImage({
    required Function(XFile) onPicked,
    required ImageSource source,
    CameraDevice preferredCamera = CameraDevice.rear,
  }) async {
    try {
      if (source == ImageSource.camera) {
        final hasPerm = await ref
            .read(permissionsProvider.notifier)
            .requestPermission(context, AppPermissionType.camera);
        if (!hasPerm && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera permission is required to capture documents.')),
          );
          return;
        }
      } else {
        final hasPerm = await ref
            .read(permissionsProvider.notifier)
            .requestPermission(context, AppPermissionType.photos);
        if (!hasPerm && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photos permission is required to select document.')),
          );
          return;
        }
      }

      final picked = await _picker.pickImage(
        source: source,
        preferredCameraDevice: preferredCamera,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (picked != null) {
        setState(() => onPicked(picked));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not capture photo: $e')),
        );
      }
    }
  }

  void _showImagePickerSheet({
    required String title,
    required Function(XFile) onPicked,
    CameraDevice preferredCamera = CameraDevice.rear,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: DesignTokens.surface,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: DesignTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose capture method. Make sure the document is clearly legible and well-lit.',
                  style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: DesignTokens.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: DesignTokens.primary),
                  ),
                  title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(
                      onPicked: onPicked,
                      source: ImageSource.camera,
                      preferredCamera: preferredCamera,
                    );
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: DesignTokens.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: DesignTokens.primary),
                  ),
                  title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(
                      onPicked: onPicked,
                      source: ImageSource.gallery,
                      preferredCamera: preferredCamera,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitVerification(KycNotifier notifier) async {
    if (_frontImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture the front of your document.')),
      );
      return;
    }

    if (_selectedDocType.requiresBack && _backImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture the back of your document.')),
      );
      return;
    }

    if (_selfieImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture your live selfie.')),
      );
      return;
    }

    if (!_consentAgreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to the verification terms to proceed.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final frontBytes = await _frontImage!.readAsBytes();
      final frontBase64 = 'data:image/jpeg;base64,${base64Encode(frontBytes)}';

      String? backBase64;
      if (_backImage != null) {
        final backBytes = await _backImage!.readAsBytes();
        backBase64 = 'data:image/jpeg;base64,${base64Encode(backBytes)}';
      }

      final selfieBytes = await _selfieImage!.readAsBytes();
      final selfieBase64 = 'data:image/jpeg;base64,${base64Encode(selfieBytes)}';

      final submissionPayload = {
        'document_type': _selectedDocType.value,
        'full_legal_name': _nameController.text.trim(),
        'id_number': _idNumberController.text.trim(),
        'country': _selectedCountry,
        'expiry_date': _expiryController.text.trim(),
        'front_url': frontBase64,
        'back_url': backBase64,
        'selfie_url': selfieBase64,
        'submitted_at': DateTime.now().toIso8601String(),
      };

      final ok = await notifier.submit(payload: {
        'kyc_document': jsonEncode(submissionPayload),
      });

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (ok) {
        ref.read(authProvider.notifier).refreshProfile();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: DesignTokens.success, size: 28),
                SizedBox(width: 8),
                Text('KYC Submitted!'),
              ],
            ),
            content: const Text(
              'Your identity documents have been safely encrypted and submitted for compliance review. Review usually completes within 1-3 hours.',
              style: TextStyle(fontSize: 14, color: DesignTokens.textSecondary),
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  notifier.refresh();
                },
                child: const Text('View Status'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.read(kycProvider).error ?? 'Submission failed. Please try again.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error preparing document upload: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(kycProvider);
    final notifier = ref.read(kycProvider.notifier);
    final status = state.status;

    final platformState = ref.watch(platformProvider);
    final isKycEnabled = platformState.config?.kycEnabled ?? true;

    if (!isKycEnabled) {
      return Scaffold(
        appBar: AppBar(title: const Text('Identity Verification')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Identity Verification is currently disabled by the platform.',
              textAlign: TextAlign.center,
              style: TextStyle(color: DesignTokens.textSecondary),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: DesignTokens.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignTokens.surface,
        title: const Text(
          'Identity Verification',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: DesignTokens.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.lock_outline_rounded, size: 13, color: DesignTokens.primary),
                SizedBox(width: 4),
                Text(
                  '256-Bit SSL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: DesignTokens.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => notifier.refresh(),
        child: _buildContent(context, state, status, notifier),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    KycState state,
    KycStatusInfo? status,
    KycNotifier notifier,
  ) {
    if (state.loading && status == null) {
      return const LoadingStateWidget(message: 'Loading verification status…');
    }
    if (state.error != null && status == null) {
      return ErrorStateWidget(
        title: 'Could not load verification',
        description: state.error!,
        onRetry: () => notifier.refresh(),
      );
    }

    // 1. If Verified: Show verified celebration card
    if (status != null && status.isVerified) {
      return _buildVerifiedView();
    }

    // 2. If Pending / In Review: Show in-review status
    if (status != null && status.isPending) {
      return _buildPendingView(notifier);
    }

    // 3. Otherwise show multi-step interactive KYC wizard
    return _buildWizardView(status, notifier);
  }

  Widget _buildVerifiedView() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: DesignTokens.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: DesignTokens.success.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: DesignTokens.success.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: DesignTokens.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_rounded, size: 44, color: DesignTokens.success),
              ),
              const SizedBox(height: 16),
              const Text(
                'Identity Verified',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: DesignTokens.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your government ID and biometric verification have been approved. All verified features across MurihSpace are unlocked.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: DesignTokens.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              _buildFeatureBenefit(Icons.lock_open_rounded, 'Escrow & Instant Payouts', 'Request direct bank and wallet withdrawals with zero limits.'),
              const SizedBox(height: 14),
              _buildFeatureBenefit(Icons.verified_outlined, 'Official Blue Checkmark', 'Activate your official verified checkmark in Settings.'),
              const SizedBox(height: 14),
              _buildFeatureBenefit(Icons.storefront_outlined, 'Storefront & Brand Deals', 'Publish unlimited products, coaching, and accept sponsor proposals.'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPendingView(KycNotifier notifier) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: DesignTokens.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: DesignTokens.warning.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: DesignTokens.warning.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hourglass_top_rounded, size: 40, color: DesignTokens.warning),
              ),
              const SizedBox(height: 16),
              const Text(
                'Verification In Review',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: DesignTokens.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Our compliance team is verifying your submitted identity documents. This process usually completes within 1-3 hours.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: DesignTokens.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => notifier.refresh(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh Status'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWizardView(KycStatusInfo? status, KycNotifier notifier) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Rejection Alert Banner if previously rejected
        if (status?.status == 'rejected') ...[
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: DesignTokens.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: DesignTokens.danger.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded, color: DesignTokens.danger, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Previous Submission Rejected',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: DesignTokens.danger),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status?.rejectionReason ?? 'The uploaded photos were unclear or expired. Please capture crisp photos below.',
                        style: const TextStyle(fontSize: 12, color: DesignTokens.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // Step Progress Bar
        _buildStepProgressBar(),
        const SizedBox(height: 20),

        // Step Content
        if (_currentStep == 0) _buildStep0DocumentDetails(),
        if (_currentStep == 1) _buildStep1Photos(),
        if (_currentStep == 2) _buildStep2Selfie(),
        if (_currentStep == 3) _buildStep3Review(notifier),
      ],
    );
  }

  Widget _buildStepProgressBar() {
    final steps = ['Document', 'Photos', 'Selfie', 'Submit'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: DesignTokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DesignTokens.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length, (index) {
          final isDone = index < _currentStep;
          final isCurrent = index == _currentStep;
          return Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? DesignTokens.success
                      : isCurrent
                          ? DesignTokens.primary
                          : DesignTokens.surfaceSecondary,
                  border: Border.all(
                    color: isCurrent ? DesignTokens.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isCurrent ? Colors.white : DesignTokens.textSecondary,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                steps[index],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                  color: isCurrent ? DesignTokens.textPrimary : DesignTokens.textSecondary,
                ),
              ),
              if (index < steps.length - 1) ...[
                const SizedBox(width: 8),
                Container(
                  width: 16,
                  height: 1.5,
                  color: isDone ? DesignTokens.success : DesignTokens.border,
                ),
                const SizedBox(width: 8),
              ],
            ],
          );
        }),
      ),
    );
  }

  Widget _buildStep0DocumentDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignTokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DesignTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '1. Select Government ID Type',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: DesignTokens.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose the official government-issued ID you want to verify.',
            style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary),
          ),
          const SizedBox(height: 16),
          ...KycDocumentType.values.map((type) {
            final isSelected = _selectedDocType == type;
            return GestureDetector(
              onTap: () => setState(() => _selectedDocType = type),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected ? DesignTokens.primary.withValues(alpha: 0.06) : DesignTokens.surfaceSecondary,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? DesignTokens.primary : DesignTokens.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      type.icon,
                      color: isSelected ? DesignTokens.primary : DesignTokens.textSecondary,
                      size: 24,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        type.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? DesignTokens.primary : DesignTokens.textPrimary,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle_rounded, color: DesignTokens.primary, size: 20),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            'Legal Information',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: DesignTokens.textPrimary),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Full Legal Name (as on ID)',
              hintText: 'e.g. Chukwuemeka Adebayo',
              filled: true,
              fillColor: DesignTokens.surfaceSecondary,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _idNumberController,
            decoration: InputDecoration(
              labelText: 'ID / NIN / Document Number',
              hintText: 'e.g. 12345678901',
              filled: true,
              fillColor: DesignTokens.surfaceSecondary,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedCountry,
            decoration: InputDecoration(
              labelText: 'Issuing Country',
              filled: true,
              fillColor: DesignTokens.surfaceSecondary,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
            items: const [
              DropdownMenuItem(value: 'Nigeria', child: Text('Nigeria 🇳🇬')),
              DropdownMenuItem(value: 'Ghana', child: Text('Ghana 🇬🇭')),
              DropdownMenuItem(value: 'Kenya', child: Text('Kenya 🇰🇪')),
              DropdownMenuItem(value: 'United Kingdom', child: Text('United Kingdom 🇬🇧')),
              DropdownMenuItem(value: 'United States', child: Text('United States 🇺🇸')),
              DropdownMenuItem(value: 'Canada', child: Text('Canada 🇨🇦')),
              DropdownMenuItem(value: 'Other', child: Text('Other Country 🌍')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedCountry = val);
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              if (_nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter your full legal name.')),
                );
                return;
              }
              if (_idNumberController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter your document ID number.')),
                );
                return;
              }
              setState(() => _currentStep = 1);
            },
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Continue to Document Photos', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1Photos() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignTokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DesignTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '2. Capture ${_selectedDocType.label}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: DesignTokens.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Place your ID on a flat surface in good lighting. Ensure all 4 corners are visible.',
            style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary),
          ),
          const SizedBox(height: 18),

          // Front of ID
          _buildCaptureBox(
            label: 'Front of Document',
            imageFile: _frontImage,
            onTap: () => _showImagePickerSheet(
              title: 'Capture Front of ID',
              onPicked: (img) => _frontImage = img,
            ),
            onRemove: () => setState(() => _frontImage = null),
          ),

          // Back of ID (if required)
          if (_selectedDocType.requiresBack) ...[
            const SizedBox(height: 16),
            _buildCaptureBox(
              label: 'Back of Document',
              imageFile: _backImage,
              onTap: () => _showImagePickerSheet(
                title: 'Capture Back of ID',
                onPicked: (img) => _backImage = img,
              ),
              onRemove: () => setState(() => _backImage = null),
            ),
          ],

          const SizedBox(height: 24),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _currentStep = 0),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(80, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Back'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    if (_frontImage == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please capture the front of your document.')),
                      );
                      return;
                    }
                    if (_selectedDocType.requiresBack && _backImage == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please capture the back of your document.')),
                      );
                      return;
                    }
                    setState(() => _currentStep = 2);
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Continue to Selfie', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Selfie() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignTokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DesignTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '3. Live Face Selfie with ID',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: DesignTokens.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Take a clear portrait selfie holding your document next to your face. Remove hats or glasses.',
            style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary),
          ),
          const SizedBox(height: 20),

          // Selfie Capture Frame
          Center(
            child: GestureDetector(
              onTap: () => _showImagePickerSheet(
                title: 'Capture Face Selfie',
                onPicked: (img) => _selfieImage = img,
                preferredCamera: CameraDevice.front,
              ),
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: DesignTokens.surfaceSecondary,
                  borderRadius: BorderRadius.circular(110),
                  border: Border.all(
                    color: _selfieImage != null ? DesignTokens.success : DesignTokens.primary,
                    width: 2.5,
                  ),
                ),
                child: _selfieImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(110),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(File(_selfieImage!.path), fit: BoxFit.cover),
                            Positioned(
                              bottom: 10,
                              right: 0,
                              left: 0,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Tap to Retake',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.face_retouching_natural_rounded, size: 54, color: DesignTokens.primary),
                          SizedBox(height: 10),
                          Text(
                            'Tap to Take Selfie',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: DesignTokens.primary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Front Camera',
                            style: TextStyle(fontSize: 11, color: DesignTokens.textSecondary),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          const SizedBox(height: 24),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _currentStep = 1),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(80, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Back'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    if (_selfieImage == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please take a selfie to continue.')),
                      );
                      return;
                    }
                    setState(() => _currentStep = 3);
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Review & Submit', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Review(KycNotifier notifier) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignTokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DesignTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '4. Review Verification Details',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: DesignTokens.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Please verify that all details match your official documents before submitting.',
            style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary),
          ),
          const SizedBox(height: 16),

          // Summary box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DesignTokens.surfaceSecondary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildSummaryRow('Document Type', _selectedDocType.label),
                const Divider(height: 18),
                _buildSummaryRow('Legal Name', _nameController.text.trim()),
                const Divider(height: 18),
                _buildSummaryRow('ID Number', _idNumberController.text.trim()),
                const Divider(height: 18),
                _buildSummaryRow('Country', _selectedCountry),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Photo Thumbnails Row
          const Text(
            'Attached Documents',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: DesignTokens.textPrimary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (_frontImage != null)
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(File(_frontImage!.path), height: 75, fit: BoxFit.cover),
                  ),
                ),
              if (_backImage != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(File(_backImage!.path), height: 75, fit: BoxFit.cover),
                  ),
                ),
              ],
              if (_selfieImage != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(File(_selfieImage!.path), height: 75, fit: BoxFit.cover),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Consent checkbox
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _consentAgreed,
            onChanged: (val) => setState(() => _consentAgreed = val ?? false),
            title: const Text(
              'I certify that the information and identity documents provided are genuine, authentic, and belong to me.',
              style: TextStyle(fontSize: 11, color: DesignTokens.textSecondary),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),

          const SizedBox(height: 20),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _currentStep = 2),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(80, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Back'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _isSubmitting ? null : () => _submitVerification(notifier),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: DesignTokens.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Submit Verification',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureBox({
    required String label,
    required XFile? imageFile,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: DesignTokens.textPrimary),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              color: DesignTokens.surfaceSecondary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: imageFile != null ? DesignTokens.success : DesignTokens.border,
                width: imageFile != null ? 1.5 : 1,
              ),
            ),
            child: imageFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(File(imageFile.path), fit: BoxFit.cover),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: onRemove,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Tap to Retake',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: DesignTokens.primary.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt_outlined, color: DesignTokens.primary, size: 28),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Tap to capture or upload $label',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: DesignTokens.primary),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'JPG, PNG (Max 10MB)',
                        style: TextStyle(fontSize: 10, color: DesignTokens.textSecondary),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: DesignTokens.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: DesignTokens.textPrimary)),
      ],
    );
  }

  Widget _buildFeatureBenefit(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: DesignTokens.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: DesignTokens.success, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: DesignTokens.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

