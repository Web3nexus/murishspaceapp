import 'package:flutter/material.dart';

import '../models/community_models.dart';

const _reasons = [
  'spam',
  'harassment',
  'inappropriate',
  'misinformation',
  'other',
];

const _reasonLabels = {
  'spam': 'Spam',
  'harassment': 'Harassment or bullying',
  'inappropriate': 'Inappropriate content',
  'misinformation': 'Misinformation',
  'other': 'Other',
};

/// Bottom sheet to report a post. Returns the chosen reason (or null).
Future<String?> showPostReportDialog(
  BuildContext context, {
  required Post post,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              'Report this post',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const Divider(height: 1),
          for (final reason in _reasons)
            ListTile(
              leading: const Icon(Icons.flag_outlined, size: 20),
              title: Text(_reasonLabels[reason] ?? reason),
              onTap: () => Navigator.pop(context, reason),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
