import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../core/design_tokens.dart';
import '../providers/community_provider.dart';
import '../providers/events_provider.dart';

/// Shows the create/edit event sheet.
///
/// Returns the created or updated [EventModel], or null if cancelled/failed.
/// Passing [initial] switches the sheet into edit mode: the fields are
/// prefilled and the save goes to `PUT /my-events/{id}` instead of
/// `POST /my-events`. The field set mirrors the web `CreateEventModal` so an
/// event authored on either surface describes identically.
Future<EventModel?> showEventEditorSheet(
  BuildContext context, {
  EventModel? initial,
}) {
  return showModalBottomSheet<EventModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1C1C1E)
        : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _EventEditorSheet(initial: initial),
  );
}

const List<String> _eventTypes = ['online', 'in_person', 'hybrid'];

String _typeLabel(String type) => switch (type) {
  'in_person' => 'In Person',
  'hybrid' => 'Hybrid',
  _ => 'Online',
};

class _EventEditorSheet extends ConsumerStatefulWidget {
  final EventModel? initial;

  const _EventEditorSheet({this.initial});

  @override
  ConsumerState<_EventEditorSheet> createState() => _EventEditorSheetState();
}

class _EventEditorSheetState extends ConsumerState<_EventEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _timezone;
  late final TextEditingController _location;
  late final TextEditingController _meetingUrl;
  late final TextEditingController _capacity;

  int? _communityId;
  late String _eventType;
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _deadline;
  String? _coverUrl;

  bool _uploadingCover = false;
  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final event = widget.initial;
    _title = TextEditingController(text: event?.title ?? '');
    _description = TextEditingController(text: event?.description ?? '');
    _timezone = TextEditingController(text: event?.timezone ?? 'UTC');
    _location = TextEditingController(text: event?.location ?? '');
    _meetingUrl = TextEditingController(text: event?.meetingUrl ?? '');
    _capacity = TextEditingController(
      text: event?.capacity == null ? '' : event!.capacity.toString(),
    );
    _communityId = event?.communityId;
    _eventType = event?.eventType ?? 'online';
    _startDate = event?.startDate;
    _endDate = event?.endDate;
    _deadline = event?.registrationDeadline;
    _coverUrl = event?.coverUrl;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _timezone.dispose();
    _location.dispose();
    _meetingUrl.dispose();
    _capacity.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked == null) return;

      setState(() => _uploadingCover = true);

      final bytes = await picked.readAsBytes();
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: picked.name),
        'folder': 'events/covers',
      });

      final res = await ApiClient.instance.dio.post('/upload', data: form);
      final payload = res.data;
      final url = payload is Map<String, dynamic>
          ? (payload['data']?['url'] ?? payload['url'])
          : null;

      if (!mounted) return;
      setState(() {
        _uploadingCover = false;
        if (url is String && url.isNotEmpty) _coverUrl = url;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploadingCover = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not upload image. Please try again.')),
      );
    }
  }

  Future<DateTime?> _pickDateTime(DateTime? current) async {
    final now = DateTime.now();
    final initial = current ?? now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Please enter an event title.');
      return;
    }
    if (!_isEdit && _communityId == null) {
      setState(() => _error = 'Please choose the community hosting this event.');
      return;
    }
    if (_startDate == null || _endDate == null) {
      setState(() => _error = 'Please set a start and end date.');
      return;
    }
    if (!_endDate!.isAfter(_startDate!)) {
      setState(() => _error = 'The end date must be after the start date.');
      return;
    }
    if (!_isEdit && !_startDate!.isAfter(DateTime.now())) {
      setState(() => _error = 'The start date must be in the future.');
      return;
    }
    if (_deadline != null && !_deadline!.isBefore(_startDate!)) {
      setState(() {
        _error = 'Registration must close before the event starts.';
      });
      return;
    }

    final location = _location.text.trim();
    final meetingUrl = _meetingUrl.text.trim();
    final timezone = _timezone.text.trim();
    final capacityText = _capacity.text.trim();

    final payload = <String, dynamic>{
      if (!_isEdit) 'community_id': _communityId,
      'title': title,
      'description': _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      'event_type': _eventType,
      'start_date': _startDate!.toUtc().toIso8601String(),
      'end_date': _endDate!.toUtc().toIso8601String(),
      'timezone': timezone.isEmpty ? 'UTC' : timezone,
      'location': location.isEmpty ? null : location,
      'meeting_url': meetingUrl.isEmpty ? null : meetingUrl,
      'capacity': capacityText.isEmpty ? null : int.tryParse(capacityText),
      'cover_url': _coverUrl,
      'registration_deadline': _deadline?.toUtc().toIso8601String(),
    };

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final mutations = ref.read(eventMutationsProvider);
      final event = _isEdit
          ? await mutations.update(widget.initial!.id, payload)
          : await mutations.create(payload);
      if (!mounted) return;
      Navigator.pop(context, event);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = eventErrorMessage(e, fallback: 'Could not save this event.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
    final media = MediaQuery.of(context);

    final communities = ref.watch(myCommunitiesProvider).communities;
    final noCommunity = !_isEdit && communities.isEmpty;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: media.viewInsets.bottom + 20,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight:
              media.size.height - media.padding.top - media.viewInsets.bottom - 36,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: DesignTokens.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isEdit
                          ? Icons.edit_calendar_rounded
                          : Icons.event_available_rounded,
                      color: DesignTokens.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEdit ? 'Edit Event' : 'Create Event',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          _isEdit
                              ? 'Update the details for your community.'
                              : 'Schedule a new event for your community.',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              _CoverPicker(
                isDark: isDark,
                coverUrl: _coverUrl,
                uploading: _uploadingCover,
                onTap: _uploadingCover ? null : _pickCover,
              ),
              const SizedBox(height: 16),

              if (_isEdit)
                _ReadOnlyCommunity(
                  isDark: isDark,
                  name: widget.initial!.communityName ?? 'Community',
                )
              else if (noCommunity)
                _InfoBanner(
                  isDark: isDark,
                  text:
                      'You need a community before scheduling an event. Create one first.',
                )
              else
                DropdownButtonFormField<int>(
                  initialValue: _communityId,
                  isExpanded: true,
                  dropdownColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                  style: TextStyle(color: textPrimary),
                  decoration: _fieldDecoration('Community *'),
                  items: [
                    for (final c in communities)
                      DropdownMenuItem(
                        value: c.id,
                        child: Text(
                          c.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: textPrimary),
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _communityId = v),
                ),
              const SizedBox(height: 12),

              TextField(
                controller: _title,
                maxLength: 255,
                style: TextStyle(color: textPrimary),
                decoration: _fieldDecoration('Event Title *', counter: true),
              ),
              const SizedBox(height: 4),

              TextField(
                controller: _description,
                maxLines: 4,
                style: TextStyle(color: textPrimary),
                decoration: _fieldDecoration('Description', hint: 'What is this event about?'),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _eventType,
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                      style: TextStyle(color: textPrimary),
                      decoration: _fieldDecoration('Event Type *'),
                      items: [
                        for (final t in _eventTypes)
                          DropdownMenuItem(
                            value: t,
                            child: Text(
                              _typeLabel(t),
                              style: TextStyle(color: textPrimary),
                            ),
                          ),
                      ],
                      onChanged: (v) =>
                          setState(() => _eventType = v ?? 'online'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _timezone,
                      style: TextStyle(color: textPrimary),
                      decoration: _fieldDecoration('Timezone', hint: 'UTC'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _DateTimeField(
                isDark: isDark,
                label: 'Starts *',
                value: _startDate,
                onTap: () async {
                  final picked = await _pickDateTime(_startDate);
                  if (picked != null) setState(() => _startDate = picked);
                },
                onClear: _startDate == null
                    ? null
                    : () => setState(() => _startDate = null),
              ),
              const SizedBox(height: 12),

              _DateTimeField(
                isDark: isDark,
                label: 'Ends *',
                value: _endDate,
                onTap: () async {
                  final picked = await _pickDateTime(_endDate);
                  if (picked != null) setState(() => _endDate = picked);
                },
                onClear: _endDate == null
                    ? null
                    : () => setState(() => _endDate = null),
              ),
              const SizedBox(height: 12),

              _DateTimeField(
                isDark: isDark,
                label: 'Registration closes (optional)',
                value: _deadline,
                onTap: () async {
                  final picked = await _pickDateTime(_deadline);
                  if (picked != null) setState(() => _deadline = picked);
                },
                onClear: _deadline == null
                    ? null
                    : () => setState(() => _deadline = null),
              ),
              const SizedBox(height: 12),

              if (_eventType != 'online') ...[
                TextField(
                  controller: _location,
                  style: TextStyle(color: textPrimary),
                  decoration: _fieldDecoration(
                    'Location',
                    hint: _eventType == 'hybrid'
                        ? 'Venue address (online link below)'
                        : 'Venue address',
                  ),
                ),
                const SizedBox(height: 12),
              ],

              if (_eventType != 'in_person') ...[
                TextField(
                  controller: _meetingUrl,
                  keyboardType: TextInputType.url,
                  style: TextStyle(color: textPrimary),
                  decoration: _fieldDecoration(
                    'Meeting URL',
                    hint: 'https://zoom.us/j/...',
                  ),
                ),
                const SizedBox(height: 12),
              ],

              TextField(
                controller: _capacity,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textPrimary),
                decoration: _fieldDecoration(
                  'Capacity',
                  hint: 'Leave empty for unlimited',
                ),
              ),
              const SizedBox(height: 12),

              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed:
                      (_submitting || noCommunity) ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _isEdit
                              ? Icons.save_rounded
                              : Icons.event_available_rounded,
                        ),
                  label: Text(
                    _submitting
                        ? 'Saving…'
                        : _isEdit
                        ? 'Save Changes'
                        : 'Create Event',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, {String? hint, bool counter = false}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      counterText: counter ? null : '',
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _CoverPicker extends StatelessWidget {
  final bool isDark;
  final String? coverUrl;
  final bool uploading;
  final VoidCallback? onTap;

  const _CoverPicker({
    required this.isDark,
    required this.coverUrl,
    required this.uploading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = coverUrl != null && coverUrl!.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 140,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(16),
          image: hasImage
              ? DecorationImage(image: NetworkImage(coverUrl!), fit: BoxFit.cover)
              : null,
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
          ),
        ),
        child: uploading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : hasImage
            ? Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_rounded, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Change Cover',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_rounded,
                    size: 30,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Upload Cover Image',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ReadOnlyCommunity extends StatelessWidget {
  final bool isDark;
  final String name;

  const _ReadOnlyCommunity({required this.isDark, required this.name});

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? Colors.white : Colors.black;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.forum_rounded, size: 18, color: DesignTokens.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final bool isDark;
  final String text;

  const _InfoBanner({required this.isDark, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DesignTokens.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: DesignTokens.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  final bool isDark;
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateTimeField({
    required this.isDark,
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
    final hasValue = value != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: hasValue && onClear != null
              ? IconButton(
                  onPressed: onClear,
                  icon: Icon(Icons.close_rounded, size: 18, color: textSecondary),
                )
              : const Icon(Icons.calendar_month_rounded, size: 18),
        ),
        child: Text(
          hasValue
              ? DateFormat.yMMMEd().add_jm().format(value!)
              : 'Not set',
          style: TextStyle(
            color: hasValue ? textPrimary : textSecondary,
          ),
        ),
      ),
    );
  }
}
