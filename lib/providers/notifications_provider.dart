import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/notification_models.dart';

class NotificationsState {
  final bool loading;
  final String? error;
  final List<AppNotification> notifications;
  final int unread;

  const NotificationsState({
    this.loading = false,
    this.error,
    this.notifications = const [],
    this.unread = 0,
  });

  NotificationsState copyWith({
    bool? loading,
    String? error,
    List<AppNotification>? notifications,
    int? unread,
    bool clearError = false,
  }) {
    return NotificationsState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      notifications: notifications ?? this.notifications,
      unread: unread ?? this.unread,
    );
  }
}

class NotificationsNotifier extends Notifier<NotificationsState> {
  Dio get _dio => ApiClient.instance.dio;

  @override
  NotificationsState build() {
    _load();
    return const NotificationsState(loading: true);
  }

  Future<void> _load({bool showLoading = false}) async {
    if (showLoading) state = state.copyWith(loading: true, clearError: true);
    try {
      final response = await _dio.get('/notifications');
      final payload = ApiClient.instance.unwrap(response);
      final paginator = payload is Map<String, dynamic> ? payload['data'] : payload;
      final rawList = paginator is Map<String, dynamic> ? paginator['data'] : paginator;
      final list = rawList is List
          ? rawList.whereType<Map<String, dynamic>>().map(AppNotification.fromJson).toList()
          : <AppNotification>[];
      final unread = payload is Map<String, dynamic> ? (payload['unread'] as num?)?.toInt() ?? 0 : 0;
      state = NotificationsState(notifications: list, unread: unread);
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: _errorMessage(e));
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Failed to load notifications.');
    }
  }

  Future<void> refresh() => _load(showLoading: true);

  Future<void> markRead(String id) async {
    final index = state.notifications.indexWhere((n) => n.id == id);
    if (index == -1) return;
    final current = state.notifications[index];
    if (current.read) return;
    final updated = AppNotification(
      id: current.id,
      type: current.type,
      data: current.data,
      read: true,
      createdAt: current.createdAt,
    );
    final list = [...state.notifications];
    list[index] = updated;
    state = state.copyWith(
      notifications: list,
      unread: (state.unread - 1).clamp(0, 1 << 31),
    );
    try {
      await _dio.post('/notifications/$id/read');
    } catch (_) {
      // Optimistic update: keep the local state as-is.
    }
  }

  Future<void> markAllRead() async {
    final updated = state.notifications.map((n) {
      if (n.read) return n;
      return AppNotification(id: n.id, type: n.type, data: n.data, read: true, createdAt: n.createdAt);
    }).toList();
    state = state.copyWith(notifications: updated, unread: 0);
    try {
      await _dio.post('/notifications/read-all');
    } catch (_) {
      // Optimistic update: keep the local state as-is.
    }
  }

  String _errorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) return data['message'] as String? ?? 'Failed to load notifications.';
    return 'Failed to load notifications.';
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, NotificationsState>(NotificationsNotifier.new);
