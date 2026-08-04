import 'package:flutter/material.dart';

import '../core/design_tokens.dart';

class InlineFieldError extends StatelessWidget {
  final String? error;

  const InlineFieldError({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    if (error == null || error!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, left: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            size: 14,
            color: DesignTokens.danger,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              error!,
              style: const TextStyle(
                fontSize: 12,
                color: DesignTokens.danger,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
