import 'package:flutter/material.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/models/chat_thread.dart';

import '../theme/desk_theme.dart';

/// Messenger inbox (master–detail): customer threads on the left, the selected
/// conversation on the right with a reply composer. Reuses fetchChats /
/// replyToChat / handBackChat.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<ChatThread> _threads = [];
  ChatThread? _selected;
  bool _loading = true;
  bool _sending = false;
  final _reply = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final threads = await AppScope.read(context).fetchChats();
      if (!mounted) return;
      setState(() {
        _threads = threads;
        _selected = _selected == null
            ? (threads.isEmpty ? null : threads.first)
            : threads.firstWhere((t) => t.id == _selected!.id,
                orElse: () => threads.isEmpty ? _selected! : threads.first);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final thread = _selected;
    final text = _reply.text.trim();
    if (thread == null || text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final updated =
          await AppScope.read(context).replyToChat(thread.id, text);
      if (!mounted) return;
      _reply.clear();
      setState(() {
        _selected = updated;
        _threads = [
          for (final t in _threads) if (t.id == updated.id) updated else t,
        ];
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_threads.isEmpty) {
      return Center(
          child: Text('No conversations',
              style: TextStyle(color: PosColors.muted)));
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 300, child: _threadList()),
        Expanded(child: _detail()),
      ],
    );
  }

  Widget _threadList() {
    return Container(
      decoration: const BoxDecoration(
        color: PosColors.surface,
        border: Border(right: BorderSide(color: PosColors.line)),
      ),
      child: ListView.separated(
        itemCount: _threads.length,
        separatorBuilder: (_, _) => const Divider(height: 1, color: PosColors.line),
        itemBuilder: (_, i) {
          final t = _threads[i];
          final active = t.id == _selected?.id;
          return InkWell(
            onTap: () => setState(() => _selected = t),
            child: Container(
              color: active ? PosColors.primarySoft : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(t.name.isEmpty ? 'Customer' : t.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w700)),
                      ),
                      if (t.unread > 0)
                        Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                color: PosColors.primary,
                                shape: BoxShape.circle)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(t.lastUserMessage ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: PosColors.muted)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _detail() {
    final thread = _selected;
    if (thread == null) {
      return Center(
          child: Text('Select a conversation',
              style: TextStyle(color: PosColors.muted)));
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final message in thread.messages) _bubble(message),
            ],
          ),
        ),
        _composer(),
      ],
    );
  }

  Widget _bubble(ChatMessage message) {
    final fromCustomer = message.sender == ChatSender.customer;
    return Align(
      alignment: fromCustomer ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints: const BoxConstraints(maxWidth: 460),
        decoration: BoxDecoration(
          color: fromCustomer ? PosColors.surfaceSunk : PosColors.primary,
          borderRadius: BorderRadius.circular(PosRadii.md),
        ),
        child: Text(
          message.text,
          style: TextStyle(
              fontSize: 13.5,
              color: fromCustomer ? PosColors.primaryDark : Colors.white),
        ),
      ),
    );
  }

  Widget _composer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: PosColors.surface,
        border: Border(top: BorderSide(color: PosColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _reply,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Type a reply…',
                filled: true,
                fillColor: PosColors.surfaceSunk,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PosRadii.pill),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: PosColors.primary,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(14),
            ),
            onPressed: _sending ? null : _send,
            child: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}
