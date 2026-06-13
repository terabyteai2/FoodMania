/// Messenger conversation (spec §4.6) — mirrors `GET /admin/chatbot/chats`.
/// `needs` = the bot escalated to a manager; `replied` = a manager answered;
/// `bot` = the bot is handling it.
enum ChatStatus { needs, replied, bot }

extension ChatStatusX on ChatStatus {
  static ChatStatus parse(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'needs':
        return ChatStatus.needs;
      case 'replied':
        return ChatStatus.replied;
      default:
        return ChatStatus.bot;
    }
  }
}

enum ChatSender { customer, bot, manager, system }

extension ChatSenderX on ChatSender {
  static ChatSender parse(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'customer':
        return ChatSender.customer;
      case 'bot':
        return ChatSender.bot;
      case 'manager':
        return ChatSender.manager;
      default:
        return ChatSender.system;
    }
  }
}

class ChatMessage {
  ChatMessage({
    required this.sender,
    required this.text,
    this.kind,
    this.createdAt,
  });

  final ChatSender sender;
  final String text;
  final String? kind; // e.g. 'image'
  final DateTime? createdAt;

  bool get isImage => kind == 'image';

  factory ChatMessage.fromJson(Map<String, Object?> json) {
    return ChatMessage(
      sender: ChatSenderX.parse(json['from'] as String?),
      text: (json['text'] as String?) ?? '',
      kind: (json['kind'] as String?),
      createdAt: DateTime.tryParse(
        (json['at'] ?? json['time'] ?? json['createdAt'])?.toString() ?? '',
      )?.toLocal(),
    );
  }
}

class ChatThread {
  ChatThread({
    required this.id,
    required this.name,
    required this.handle,
    required this.status,
    required this.updatedAt,
    required this.messages,
    this.reason,
    this.lastUserMessage,
    this.unread = 0,
  });

  final String id;
  final String name;
  final String handle;
  final ChatStatus status;
  final DateTime updatedAt;
  final List<ChatMessage> messages;
  final String? reason;
  final String? lastUserMessage;
  final int unread;

  bool get needsAttention => status == ChatStatus.needs;

  factory ChatThread.fromJson(Map<String, Object?> json) {
    final rawMessages = (json['messages'] as List?) ?? const [];
    return ChatThread(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Messenger customer',
      handle: (json['handle'] as String?) ?? '',
      status: ChatStatusX.parse(json['status'] as String?),
      reason: (json['reason'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['reason'] as String?),
      lastUserMessage: (json['lastUserMessage'] as String?),
      unread: (json['unread'] as num?)?.toInt() ?? 0,
      updatedAt:
          DateTime.tryParse((json['updatedAt'] as String?) ?? '')?.toLocal() ??
          DateTime.now(),
      messages: rawMessages
          .whereType<Map>()
          .map((m) => ChatMessage.fromJson(Map<String, Object?>.from(m)))
          .toList(growable: false),
    );
  }
}
