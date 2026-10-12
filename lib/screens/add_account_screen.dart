import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/add_account_flow.dart';
import '../core/design_tokens.dart';

/// Lets a signed-in user add (and immediately switch into) a second account
/// using the phone + 6-digit code workflow — the same one used at login —
/// without going through the login screen.
class AddAccountScreen extends ConsumerWidget {
  const AddAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = DesignTokens.textPrimaryOf(isDark);
    final textSecondary = DesignTokens.textSecondaryOf(isDark);
    final bg = DesignTokens.bgOf(isDark);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Add Account',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sign in to another MurihSpace account to switch between them instantly. '
                'A 6-digit code will be sent to confirm the number.',
                style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
              ),
              const SizedBox(height: 20),
              AddAccountFlow(
                onSuccess: (name) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Now signed in as $name')),
                  );
                  Navigator.of(context).pop(true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}