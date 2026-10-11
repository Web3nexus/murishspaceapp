import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';
import '../core/roles.dart';
import '../providers/auth_provider.dart';
import '../providers/events_provider.dart';
import '../widgets/event_card.dart';
import 'event_editor_sheet.dart';

enum _EventsTab {
  upcoming('Upcoming'),
  mine('My events'),
  attending('Going to');

  const _EventsTab(this.label);

  final String label;
}

/// In-app Events browser (`/app/events`).
///
/// Deliberately no "past" tab: `GET /api/v1/events` returns only the next 20
/// upcoming published events, so a locally filtered "past" list would look
/// authoritative while being silently incomplete. Upcoming, the user's own
/// events, and the user's upcoming registrations are the three views the API
/// can answer truthfully.
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: _EventsTab.values.length,
    vsync: this,
  );

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Event authoring requires the API's `creator` gate; vendors and plain
    // members get the browse-only view.
    final role = ref.watch(authProvider).user?.role;
    final canCreate = role == UserRole.creator || role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [for (final tab in _EventsTab.values) Tab(text: tab.label)],
        ),
        actions: [
          if (canCreate)
            IconButton(
              tooltip: 'Create event',
              onPressed: () => _createEvent(context),
              icon: const Icon(Icons.add_rounded),
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _EventList(provider: null),
          _EventList(owned: true),
          _EventList(registered: true),
        ],
      ),
    );
  }

  /// Opens the create-event composer and lands the creator on their own list
  /// once the event exists, where it can be published or edited.
  Future<void> _createEvent(BuildContext context) async {
    final event = await showEventEditorSheet(context);
    if (event == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${event.title}" created as a ${event.status}.')),
    );
    _tabs.animateTo(1);
  }
}

/// One tab of the events browser.
class _EventList extends ConsumerWidget {
  final int? provider;
  final bool owned;
  final bool registered;

  const _EventList({
    this.provider,
    this.owned = false,
    this.registered = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = switch ((owned, registered)) {
      (true, _) => ref.watch(myEventsProvider),
      (_, true) => ref.watch(myUpcomingEventsProvider),
      _ => ref.watch(eventsProvider(provider)),
    };

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _EventsError(
        message: _message(error),
        onRetry: () => switch ((owned, registered)) {
          (true, _) => ref.invalidate(myEventsProvider),
          (_, true) => ref.invalidate(myUpcomingEventsProvider),
          _ => ref.invalidate(eventsProvider(provider)),
        },
      ),
      data: (events) {
        if (events.isEmpty) {
          return _EventsEmpty(owned: owned, registered: registered);
        }
        return RefreshIndicator(
          onRefresh: () async {
            switch ((owned, registered)) {
              case (true, _):
                ref.invalidate(myEventsProvider);
              case (_, true):
                ref.invalidate(myUpcomingEventsProvider);
              default:
                ref.invalidate(eventsProvider(provider));
            }
            await Future<void>.delayed(const Duration(milliseconds: 400));
          },
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return EventCard(
                event: event,
                trailing: owned ? _OwnedEventActions(event: event) : null,
                onTap: () => context.push(
                  '/e/${Uri.encodeComponent(event.id.toString())}',
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _message(Object error) {
    if (error is ApiException && error.status == 403) {
      return 'You do not have permission to view this list.';
    }
    return 'We could not load events. Pull to try again.';
  }
}

class _EventsEmpty extends StatelessWidget {
  final bool owned;
  final bool registered;

  const _EventsEmpty({required this.owned, required this.registered});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, title, message) = owned
        ? (
            Icons.edit_calendar_rounded,
            "You haven't created any events",
            'Events you create will appear here for you to manage.',
          )
        : registered
        ? (
            Icons.event_seat_rounded,
            'No upcoming registrations',
            'Register for an event and it will show up here.',
          )
        : (
            Icons.event_rounded,
            'No upcoming events',
            'Check back soon — new events are announced here first.',
          );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EventsError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _EventsError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.bodyLarge,
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

/// Overflow menu for events the signed-in user created: edit the details, move
/// it between draft/published/cancelled, or delete it — the same actions the
/// web "My Events" dashboard exposes.
class _OwnedEventActions extends ConsumerWidget {
  final EventModel event;

  const _OwnedEventActions({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Manage event',
      icon: Icon(
        Icons.more_vert_rounded,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onSelected: (value) => _handle(context, ref, value),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: _MenuItem(icon: Icons.edit_rounded, label: 'Edit'),
        ),
        if (event.status == 'draft')
          const PopupMenuItem(
            value: 'publish',
            child: _MenuItem(icon: Icons.public_rounded, label: 'Publish'),
          ),
        if (event.status == 'published')
          const PopupMenuItem(
            value: 'cancel',
            child: _MenuItem(icon: Icons.event_busy_rounded, label: 'Cancel'),
          ),
        const PopupMenuItem(
          value: 'delete',
          child: _MenuItem(icon: Icons.delete_outline_rounded, label: 'Delete'),
        ),
      ],
    );
  }

  Future<void> _handle(BuildContext context, WidgetRef ref, String value) async {
    final messenger = ScaffoldMessenger.of(context);
    final mutations = ref.read(eventMutationsProvider);
    try {
      switch (value) {
        case 'edit':
          await showEventEditorSheet(context, initial: event);
        case 'publish':
          await mutations.publish(event.id, 'published');
          messenger.showSnackBar(const SnackBar(content: Text('Event published')));
        case 'cancel':
          await mutations.publish(event.id, 'cancelled');
          messenger.showSnackBar(const SnackBar(content: Text('Event cancelled')));
        case 'delete':
          final confirmed = await _confirmDelete(context, event.title);
          if (confirmed != true) return;
          await mutations.delete(event.id);
          messenger.showSnackBar(const SnackBar(content: Text('Event deleted')));
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            eventErrorMessage(e, fallback: 'Could not update this event.'),
          ),
        ),
      );
    }
  }

  Future<bool?> _confirmDelete(BuildContext context, String title) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete event'),
        content: Text('Delete "$title"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MenuItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}
