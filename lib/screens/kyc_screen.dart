import 'package:flutter/material.dart';

/// Screen for displaying KYC status and submitting verification documents.
class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _docController = TextEditingController();
  bool _isSubmitting = false;
  String _status = 'pending';

  @override
  void dispose() {
    _docController.dispose();
    super.dispose();
  }

  void _handleSubmit() async {
    if (_docController.text.trim().isEmpty) return;
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _status = 'pending';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Identity verification document submitted!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Identity Verification (KYC)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.shield_outlined, size: 48, color: Colors.blue),
                    const SizedBox(height: 8),
                    const Text(
                      'Verification Status',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Chip(
                      label: Text(_status.toUpperCase()),
                      backgroundColor: Colors.amber.withValues(alpha: 0.2),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _docController,
              decoration: const InputDecoration(
                labelText: 'Passport or ID Reference',
                hintText: 'e.g. PASSPORT-12345678',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _handleSubmit,
              icon: const Icon(Icons.upload_file),
              label: _isSubmitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit Verification'),
            ),
          ],
        ),
      ),
    );
  }
}
