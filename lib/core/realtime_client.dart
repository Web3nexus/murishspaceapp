import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/env.dart';

/// A typed broadcast event delivered by the [ReverbClient].
class RealtimeEvent {
  final String event;
  final String channel;
  final dynamic data;

  const RealtimeEvent(this.event, this.channel, this.data);
}

/// Thin socket abstraction so the client is testable without a live WebSocket.
abstract class RealtimeSocket {
  Stream<dynamic> get stream;
  void add(String data);
  Future<void> close();
}

class _WebSocketChannelSocket implements RealtimeSocket {
  final WebSocketChannel channel;

  _WebSocketChannelSocket(this.channel);

  @override
  Stream<dynamic> get stream => channel.stream;

  @override
  void add(String data) => channel.sink.add(data);

  @override
  Future<void> close() => channel.sink.close();
}

/// Minimal Laravel Reverb client speaking the Pusher wire protocol.
///
/// - Connects to `ws(s)://host:port/app/{key}`.
/// - Authorizes private channels against `POST /broadcasting/auth` using the
///   server-assigned `socket_id`.
/// - Emits [RealtimeEvent] for every message received.
///
/// The transport is injected so tests can drive it with a fake channel.
class ReverbClient {
  ReverbClient({
    required Future<String?> Function(String url, Map<String, dynamic> body)
        postJson,
    RealtimeSocket Function(Uri uri)? openSocket,
    this.log = false,
  })  : _postJson = postJson,
        _openSocket = openSocket ?? _defaultOpen;

  final Future<String?> Function(String url, Map<String, dynamic> body) _postJson;
  final RealtimeSocket Function(Uri uri) _openSocket;
  final bool log;

  static RealtimeSocket _defaultOpen(Uri uri) =>
      _WebSocketChannelSocket(WebSocketChannel.connect(uri));

  final _events = StreamController<RealtimeEvent>.broadcast();
  final _pendingChannels = <String>[];

  RealtimeSocket? _socket;
  StreamSubscription<dynamic>? _sub;
  String? _socketId;
  bool _disposed = false;

  /// Stream of broadcast events. Never throws; connection drops are silent.
  Stream<RealtimeEvent> get events => _events.stream;

  bool get isConnected => _socket != null;

  /// Connects (idempotent) and subscribes to any channels requested earlier.
  Future<void> connect() async {
    if (_socket != null) return;
    final uri = Uri.parse(
      '${Env.reverbScheme}://${Env.reverbHost}:${Env.reverbPort}/app/${Env.reverbAppKey}',
    );
    RealtimeSocket socket;
    try {
      socket = _openSocket(uri);
    } catch (_) {
      return;
    }
    _socket = socket;
    _sub = socket.stream.listen(
      _onMessage,
      onDone: _onDone,
      onError: (_) => _onDone(),
      cancelOnError: true,
    );
  }

  Future<void> subscribe(String channel) async {
    if (_pendingChannels.contains(channel)) return;
    if (_socket == null) {
      _pendingChannels.add(channel);
      return;
    }
    _pendingChannels.add(channel);
    final auth = await _authorize(channel);
    if (auth == null) return;
    _send('pusher:subscribe', {'channel': channel, 'auth': auth});
  }

  Future<String?> _authorize(String channel) async {
    final socketId = _socketId;
    if (socketId == null) return null;
    return _postJson('/broadcasting/auth', {
      'socket_id': socketId,
      'channel_name': channel,
    });
  }

  void _send(String event, Object? data) {
    final payload = jsonEncode({
      'event': event,
      'data': data is String ? data : jsonEncode(data),
    });
    try {
      _socket?.add(payload);
    } catch (_) {
      // Ignore send failures (reconnect will re-subscribe).
    }
  }

  void _onMessage(dynamic raw) {
    final text = raw is String ? raw : (raw as dynamic)?.toString();
    if (text == null) return;
    Map<String, dynamic> frame;
    try {
      frame = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    _log('<= $frame');
    final event = frame['event'] as String?;
    if (event == null) return;

    if (event == 'pusher:connection_established') {
      final data = frame['data'];
      if (data is String) {
        try {
          _socketId = (jsonDecode(data) as Map<String, dynamic>)['socket_id'] as String?;
        } catch (_) {
          // ignore malformed handshake
        }
      }
      // Now that we know our socket id, authorize + subscribe.
      final channels = List<String>.from(_pendingChannels);
      _pendingChannels.clear();
      for (final c in channels) {
        subscribe(c);
      }
      return;
    }

    if (event == 'pusher:ping') {
      _send('pusher:pong', null);
      return;
    }
    if (event == 'pusher:pong' || event == 'pusher:error') return;

    final channel = frame['channel'] as String? ?? '';
    var data = frame['data'];
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        // keep raw string
      }
    }
    _events.add(RealtimeEvent(event, channel, data));
  }

  void _onDone() {
    _teardown();
    _socketId = null;
    _socket = null;
    // Keep pending channels so a later connect() re-subscribes.
    if (!_disposed) {
      _pendingChannels.clear();
    }
  }

  void _teardown() {
    _sub?.cancel();
    _sub = null;
  }

  void dispose() {
    _disposed = true;
    _teardown();
    try {
      _socket?.close();
    } catch (_) {}
    _socket = null;
    _events.close();
  }

  void _log(String message) {
    if (log) dev.log(message, name: 'reverb');
  }
}
