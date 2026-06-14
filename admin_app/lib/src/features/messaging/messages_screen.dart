import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/chat_thread.dart';

/// Messages — Messenger takeover inbox (spec §4.6). Two segments
/// (Needs you / All chats) over `GET /admin/chatbot/chats`; websocket chat
/// signals trigger a REST refresh so the list stays current without polling.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _needsOnly = true;
  bool _loading = true;
  bool _refreshInFlight = false;
  Object? _error;
  List<ChatThread> _chats = const [];
  PosAppController? _app;
  StreamSubscription<Map<String, Object?>>? _chatEvents;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    if (!identical(_app, app)) {
      unawaited(_chatEvents?.cancel());
      _app = app;
      _chatEvents = app.chatEvents.listen((_) => _reload(silent: true));
      _reload();
    }
  }

  @override
  void dispose() {
    unawaited(_chatEvents?.cancel());
    super.dispose();
  }

  Future<void> _reload({bool silent = false}) async {
    if (_refreshInFlight) return;
    final app = _app ?? AppScope.of(context);
    _refreshInFlight = true;
    if (!silent && mounted) {
      setState(() {
        _loading = _chats.isEmpty;
        _error = null;
      });
    }
    try {
      final chats = await app.fetchChats();
      if (!mounted) return;
      setState(() {
        _chats = chats;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _loading = false;
          _error = error;
        });
      }
    } finally {
      _refreshInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    return AppScaffold(
      title: text.messages,
      subtitle: text.botLive,
      showDatePill: false,
      showBackButton: true,
      pinHeader: true,
      fillBody: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Segments(
            text: text,
            needsOnly: _needsOnly,
            needsCount: _chats.where((c) => c.needsAttention).length,
            onChanged: (v) => setState(() => _needsOnly = v),
          ),
          const SizedBox(height: 12),
          Expanded(child: _body(context, text)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, AppStrings text) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: PosColors.muted,
            ),
            const SizedBox(height: 12),
            TfText(
              text.chatsLoadFailed,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: PosColors.text,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 160,
              child: TfButton(
                label: text.isBn ? 'আবার চেষ্টা' : 'Retry',
                variant: TfButtonVariant.dark,
                onPressed: () => _reload(),
              ),
            ),
          ],
        ),
      );
    }
    final rows = _needsOnly
        ? _chats.where((c) => c.needsAttention).toList(growable: false)
        : _chats;
    if (rows.isEmpty) {
      return Center(
        child: TfEmptyState(
          icon: Icons.forum_outlined,
          title: _needsOnly ? text.noChatsNeedYou : text.noConversations,
          message: 'Customer Messenger chats will appear here.',
          messageBn: text.noConversationsHint,
        ),
      );
    }
    return RefreshIndicator(
      color: PosColors.primaryDark,
      backgroundColor: PosColors.primary,
      onRefresh: () => _reload(silent: true),
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _ChatRow(
          text: text,
          chat: rows[i],
          onTap: () async {
            await Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => ChatThreadScreen(chat: rows[i]),
              ),
            );
            _reload();
          },
        ),
      ),
    );
  }
}

class _Segments extends StatelessWidget {
  const _Segments({
    required this.text,
    required this.needsOnly,
    required this.needsCount,
    required this.onChanged,
  });

  final AppStrings text;
  final bool needsOnly;
  final int needsCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, bool value) {
      final on = value == needsOnly;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? PosColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(PosRadii.tag),
              border: Border.all(
                color: on ? PosColors.lineStrong : Colors.transparent,
              ),
            ),
            child: TfText(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: on ? PosColors.text : PosColors.textSec,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: PosColors.surfaceSunk,
        borderRadius: BorderRadius.circular(PosRadii.input),
        border: Border.all(color: PosColors.line),
      ),
      child: Row(
        children: [
          seg(text.needsYouCount(needsCount), true),
          seg(text.allChats, false),
        ],
      ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({required this.text, required this.chat, required this.onTap});

  final AppStrings text;
  final ChatThread chat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mins = DateTime.now().difference(chat.updatedAt).inMinutes;
    final initials = chat.name.trim().isEmpty
        ? '?'
        : chat.name
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((w) => w.characters.first)
              .join()
              .toUpperCase();
    final preview = (chat.lastUserMessage ?? '').trim().isNotEmpty
        ? chat.lastUserMessage!.trim()
        : (chat.messages.isNotEmpty ? chat.messages.last.text : '');
    return TfCard(
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: PosColors.surfaceSunk,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: TfText(
                initials,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: PosColors.text,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TfText(
                          chat.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: PosColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TfText(
                        text.agoMinutes(mins < 0 ? 0 : mins),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: PosColors.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (chat.unread > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: PosColors.warning,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: TfText(
                            '${chat.unread}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (preview.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    TfText(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: PosColors.textSec,
                      ),
                    ),
                  ],
                  if (chat.needsAttention) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: PosColors.warningSoft,
                        borderRadius: BorderRadius.circular(PosRadii.tag),
                      ),
                      child: TfText(
                        chat.reason ?? text.chatbotNeedsHelp,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: PosColors.warning,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The conversation thread (spec §4.6) — customer/bot/manager bubbles, an
/// amber escalation banner, context quick replies and a reply composer. Leaving
/// the thread silently hands control back to the bot when needed.
class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({required this.chat, super.key});

  final ChatThread chat;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  late ChatThread _chat = widget.chat;
  final TextEditingController _replyCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _sending = false;
  bool _refreshing = false;
  bool _refreshAgainAfterCurrent = false;
  bool _autoHandBackStarted = false;
  PosAppController? _app;
  StreamSubscription<Map<String, Object?>>? _chatEvents;

  @override
  void initState() {
    super.initState();
    _scrollToBottom(jump: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    if (!identical(_app, app)) {
      unawaited(_chatEvents?.cancel());
      _app = app;
      _chatEvents = app.chatEvents.listen(_onChatEvent);
      unawaited(_refreshChatFromServer());
    }
  }

  @override
  void dispose() {
    unawaited(_chatEvents?.cancel());
    _autoHandBackIfNeeded();
    _scrollCtrl.dispose();
    _replyCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      final target = _scrollCtrl.position.maxScrollExtent;
      if (jump) {
        _scrollCtrl.jumpTo(target);
        return;
      }
      _scrollCtrl.jumpTo(target);
    });
  }

  void _onChatEvent(Map<String, Object?> event) {
    if (event['type']?.toString() != 'chat_updated') return;
    final data = event['data'];
    String? conversationId;
    if (data is Map) {
      conversationId =
          data['conversationId']?.toString() ??
          data['conversation_id']?.toString() ??
          data['chatId']?.toString() ??
          data['id']?.toString();
    }
    if (conversationId != null &&
        conversationId.isNotEmpty &&
        conversationId != _chat.id) {
      return;
    }
    unawaited(_refreshChatFromServer());
  }

  Future<void> _refreshChatFromServer() async {
    if (_refreshing || _sending) {
      _refreshAgainAfterCurrent = true;
      return;
    }
    final app = _app ?? AppScope.of(context);
    _refreshing = true;
    try {
      final chats = await app.fetchChats();
      ChatThread? updated;
      for (final chat in chats) {
        if (chat.id == _chat.id) {
          updated = chat;
          break;
        }
      }
      final nextChat = updated;
      if (!mounted || nextChat == null) return;
      setState(() => _chat = nextChat);
      _scrollToBottom();
    } catch (_) {
      // Keep the visible thread stable; the next websocket event can retry.
    } finally {
      _refreshing = false;
      if (_refreshAgainAfterCurrent && mounted) {
        _refreshAgainAfterCurrent = false;
        unawaited(_refreshChatFromServer());
      }
    }
  }

  void _autoHandBackIfNeeded() {
    if (_autoHandBackStarted ||
        !(_chat.status == ChatStatus.needs ||
            _chat.status == ChatStatus.replied)) {
      return;
    }
    final app = _app;
    if (app == null) return;
    _autoHandBackStarted = true;
    unawaited(app.handBackChat(_chat.id).catchError((_) => _chat));
  }

  List<String> _quickReplies(String? reason) {
    final r = (reason ?? '').toLowerCase();
    if (r.contains('photo')) {
      return ['Sharing the photo now', "Here's our full menu"];
    }
    if (r.contains('deliver') || r.contains('quote')) {
      return ['Delivery is ৳60 to your area', 'We deliver there in ~40 min'];
    }
    if (r.contains('cater')) {
      return ["I'll call you about catering", 'Please share date & headcount'];
    }
    return ['Thanks for reaching out!', 'How can I help you today?'];
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sending) return;
    setState(() => _sending = true);
    final app = AppScope.of(context);
    try {
      final updated = await app.replyToChat(_chat.id, trimmed);
      if (!mounted) return;
      setState(() {
        _chat = updated;
        _replyCtrl.clear();
      });
      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: TfText(app.strings.replyFailed)));
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        if (_refreshAgainAfterCurrent) {
          _refreshAgainAfterCurrent = false;
          unawaited(_refreshChatFromServer());
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    return AppScaffold(
      title: _chat.name,
      subtitle: text.viaMessenger,
      showDatePill: false,
      showBackButton: true,
      pinHeader: true,
      fillBody: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                for (final m in _chat.messages) _Bubble(text: text, message: m),
              ],
            ),
          ),
          if (_chat.status == ChatStatus.needs ||
              _chat.status == ChatStatus.replied)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _HandedBackBadge(text: text),
            ),
          if (_chat.needsAttention)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final q in _quickReplies(_chat.reason))
                    _QuickReplyChip(label: q, onTap: () => _send(q)),
                ],
              ),
            ),
          _Composer(
            text: text,
            controller: _replyCtrl,
            sending: _sending,
            onSend: () => _send(_replyCtrl.text),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.message});

  final AppStrings text;
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.sender == ChatSender.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: PosColors.warningSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: PosColors.warning,
                ),
                const SizedBox(width: 6),
                TfText(
                  message.text.isEmpty ? text.chatbotNeedsHelp : message.text,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: PosColors.warning,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isCustomer = message.sender == ChatSender.customer;
    final isManager = message.sender == ChatSender.manager;
    final align = isCustomer ? Alignment.centerLeft : Alignment.centerRight;
    final bg = isCustomer
        ? PosColors.surfaceSunk
        : isManager
        ? PosColors.primaryDark
        : PosColors.accentSoft;
    final fg = isManager ? PosColors.onInk : PosColors.text;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: align,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.74,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.sender == ChatSender.bot) ...[
                  TfText(
                    text.bytesBot,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: PosColors.accentStrong,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                TfText(
                  message.isImage ? text.imageMessage : message.text,
                  style: TextStyle(fontSize: 14, color: fg, height: 1.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HandedBackBadge extends StatelessWidget {
  const _HandedBackBadge({required this.text});

  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: PosColors.warningSoft,
          borderRadius: BorderRadius.circular(PosRadii.tag),
          border: Border.all(color: PosColors.warning.withValues(alpha: 0.24)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.support_agent_outlined,
              size: 15,
              color: PosColors.warning,
            ),
            const SizedBox(width: 6),
            TfText(
              text.handedBackToYou,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: PosColors.warning,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickReplyChip extends StatelessWidget {
  const _QuickReplyChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: PosColors.accentSoft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: PosColors.primaryWash),
        ),
        child: TfText(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: PosColors.accentSoftInk,
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.text,
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final AppStrings text;
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: text.writeReplyHint,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SendButton(sending: sending, onSend: onSend),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.sending, required this.onSend});

  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PosColors.primary,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: sending ? null : onSend,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 48,
          height: 48,
          child: sending
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: PosColors.accentSoftInk,
                  ),
                )
              : const Icon(
                  Icons.send_rounded,
                  size: 20,
                  color: PosColors.accentSoftInk,
                ),
        ),
      ),
    );
  }
}
