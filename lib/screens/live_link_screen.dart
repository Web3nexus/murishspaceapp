import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';
import '../providers/auth_provider.dart';

class LiveLinkScreen extends ConsumerStatefulWidget {
  final String trackingId;
  final Map<String, String> queryParameters;

  const LiveLinkScreen({
    super.key,
    required this.trackingId,
    this.queryParameters = const {},
  });

  @override
  ConsumerState<LiveLinkScreen> createState() => _LiveLinkScreenState();
}

class _LiveLinkScreenState extends ConsumerState<LiveLinkScreen> {
  Map<String, dynamic>? _stream;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get(
        '/live/resolve/${Uri.encodeComponent(widget.trackingId)}',
        queryParameters: widget.queryParameters.isEmpty
            ? null
            : widget.queryParameters,
      );
      final payload =
          ApiClient.instance.unwrap(response) as Map<String, dynamic>;
      final stream = payload['stream'] as Map<String, dynamic>?;
      if (!mounted) return;
      if (stream == null) {
        setState(() {
          _loading = false;
          _error = 'This live stream is no longer available.';
        });
        return;
      }

      setState(() {
        _stream = stream;
        _loading = false;
      });
      _continueToStream(stream);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'We could not open this live stream.';
      });
    }
  }

  void _continueToStream(Map<String, dynamic> stream) {
    if (ref.read(authProvider).token == null) return;

    final streamId = (stream['id'] as num?)?.toInt();
    if (streamId == null) return;
    final host = stream['host'] as Map<String, dynamic>?;
    final community = stream['community'] as Map<String, dynamic>?;
    final query = <String, String>{
      'streamId': '$streamId',
      'trackingId':
          (stream['tracking_id'] as String?)?.trim() ?? widget.trackingId,
      'title': (stream['title'] as String?)?.trim().isNotEmpty == true
          ? (stream['title'] as String).trim()
          : 'Live Broadcast',
      'hostName': (host?['name'] as String?)?.trim().isNotEmpty == true
          ? (host!['name'] as String).trim()
          : 'Creator',
      'isHost': 'false',
      if (community?['name'] != null)
        'communityName': community!['name'].toString(),
    };
    final encodedQuery = query.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');
    context.go('/app/live?$encodedQuery');
  }

  void _openLogin() {
    final returnTo = '/live/${Uri.encodeComponent(widget.trackingId)}';
    context.go('/auth/login?returnTo=${Uri.encodeQueryComponent(returnTo)}');
  }

  @override
  Widget build(BuildContext context) {
    final host = _stream?['host'] as Map<String, dynamic>?;
    final hostName = (host?['name'] as String?)?.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Live broadcast')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const CircularProgressIndicator()
              : _error != null
              ? _ErrorState(message: _error!, onRetry: _resolve)
              : _LivePreview(
                  title:
                      (_stream?['title'] as String?)?.trim().isNotEmpty == true
                      ? (_stream!['title'] as String).trim()
                      : 'Live Broadcast',
                  hostName: hostName?.isNotEmpty == true
                      ? hostName!
                      : 'Creator',
                  isAuthenticated: ref.watch(authProvider).token != null,
                  onWatch: _continueToStreamFromState,
                ),
        ),
      ),
    );
  }

  void _continueToStreamFromState() {
    final stream = _stream;
    if (stream == null) return;
    if (ref.read(authProvider).token == null) {
      _openLogin();
      return;
    }
    _continueToStream(stream);
  }
}

class _LivePreview extends StatelessWidget {
  final String title;
  final String hostName;
  final bool isAuthenticated;
  final VoidCallback onWatch;

  const _LivePreview({
    required this.title,
    required this.hostName,
    required this.isAuthenticated,
    required this.onWatch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.sensors_rounded,
              size: 58,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Hosted by $hostName',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: onWatch,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(isAuthenticated ? 'Watch Live Broadcast' : 'Sign in to watch'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.wifi_off_rounded,
          size: 56,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(height: 16),
        Text(
          message,
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}
