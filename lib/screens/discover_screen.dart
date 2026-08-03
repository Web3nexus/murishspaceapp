import 'package:flutter/material.dart';

import '../components/ui_states.dart';

/// Discover tab (Phase 2). Empty state for now.
class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: const EmptyStateWidget(
        icon: Icons.explore_outlined,
        title: 'Explore MurihSpace',
        description: 'Find people, creators, communities, products and events.',
      ),
    );
  }
}
