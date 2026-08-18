import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/greeting_provider.dart';

/// Shows modal bottom sheet for configuring Automated Greeting messages.
Future<void> showAutomatedGreetingSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1C1C1E)
        : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => const _AutomatedGreetingContent(),
  );
}

class _AutomatedGreetingContent extends ConsumerStatefulWidget {
  const _AutomatedGreetingContent();

  @override
  ConsumerState<_AutomatedGreetingContent> createState() =>
      __AutomatedGreetingContentState();
}

class __AutomatedGreetingContentState
    extends ConsumerState<_AutomatedGreetingContent> {
  late bool _isEnabled;
  late TextEditingController _messageController;
  int _delaySeconds = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(greetingProvider);
    _isEnabled = state.isEnabled;
    _messageController = TextEditingController(text: state.message);
    _delaySeconds = state.delaySeconds;
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _applyTemplate(String template) {
    setState(() {
      _messageController.text = template;
    });
  }

  void _insertVariable(String variable) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;

    final newText = text.replaceRange(start, end, variable);
    setState(() {
      _messageController.text = newText;
      _messageController.selection = TextSelection.collapsed(
        offset: start + variable.length,
      );
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await ref.read(greetingProvider.notifier).updateSettings(
          isEnabled: _isEnabled,
          message: _messageController.text.trim(),
          delaySeconds: _delaySeconds,
        );
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Automated greeting settings saved!'),
          backgroundColor: Color(0xFF34C759),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
    final cardBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final user = ref.watch(authProvider).user;

    final previewMessage = _messageController.text
        .replaceAll('{name}', 'Alex')
        .replaceAll('{time}', 'afternoon');

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Drag Handle & Title
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mark_chat_unread_rounded,
                      color: Color(0xFF007AFF),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Automated Greeting Message',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'Automatically reply to new client messages',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Master Switch Container
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enable Auto-Greeting',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'Sends automatically when a customer messages you',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                    Switch.adaptive(
                      value: _isEnabled,
                      activeColor: const Color(0xFF007AFF),
                      onChanged: (val) => setState(() => _isEnabled = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (_isEnabled) ...[
                // Preset Templates
                Text(
                  'Quick Preset Templates',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.storefront_rounded, size: 16),
                        label: const Text('Store Vendor'),
                        onPressed: () => _applyTemplate(
                          'Hi {name}! Welcome to ${user?.name ?? 'our shop'}. Check out our catalog and let us know if you have any questions!',
                        ),
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.video_library_rounded, size: 16),
                        label: const Text('Creator'),
                        onPressed: () => _applyTemplate(
                          'Hey {name}! Thanks for reaching out. Check out my latest content while I get back to you shortly!',
                        ),
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.support_agent_rounded, size: 16),
                        label: const Text('General Business'),
                        onPressed: () => _applyTemplate(
                          'Hi {name}! Thank you for contacting us. Our team will review your inquiry and respond shortly.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Variable Shortcut Chips
                Row(
                  children: [
                    Text(
                      'Insert Field:',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textSecondary),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _insertVariable('{name}'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '{name}',
                          style: TextStyle(
                              color: Color(0xFF007AFF),
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _insertVariable('{time}'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '{time}',
                          style: TextStyle(
                              color: Color(0xFF007AFF),
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Greeting Text Field
                TextField(
                  controller: _messageController,
                  maxLines: 4,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Enter your custom greeting message…',
                    hintStyle: TextStyle(color: textSecondary),
                    filled: true,
                    fillColor: cardBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 18),

                // Live Chat Bubble Preview
                Text(
                  'Live Preview',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF18191A)
                        : const Color(0xFFEFEFF4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                          bottomLeft: Radius.circular(4),
                        ),
                      ),
                      child: Text(
                        previewMessage.isEmpty
                            ? 'Your message preview will appear here'
                            : previewMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Save Action Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text(
                          'Save Greeting Settings',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
