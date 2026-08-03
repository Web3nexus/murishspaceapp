import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/roles.dart';
import 'package:mobile/models/chat_models.dart';
import 'package:mobile/providers/auth_provider.dart';
import 'package:mobile/providers/chat_provider.dart';
import 'package:mobile/providers/messages_provider.dart';
import 'package:mobile/providers/realtime_provider.dart';
import 'package:mobile/screens/conversation_screen.dart';

class _StubRealtime extends RealtimeService {
  _StubRealtime(super.ref);

  @override
  void enterConversation(int conversationId) {}
}

class _MessagesNotifier extends ConversationMessagesNotifier {
  _MessagesNotifier() : super(123);

  @override
  ConversationMessagesState build() {
    return const ConversationMessagesState(
      loading: false,
      messages: [
        Message(
          id: 1,
          conversationId: 123,
          userId: 9,
          content: 'Hello there',
          type: 'text',
          status: 'sent',
          user: ChatUser(id: 9, name: 'Ann', username: 'ann'),
        ),
        Message(
          id: 2,
          conversationId: 123,
          userId: 5,
          content: 'Hi Ann',
          type: 'text',
          status: 'sent',
        ),
      ],
    );
  }

  @override
  Future<void> sendTyping(bool isTyping) async {}

  @override
  Future<void> sendMessage({
    required String content,
    int? replyToId,
    int? mediaId,
    String? attachmentUrl,
    String? attachmentType,
  }) async {}
}

class _ConversationsNotifier extends ConversationsNotifier {
  @override
  ConversationsState build() {
    return const ConversationsState(
      conversations: [
        Conversation(id: 123, type: 'direct', title: 'Ann', otherUser: ChatUser(id: 9, name: 'Ann', username: 'ann')),
      ],
    );
  }
}

final _signedInUser = UserProfile(
  id: 5,
  name: 'Me',
  email: 'me@example.com',
  username: 'me',
  role: UserRole.member,
  kycStatus: 'pending',
  emailVerified: true,
);

void main() {
  Widget build() {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith(() => _AuthNotifier(_signedInUser)),
        conversationsProvider.overrideWith(_ConversationsNotifier.new),
        conversationMessagesProvider(123).overrideWith(_MessagesNotifier.new),
        realtimeProvider.overrideWith(_StubRealtime.new),
      ],
      child: const MaterialApp(
        home: ConversationScreen(conversationId: 123),
      ),
    );
  }

  testWidgets('renders messages and composer', (tester) async {
    await tester.pumpWidget(build());
    await tester.pump();

    expect(find.text('Hello there'), findsOneWidget);
    expect(find.text('Hi Ann'), findsOneWidget);
    expect(find.text('Message…'), findsOneWidget);
    expect(find.text('Ann'), findsWidgets); // app bar title + sender name
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
  });

  testWidgets('sending text clears the composer', (tester) async {
    await tester.pumpWidget(build());
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'a new message');
    await tester.pump();
    expect(find.text('a new message'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();

    // The composer input is cleared immediately (optimistic send).
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
  });
}

class _AuthNotifier extends AuthNotifier {
  final UserProfile profile;

  _AuthNotifier(this.profile);

  @override
  AuthState build() {
    return AuthState(user: profile, token: 'test-token');
  }
}
