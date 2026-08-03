import 'package:flutter/material.dart';

import '../components/ui_states.dart';

/// Create tab landing (also reachable via deep link).
/// The central Create button in the shell opens the same options as a bottom sheet.
class CreateScreen extends StatelessWidget {
  const CreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create')),
      body: const EmptyStateWidget(
        icon: Icons.add_circle_outline,
        title: 'Create something new',
        description: 'Posts, stories, live sessions, communities, channels, products and events.',
      ),
    );
  }
}
