import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../config/env.dart';
import '../core/api_client.dart';
import '../providers/auth_provider.dart';
import '../providers/events_provider.dart';
import '../widgets/event_card.dart';

/// Event detail, reached either from a shared `/e/:id` link or from the
/// in-app Events list.
///
/// Event details are public (`GET /api/v1/events/{id}` needs no session), so
/// this screen renders for signed-out visitors too. Only the registration
/// action requires an account — and `register` is additionally behind the
/// API's `verified` middleware — so signing in happens at the moment of
/// intent, with a `returnTo` back to this exact event.
class EventDetailScreen extends ConsumerStatefulWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  bool _seeded = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(eventProvider(widget.eventId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event'),
        actions: [
          async.maybeWhen(
            data: (event) => IconButton(
              tooltip: 'Share event',
              onPressed: () => _share(context, event),
              icon: const Icon(Icons.ios_share_rounded),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      // Registering needs an account, so the action bar is also the sign-in
      // entry point for signed-out visitors.
      bottomNavigationBar: async.maybeWhen(
        data: (event) =>
            _EventActionBar(event: event, routeSegment: widget.eventId),
        orElse: () => const SizedBox.shrink(),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _EventError(
          message: _friendlyMessage(error),
          onRetry: () => ref.invalidate(eventProvider(widget.eventId)),
        ),
        data: (event) {
          // Adopt a server-supplied `is_registered` flag once per screen so
          // the in-memory registration set and the fetched event agree.
          if (!_seeded) {
            _seeded = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ref.read(eventRegistrationProvider.notifier).seed(event);
              }
            });
          }
          return _EventBody(event: event);
        },
      ),
    );
  }

  Future<void> _share(BuildContext context, EventModel event) async {
    await Clipboard.setData(ClipboardData(text: Env.absolute(event.sharePath)));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Event link copied')));
  }
}

String _friendlyMessage(Object error) {
  if (error is ApiException) {
    final message = error.message.toLowerCase();
    if (message.contains('not found')) {
      return 'This event is no longer available.';
    }
    return error.message;
  }
  return 'We could not load this event.';
}

/// Shared body so the in-app list can render a selected event without a
/// second network round trip when it already holds the model.
class _EventBody extends ConsumerWidget {
  final EventModel event;

  const _EventBody({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final registration = ref.watch(eventRegistrationProvider);

    final capacity = event.capacity;
    final spotsLeft = capacity == null
        ? null
        : capacity - event.registrationCount;

    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        if (event.coverUrl != null && event.coverUrl!.isNotEmpty)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              event.coverUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  EventTypeBadge(eventType: event.eventType),
                  if (event.isFeatured) ...[
                    const SizedBox(width: 8),
                    const _FeaturedChip(),
                  ],
                  if (event.isPast) ...[
                    const SizedBox(width: 8),
                    _Chip(label: 'Ended', color: theme.colorScheme.outline),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Text(
                event.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              _DetailRow(
                icon: Icons.event_rounded,
                label: 'When',
                value: _formatRange(event),
              ),
              if (event.timezone != null && event.timezone!.isNotEmpty)
                _DetailRow(
                  icon: Icons.public_rounded,
                  label: 'Timezone',
                  value: event.timezone!,
                ),
              if (event.location != null && event.location!.isNotEmpty)
                _DetailRow(
                  icon: Icons.place_rounded,
                  label: 'Where',
                  value: event.isOnline
                      ? '${event.location!} · Online'
                      : event.location!,
                ),
              _DetailRow(
                icon: Icons.group_rounded,
                label: 'Attending',
                value: spotsLeft == null
                    ? '${event.registrationCount} registered'
                    : '${event.registrationCount} registered · '
                          '${spotsLeft < 0 ? 0 : spotsLeft} spots left',
              ),
              if (event.registrationDeadline != null)
                _DetailRow(
                  icon: Icons.timer_outlined,
                  label: 'Register by',
                  value: DateFormat.yMMMd().add_jm().format(
                    event.registrationDeadline!,
                  ),
                ),
              if (event.creatorUsername != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _DetailRow(
                    icon: Icons.person_rounded,
                    label: 'Hosted by',
                    value: event.creatorName ?? event.creatorUsername!,
                    onTap: () => context.push(
                      '/u/${Uri.encodeComponent(event.creatorUsername!)}',
                    ),
                  ),
                ),
              if (event.communitySlug != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _DetailRow(
                    icon: Icons.forum_rounded,
                    label: 'Community',
                    value: event.communityName ?? event.communitySlug!,
                    onTap: () => context.push(
                      '/c/${Uri.encodeComponent(event.communitySlug!)}',
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              if (event.description != null && event.description!.isNotEmpty)
                Text(
                  event.description!,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
            ],
          ),
        ),
        if (registration.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Material(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        registration.error!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => ref
                          .read(eventRegistrationProvider.notifier)
                          .clearError(),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (registration.isRegistered(event.id))
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "You're registered for this event",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _EventActionBar extends ConsumerWidget {
  final EventModel event;

  /// The route segment the screen was opened with, used to invalidate the
  /// exact [eventProvider] family key this screen watches.
  final String routeSegment;

  const _EventActionBar({required this.event, required this.routeSegment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isAuthenticated = ref.watch(authProvider).token != null;
    final registration = ref.watch(eventRegistrationProvider);
    final isRegistered = registration.isRegistered(event.id);
    final isBusy = registration.mutatingId == event.id;
    final capacity = event.capacity;
    final spotsLeft = capacity == null
        ? null
        : capacity - event.registrationCount;
    final soldOut = event.isFull || (spotsLeft != null && spotsLeft <= 0);

    // A signed-out visitor is sent through login with a returnTo pointing back
    // at this event, so they land here — already signed in — with the button
    // still waiting for one tap.
    if (!isAuthenticated) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: FilledButton.icon(
            onPressed: () {
              final returnTo = '/e/${Uri.encodeComponent(event.id.toString())}';
              context.push(
                '/auth/login?returnTo=${Uri.encodeQueryComponent(returnTo)}',
              );
            },
            icon: const Icon(Icons.login_rounded),
            label: const Text('Sign in to register'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ),
      );
    }

    if (event.isPast) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: OutlinedButton.icon(
            onPressed: () => context.go('/app/events'),
            icon: const Icon(Icons.event_rounded),
            label: const Text('Browse upcoming events'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ),
      );
    }

    final notifier = ref.read(eventRegistrationProvider.notifier);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: FilledButton.icon(
          onPressed: (isBusy || soldOut)
              ? null
              : () {
                  final success = isRegistered
                      ? notifier.cancel(event.id, cacheKey: routeSegment)
                      : notifier.register(event.id, cacheKey: routeSegment);
                  success.then((ok) {
                    if (!ok || !context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isRegistered
                              ? 'Registration cancelled'
                              : "You're registered!",
                        ),
                      ),
                    );
                  });
                },
          icon: isBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  isRegistered
                      ? Icons.event_busy_rounded
                      : Icons.how_to_reg_rounded,
                ),
          label: Text(
            isBusy
                ? 'Updating…'
                : soldOut
                ? 'Event is full'
                : isRegistered
                ? 'Cancel registration'
                : 'Register for event',
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: isRegistered
                ? theme.colorScheme.errorContainer
                : null,
            foregroundColor: isRegistered
                ? theme.colorScheme.onErrorContainer
                : null,
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(value, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: row,
    );
  }
}

String _formatRange(EventModel event) {
  final start = event.startDate;
  final end = event.endDate;
  if (start == null) return 'Date to be announced';
  final day = DateFormat.yMMMEd().format(start);
  final time = DateFormat.jm().format(start);
  if (end == null) return '$day at $time';
  final sameDay = DateFormat.yMMMEd().format(end) == day;
  final endTime = DateFormat.jm().format(end);
  return sameDay
      ? '$day, $time – $endTime'
      : '$day, $time → ${DateFormat.yMMMEd().format(end)}, $endTime';
}

class _FeaturedChip extends StatelessWidget {
  const _FeaturedChip();

  @override
  Widget build(BuildContext context) =>
      _Chip(label: 'Featured', color: Theme.of(context).colorScheme.tertiary);
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EventError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _EventError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_busy_rounded,
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
        ),
      ),
    );
  }
}
