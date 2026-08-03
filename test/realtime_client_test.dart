import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/realtime_client.dart';

class _FakeSocket implements RealtimeSocket {
  final incoming = StreamController<dynamic>.broadcast();
  final List<String> sent = [];

  @override
  Stream<dynamic> get stream => incoming.stream;

  @override
  void add(String data) => sent.add(data);

  @override
  Future<void> close() async => incoming.close();

  void push(Map<String, dynamic> frame) {
    incoming.add(jsonEncode(frame));
  }
}

void main() {
  group('ReverbClient', () {
    test('authorizes private channel after handshake', () async {
      final socket = _FakeSocket();
      final authRequests = <Map<String, dynamic>>[];
      final client = ReverbClient(
        postJson: (url, body) async {
          authRequests.add(body);
          return 'signed-token';
        },
        openSocket: (_) => socket,
      );

      await client.connect();
      client.subscribe('private-conversation.5');

      // Server assigns the socket id.
      socket.push({
        'event': 'pusher:connection_established',
        'data': jsonEncode({'socket_id': '123.456'}),
      });
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(authRequests, hasLength(1));
      expect(authRequests.first['socket_id'], '123.456');
      expect(authRequests.first['channel_name'], 'private-conversation.5');

      final subscribeFrame = jsonDecode(socket.sent.last) as Map<String, dynamic>;
      expect(subscribeFrame['event'], 'pusher:subscribe');
      final data = jsonDecode(subscribeFrame['data'] as String) as Map<String, dynamic>;
      expect(data['channel'], 'private-conversation.5');
      expect(data['auth'], 'signed-token');

      client.dispose();
      await socket.incoming.close();
    });

    test('emits typed events for broadcasts', () async {
      final socket = _FakeSocket();
      final client = ReverbClient(
        postJson: (_, _) async => 'auth',
        openSocket: (_) => socket,
      );
      final received = <RealtimeEvent>[];
      client.events.listen(received.add);

      await client.connect();
      socket.push({
        'event': 'App\\Events\\MessageSent',
        'channel': 'private-conversation.5',
        'data': jsonEncode({'id': 9, 'content': 'hi', 'conversation_id': 5}),
      });
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.first.event, 'App\\Events\\MessageSent');
      expect(received.first.channel, 'private-conversation.5');
      final data = received.first.data as Map<String, dynamic>;
      expect(data['content'], 'hi');

      client.dispose();
      await socket.incoming.close();
    });

    test('replies to pusher ping and ignores handshake', () async {
      final socket = _FakeSocket();
      final client = ReverbClient(
        postJson: (_, _) async => null,
        openSocket: (_) => socket,
      );
      final received = <RealtimeEvent>[];
      client.events.listen(received.add);

      await client.connect();
      socket.push({'event': 'pusher:ping'});
      socket.push({
        'event': 'pusher:connection_established',
        'data': jsonEncode({'socket_id': '9.9'}),
      });
      await Future<void>.delayed(Duration.zero);

      expect(received, isEmpty);
      final last = jsonDecode(socket.sent.last) as Map<String, dynamic>;
      expect(last['event'], 'pusher:pong');

      client.dispose();
      await socket.incoming.close();
    });
  });
}
