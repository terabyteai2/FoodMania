import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/core/theme/app_theme.dart';
import 'package:local_pos/src/features/messaging/messages_screen.dart';
import 'package:local_pos/src/models/chat_thread.dart';
import 'package:local_pos/src/models/server_config.dart';
import 'package:local_pos/src/services/cloud_api_service.dart';

class _FakeChatApi extends CloudApiService {
  _FakeChatApi(this.responses, {this.completers});

  final List<List<ChatThread>> responses;
  final List<Completer<List<ChatThread>>>? completers;
  final List<String> handbacks = [];
  int fetchCount = 0;

  @override
  Future<List<ChatThread>> fetchChats() async {
    if (completers != null) {
      final index = fetchCount < completers!.length
          ? fetchCount
          : completers!.length - 1;
      fetchCount++;
      return completers![index].future;
    }
    final index = fetchCount < responses.length
        ? fetchCount
        : responses.length - 1;
    fetchCount++;
    return responses[index];
  }

  @override
  Future<ChatThread> handBackChat(String conversationId) async {
    handbacks.add(conversationId);
    return _chat(
      id: conversationId,
      status: ChatStatus.bot,
      message: 'Handed back',
    );
  }
}

ChatThread _chat({
  String id = 'chat-1',
  ChatStatus status = ChatStatus.needs,
  String message = 'hello',
}) {
  return ChatThread(
    id: id,
    name: 'Rumana',
    handle: '123456',
    status: status,
    updatedAt: DateTime(2026, 6, 11, 10),
    messages: [ChatMessage(sender: ChatSender.customer, text: message)],
    lastUserMessage: message,
    unread: status == ChatStatus.needs ? 1 : 0,
  );
}

PosAppController _controller(_FakeChatApi api) {
  return PosAppController(cloudApiService: api)
    ..language = AppLanguage.en
    ..serverConfig = ServerConfig(
      serverId: 'server-1',
      restaurantId: 'restaurant-1',
      outletId: 'outlet-1',
      restaurantName: 'Spice Garden',
      outletName: 'Dhanmondi',
    )
    ..cloudConfig = CloudConfig(
      baseUrl: 'https://quickbytes.test',
      enabled: true,
      deviceToken: 'device-token',
      autoSyncIntervalSeconds: 30,
    );
}

Widget _scoped(PosAppController controller) {
  return AppScope(
    controller: controller,
    child: MaterialApp(theme: AppTheme.light(), home: const MessagesScreen()),
  );
}

Widget _scopedThread(PosAppController controller, ChatThread chat) {
  return AppScope(
    controller: controller,
    child: MaterialApp(
      theme: AppTheme.light(),
      home: ChatThreadScreen(chat: chat),
    ),
  );
}

void main() {
  test(
    'chat thread parser accepts recent messages with optional timestamps',
    () {
      final chat = ChatThread.fromJson({
        'id': 'chat-1',
        'name': 'Rumana',
        'handle': '123456',
        'status': 'needs',
        'updatedAt': '2026-06-11T10:00:00Z',
        'messages': [
          {'from': 'customer', 'text': 'old style'},
          {'from': 'bot', 'text': 'new style', 'at': '2026-06-11T10:01:00Z'},
        ],
      });

      expect(chat.messages, hasLength(2));
      expect(chat.messages.first.text, 'old style');
      expect(chat.messages.first.createdAt, isNull);
      expect(chat.messages.last.sender, ChatSender.bot);
      expect(chat.messages.last.createdAt, isNotNull);
    },
  );

  testWidgets('messages inbox renders segments and degrades gracefully', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = PosAppController()..language = AppLanguage.en;

    await tester.pumpWidget(_scoped(controller));
    await tester.pump(); // didChangeDependencies + first build
    await tester.pump(const Duration(milliseconds: 50)); // future resolves

    expect(tester.takeException(), isNull);
    expect(find.text('All chats'), findsOneWidget);
    expect(find.textContaining('Needs you'), findsOneWidget);
    // With no cloud config the fetch fails → graceful retry state.
    expect(find.text('Retry'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('messages inbox refreshes when a chat websocket signal arrives', (
    tester,
  ) async {
    final api = _FakeChatApi([
      [_chat(message: 'first message')],
      [_chat(message: 'second message')],
    ]);
    final controller = _controller(api);

    await tester.pumpWidget(_scoped(controller));
    await tester.pump();
    await tester.pump();

    expect(find.text('first message'), findsOneWidget);

    controller.debugEmitChatEvent({
      'type': 'chat_updated',
      'data': {'conversationId': 'chat-1'},
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('second message'), findsOneWidget);
    expect(api.fetchCount, 2);

    controller.dispose();
  });

  testWidgets('chat thread refreshes only for matching chat events', (
    tester,
  ) async {
    final api = _FakeChatApi([
      [_chat(message: 'start')],
      [_chat(message: 'updated thread')],
    ]);
    final controller = _controller(api);

    await tester.pumpWidget(_scopedThread(controller, _chat(message: 'start')));
    await tester.pump();
    await tester.pump();

    controller.debugEmitChatEvent({
      'type': 'chat_updated',
      'data': {'conversationId': 'other-chat'},
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('start'), findsOneWidget);
    expect(api.fetchCount, 1);

    controller.debugEmitChatEvent({
      'type': 'chat_updated',
      'data': {'conversationId': 'chat-1'},
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('updated thread'), findsOneWidget);
    expect(api.fetchCount, 2);

    controller.dispose();
  });

  testWidgets(
    'chat thread queues websocket refresh while a refresh is in flight',
    (tester) async {
      final first = Completer<List<ChatThread>>();
      final second = Completer<List<ChatThread>>();
      final api = _FakeChatApi(const [], completers: [first, second]);
      final controller = _controller(api);

      await tester.pumpWidget(
        _scopedThread(controller, _chat(message: 'start')),
      );
      await tester.pump();

      controller.debugEmitChatEvent({
        'type': 'chat_updated',
        'data': {'conversationId': 'chat-1'},
      });
      await tester.pump();

      expect(api.fetchCount, 1);

      first.complete([_chat(message: 'first refresh')]);
      await tester.pump();
      await tester.pump();

      expect(api.fetchCount, 2);
      second.complete([_chat(message: 'queued refresh')]);
      await tester.pump();
      await tester.pump();

      expect(find.text('queued refresh'), findsOneWidget);

      controller.dispose();
    },
  );

  testWidgets('chat thread hides image and handback controls', (tester) async {
    final api = _FakeChatApi(const []);
    final controller = _controller(api);

    await tester.pumpWidget(_scopedThread(controller, _chat()));
    await tester.pump();

    expect(find.byIcon(Icons.image_outlined), findsNothing);
    expect(find.byIcon(Icons.smart_toy_outlined), findsNothing);
    expect(find.text('Handed back to you'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('leaving a human-controlled chat silently hands back to bot', (
    tester,
  ) async {
    final api = _FakeChatApi(const []);
    final controller = _controller(api);

    await tester.pumpWidget(
      _scopedThread(controller, _chat(status: ChatStatus.replied)),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(api.handbacks, ['chat-1']);

    controller.dispose();
  });

  testWidgets('leaving a bot-controlled chat does not hand back again', (
    tester,
  ) async {
    final api = _FakeChatApi(const []);
    final controller = _controller(api);

    await tester.pumpWidget(
      _scopedThread(controller, _chat(status: ChatStatus.bot)),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(api.handbacks, isEmpty);

    controller.dispose();
  });
}
