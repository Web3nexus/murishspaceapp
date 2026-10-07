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
  final Set<String> _desiredChannels = {};

  RealtimeSocket? _socket;
  StreamSubscription<dynamic>? _sub;
  String? _socketId;
  bool _disposed = false;
  bool _connecting = false;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  Timer? _pongTimeoutTimer;

  /// Backoff base for auto-reconnect attempts.
  static const _reconnectInterval = Duration(seconds: 5);
  static const _pingInterval = Duration(seconds: 25);
  static const _pongTimeout = Duration(seconds: 12);

  /// Stream of broadcast events. Never throws; connection drops are silent.
  Stream<RealtimeEvent> get events => _events.stream;

  bool get isConnected => _socket != null && _socketId != null;

  /// Connects (idempotent) and subscribes to any channels requested earlier.
  /// Drops are auto-recovered by reconnecting and re-subscribing.
  Future<void> connect() async {
    if (_socket != null || _disposed || _connecting) return;
    _connecting = true;
    final uri = Uri.parse(
      '${Env.reverbScheme}://${Env.reverbHost}:${Env.reverbPort}/app/${Env.reverbAppKey}',
    );
    RealtimeSocket socket;
    try {
      socket = _openSocket(uri);
    } catch (_) {
      _connecting = false;
      _scheduleReconnect();
      return;
    }
    _socket = socket;
    _sub = socket.stream.listen(
      _onMessage,
      onDone: _onDone,
      onError: (_) => _onDone(),
      cancelOnError: true,
    );
    _connecting = false;
  }

  Future<void> reconnect() async {
    if (_disposed) return;
    _log('Manual reconnect requested');
    _forceReconnect();
  }

  void checkLiveness() {
    if (_disposed) return;
    if (_socket == null || _socketId == null) {
      connect();
    } else {
      _sendPing();
    }
  }

  Future<void> subscribe(String channel) async {
    _desiredChannels.add(channel);
    if (_socket == null || _socketId == null) return;
    await _sendSubscribe(channel);
  }

  void unsubscribe(String channel) {
    _desiredChannels.remove(channel);
    if (_socket != null && _socketId != null) {
      _send('pusher:unsubscribe', {'channel': channel});
    }
  }

  Future<void> _sendSubscribe(String channel) async {
    final auth = await _authorize(channel);
    if (auth == null) {
      _log('Subscription auth failed for $channel; will retry upon reconnect');
      return;
    }
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

  void _startHeartbeat() {
    _stopHeartbeat();
    _pingTimer = Timer.periodic(_pingInterval, (_) => _sendPing());
  }

  void _stopHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _pongTimeoutTimer?.cancel();
    _pongTimeoutTimer = null;
  }

  void _sendPing() {
    if (_socket == null) return;
    _send('pusher:ping', <String, dynamic>{});
    _pongTimeoutTimer?.cancel();
    _pongTimeoutTimer = Timer(_pongTimeout, () {
      _log('Missed pong heartbeat; forcing reconnection');
      _forceReconnect();
    });
  }

  void _forceReconnect() {
    _teardown();
    _socketId = null;
    _socket = null;
    _connecting = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    connect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectInterval, () {
      _reconnectTimer = null;
      if (!_disposed) {
        connect();
      }
    });
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
      _startHeartbeat();
      // Now that we know our socket id, authorize + subscribe all desired channels.
      final channels = List<String>.from(_desiredChannels);
      for (final c in channels) {
        _sendSubscribe(c);
      }
      return;
    }

    if (event == 'pusher:ping') {
      _send('pusher:pong', null);
      return;
    }
    if (event == 'pusher:pong') {
      _pongTimeoutTimer?.cancel();
      _pongTimeoutTimer = null;
      return;
    }
    if (event == 'pusher:error') {
      _log('Pusher error: ${frame['data']}');
      return;
    }

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
    _stopHeartbeat();
    _teardown();
    final hadSocket = _socket != null;
    _socketId = null;
    _socket = null;
    // Keep the desired channel list so a reconnect re-subscribes everything.
    if (_disposed || !hadSocket) return;
    _scheduleReconnect();
  }

  void _teardown() {
    _stopHeartbeat();
    _sub?.cancel();
    _sub = null;
    try {
      _socket?.close();
    } catch (_) {}
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _teardown();
    _socket = null;
    _events.close();
  }

  void _log(String message) {
    if (log) dev.log(message, name: 'reverb');
  }
}
