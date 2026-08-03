import 'package:flutter/material.dart';

import '../components/ui_states.dart';

/// Communities tab (Phase 2). Empty state for now.
class CommunitiesScreen extends StatelessWidget {
  const CommunitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Communities')),
      body: const EmptyStateWidget(
        icon: Icons.groups_outlined,
        title: 'No communities yet',
        description: 'Join communities, channels, events and audio rooms.',
      ),
    );
  }
}
