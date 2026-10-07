import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../providers/events_provider.dart';

/// Compact date block used on event cards, e.g. "OCT / 12".
///
/// Reading a month-over-day split from a list is much faster than parsing a
/// full date string, so the month is abbreviated to fit the tile.
class EventDateTile extends StatelessWidget {
  final DateTime? date;

  const EventDateTile({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (date == null) {
      return _tile(context, const Text('—'), const SizedBox.shrink());
    }
    return _tile(
      context,
      Text(
        DateFormat.MMM().format(date!).toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
      Text(
        DateFormat.d().format(date!),
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, Widget month, Widget day) {
    final theme = Theme.of(context);
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DefaultTextStyle.merge(
            style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
            child: month,
          ),
          const SizedBox(height: 2),
          DefaultTextStyle.merge(
            style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
            child: day,
          ),
        ],
      ),
    );
  }
}

/// Small pill describing the event format (`Online`, `In person`, `Hybrid`).
class EventTypeBadge extends StatelessWidget {
  final String eventType;

  const EventTypeBadge({super.key, required this.eventType});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = switch (eventType) {
      'in_person' => (Icons.place_rounded, theme.colorScheme.tertiary),
      'hybrid' => (Icons.merge_rounded, theme.colorScheme.secondary),
      _ => (Icons.videocam_rounded, theme.colorScheme.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            switch (eventType) {
              'in_person' => 'In person',
              'hybrid' => 'Hybrid',
              _ => 'Online',
            },
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// List tile for an event, used by the Events tab and the deep-link list.
class EventCard extends StatelessWidget {
  final EventModel event;
  final VoidCallback onTap;

  const EventCard({super.key, required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final capacity = event.capacity;
    final spotsLeft = capacity == null
        ? null
        : capacity - event.registrationCount;
    final soldOut = event.isFull || (spotsLeft != null && spotsLeft <= 0);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EventDateTile(date: event.startDate),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            event.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (event.isPast)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.history_rounded,
                              size: 16,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      event.startDate == null
                          ? 'Date to be announced'
                          : DateFormat.yMMMEd().add_jm().format(
                              event.startDate!,
                            ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        EventTypeBadge(eventType: event.eventType),
                        if (soldOut)
                          _Tag(label: 'Full', color: theme.colorScheme.error)
                        else if (spotsLeft != null)
                          _Tag(
                            label: '$spotsLeft left',
                            color: spotsLeft <= 5
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary,
                          ),
                        if (event.isRegistered)
                          _Tag(
                            label: 'Registered',
                            color: theme.colorScheme.primary,
                            icon: Icons.check_circle_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _Tag({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
