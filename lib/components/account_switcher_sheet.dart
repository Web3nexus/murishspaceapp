import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';
import '../core/design_tokens.dart';
import '../core/roles.dart';
import '../providers/auth_provider.dart';
import 'add_account_flow.dart';
import 'murih_icon.dart';

/// Opens the saved-accounts pop so the user can quickly switch profile or add
/// a new account inline with the phone + 6-digit code workflow.
Future<void> showAccountSwitcherSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AccountSwitcherSheet(),
  );
}

class _AccountSwitcherSheet extends ConsumerStatefulWidget {
  const _AccountSwitcherSheet();

  @override
  ConsumerState<_AccountSwitcherSheet> createState() => _AccountSwitcherSheetState();
}

class _AccountSwitcherSheetState extends ConsumerState<_AccountSwitcherSheet> {
  List<Map<String, dynamic>> _accounts = const [];
  bool _loading = true;
  int? _switchingTo;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final accounts = await ref.read(authProvider.notifier).getSavedAccounts();
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _loading = false;
    });
  }

  Future<void> _switchTo(Map<String, dynamic> account) async {
    final token = account['token'] as String?;
    final id = account['id'];
    final currentId = ref.read(authProvider).user?.id;
    if (token == null || id == currentId) return;

    setState(() => _switchingTo = id is int ? id : null);
    final ok = await ref.read(authProvider.notifier).switchSavedAccount(token);
    if (!mounted) return;
    setState(() => _switchingTo = null);

    if (ok) {
      final name = account['name'] as String? ?? 'account';
      final router = GoRouter.of(context);
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text('Switched to $name')));
      router.go('/app/profile');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not switch account. Please try again.')),
      );
    }
  }

  Future<void> _onAccountAdded(String name) async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text('Now signed in as $name')));
    router.go('/app/profile');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF161B26) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF17202B);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF667085);
    final borderColor = isDark ? const Color(0xFF2E384D) : const Color(0xFFE4E7EC);
    final currentId = ref.watch(authProvider).user?.id;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: _adding
            ? _buildAddMode(textPrimary, textSecondary)
            : _buildListMode(textPrimary, textSecondary, borderColor, currentId),
      ),
    );
  }

  Widget _buildListMode(
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
    int? currentId,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const SizedBox(width: 2),
            const MurihIcon('Swap', size: 20, color: DesignTokens.primary),
            const SizedBox(width: 8),
            Text(
              'Switch profile',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(
            'Choose an account to continue with.',
            style: TextStyle(fontSize: 12, color: textSecondary),
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
          )
        else if (_accounts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'No other saved accounts yet.',
              style: TextStyle(fontSize: 13, color: textSecondary),
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _accounts.length,
              separatorBuilder: (_, _) => Divider(height: 1, color: borderColor),
              itemBuilder: (_, index) {
                final account = _accounts[index];
                final id = account['id'];
                final isCurrent = id == currentId;
                final isSwitching = _switchingTo != null && _switchingTo == id;
                return _AccountTile(
                  account: account,
                  isCurrent: isCurrent,
                  isSwitching: isSwitching,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: isCurrent ? null : () => _switchTo(account),
                );
              },
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: DesignTokens.primary),
              foregroundColor: DesignTokens.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const MurihIcon('Add User', size: 18, color: DesignTokens.primary),
            label: const Text('Add account', style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: () => setState(() => _adding = true),
          ),
        ),
      ],
    );
  }

  Widget _buildAddMode(Color textPrimary, Color textSecondary) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
                onPressed: () => setState(() => _adding = false),
              ),
              const SizedBox(width: 4),
              Text(
                'Add account',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              'Sign in to another account with a code sent to your number.',
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
          ),
          const SizedBox(height: 12),
          AddAccountFlow(onSuccess: _onAccountAdded),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final Map<String, dynamic> account;
  final bool isCurrent;
  final bool isSwitching;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback? onTap;

  const _AccountTile({
    required this.account,
    required this.isCurrent,
    required this.isSwitching,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = account['name'] as String? ?? 'User';
    final username = account['username'] as String? ?? '';
    final email = account['email'] as String? ?? '';
    final phone = account['phone'] as String? ?? '';
    final role = UserRole.fromApi((account['role'] as String?) ?? 'member');
    final subtitle = phone.isNotEmpty ? phone : (email.isNotEmpty ? email : '@$username');
    final avatar = ApiClient.resolveUrl(account['avatar_url'] as String?);

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: DesignTokens.primary.withValues(alpha: 0.15),
        backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar) : null,
        child: avatar == null
            ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: DesignTokens.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              )
            : null,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: textPrimary),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '· ${role.label}',
            style: TextStyle(fontSize: 11, color: textSecondary),
          ),
        ],
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: textSecondary),
      ),
      trailing: isCurrent
          ? const Text(
              'Current',
              style: TextStyle(
                color: DesignTokens.primary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            )
          : isSwitching
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const MurihIcon('Swap', color: DesignTokens.textSecondary, size: 20),
    );
  }
}