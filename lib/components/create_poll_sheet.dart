import 'package:flutter/material.dart';

/// Clean Telegram-style modal bottom sheet for creating chat & community polls.
class CreatePollSheet extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>> onSubmit;

  const CreatePollSheet({super.key, required this.onSubmit});

  static Future<void> show(BuildContext context, {required ValueChanged<Map<String, dynamic>> onSubmit}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreatePollSheet(onSubmit: onSubmit),
    );
  }

  @override
  State<CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends State<CreatePollSheet> {
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _showWhoVoted = true;
  bool _isMultipleChoice = false;
  bool _allowAddingOptions = false;
  bool _allowRevoting = true;
  bool _isQuizMode = false;
  int? _correctOptionIndex;
  String _durationLimit = 'unlimited';

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length < 10) {
      setState(() {
        _optionControllers.add(TextEditingController());
      });
    }
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        final removed = _optionControllers.removeAt(index);
        removed.dispose();
        if (_correctOptionIndex == index) {
          _correctOptionIndex = null;
        } else if (_correctOptionIndex != null && _correctOptionIndex! > index) {
          _correctOptionIndex = _correctOptionIndex! - 1;
        }
      });
    }
  }

  void _submit() {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a poll question.')),
      );
      return;
    }

    final validOptions = _optionControllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    if (validOptions.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide at least 2 options.')),
      );
      return;
    }

    if (_isQuizMode && _correctOptionIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please tap the radio button next to the correct answer for Quiz Mode.')),
      );
      return;
    }

    Navigator.of(context).pop();
    widget.onSubmit({
      'question': question,
      'options': validOptions,
      'show_who_voted': _showWhoVoted,
      'is_multiple': _isMultipleChoice,
      'allow_adding_options': _allowAddingOptions,
      'allow_revoting': _allowRevoting,
      'is_quiz': _isQuizMode,
      'correct_option_index': _isQuizMode ? _correctOptionIndex : null,
      'duration_limit': _durationLimit,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final inputBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F4F7);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
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
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.poll_rounded, color: Color(0xFFFF9500), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Create a Poll',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: textSecondary, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Question label & field
            Text(
              'QUESTION',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textSecondary, letterSpacing: 0.8),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _questionController,
              autofocus: true,
              style: TextStyle(color: textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Ask a question…',
                hintStyle: TextStyle(color: textSecondary, fontSize: 14),
                filled: true,
                fillColor: inputBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),

            // Options header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'POLL OPTIONS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textSecondary, letterSpacing: 0.8),
                ),
                if (_isQuizMode)
                  const Text(
                    'Tap circle to select correct answer',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF34C759)),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Option fields
            for (int i = 0; i < _optionControllers.length; i++) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    if (_isQuizMode)
                      IconButton(
                        icon: Icon(
                          _correctOptionIndex == i ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: _correctOptionIndex == i ? const Color(0xFF34C759) : textSecondary,
                          size: 22,
                        ),
                        onPressed: () => setState(() => _correctOptionIndex = i),
                      ),
                    Expanded(
                      child: TextField(
                        controller: _optionControllers[i],
                        style: TextStyle(color: textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Option ${i + 1}',
                          hintStyle: TextStyle(color: textSecondary, fontSize: 14),
                          filled: true,
                          fillColor: inputBg,
                          prefixIcon: !_isQuizMode
                              ? Icon(Icons.radio_button_unchecked_rounded, size: 16, color: textSecondary)
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    if (_optionControllers.length > 2) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFFF3B30), size: 20),
                        onPressed: () => _removeOption(i),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Add option button
            if (_optionControllers.length < 10)
              TextButton.icon(
                onPressed: _addOption,
                icon: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF007AFF)),
                label: const Text('Add an option', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF007AFF))),
              ),
            const SizedBox(height: 12),
            const Divider(),

            // Settings Section
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'SETTINGS & PERMISSIONS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textSecondary, letterSpacing: 0.8),
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text('Show Who Voted', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary)),
              subtitle: Text('Voters and choices are visible to group members', style: TextStyle(fontSize: 12, color: textSecondary)),
              value: _showWhoVoted,
              activeColor: const Color(0xFF007AFF),
              onChanged: (val) => setState(() => _showWhoVoted = val),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text('Multiple Answers', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary)),
              subtitle: Text('Allow voters to select more than one option', style: TextStyle(fontSize: 12, color: textSecondary)),
              value: _isMultipleChoice,
              activeColor: const Color(0xFF007AFF),
              onChanged: _isQuizMode ? null : (val) => setState(() => _isMultipleChoice = val),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text('Allow Members to Add Options', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary)),
              subtitle: Text('Participants can contribute custom options', style: TextStyle(fontSize: 12, color: textSecondary)),
              value: _allowAddingOptions,
              activeColor: const Color(0xFF007AFF),
              onChanged: (val) => setState(() => _allowAddingOptions = val),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text('Allow Revoting', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary)),
              subtitle: Text('Voters can change their answer after submitting', style: TextStyle(fontSize: 12, color: textSecondary)),
              value: _allowRevoting,
              activeColor: const Color(0xFF007AFF),
              onChanged: (val) => setState(() => _allowRevoting = val),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text('Quiz Mode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary)),
              subtitle: Text('Set one correct answer. Feedback is revealed on vote.', style: TextStyle(fontSize: 12, color: textSecondary)),
              value: _isQuizMode,
              activeColor: const Color(0xFF34C759),
              onChanged: (val) => setState(() {
                _isQuizMode = val;
                if (val) _isMultipleChoice = false;
              }),
            ),
            const SizedBox(height: 8),

            // Limit Duration Dropdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Limit Duration', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary)),
                DropdownButton<String>(
                  value: _durationLimit,
                  dropdownColor: inputBg,
                  underline: const SizedBox.shrink(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF007AFF)),
                  items: const [
                    DropdownMenuItem(value: '24 hours', child: Text('24 Hours')),
                    DropdownMenuItem(value: '3 days', child: Text('3 Days')),
                    DropdownMenuItem(value: '7 days', child: Text('7 Days')),
                    DropdownMenuItem(value: 'unlimited', child: Text('Unlimited')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _durationLimit = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _submit,
                child: const Text('Send Poll', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

