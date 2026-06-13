// QuickBytes Desktop — Messages slide-over (Messenger takeover). Faithful to
// `desktop-messages.jsx`: the FB bot auto-answers and escalates; the manager
// replies in OUR UI. Bot bubbles = accent-tint + "BYTES BOT" label; escalations
// = amber banners; manager bubbles = solid ink. Wired to fetchChats /
// replyToChat / handBackChat on [PosAppController].

import 'package:flutter/material.dart';

import '../../../app_scope.dart';
import '../../../core/localization/app_strings.dart';
import '../../../models/chat_thread.dart';
import '../desk_controller.dart';
import 'dk_icons.dart';
import 'dk_kit.dart';

const Map<String, List<String>> _quickByReason = {
  'Photo requested': ['Send item photo', 'Share full menu'],
  'Delivery quote': ['Quote delivery charge', 'Within zone — standard rate'],
  'Catering ask': ['Send catering rates', 'Reserve the date'],
};

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '··';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

int _mins(DateTime t) {
  final m = DateTime.now().difference(t).inMinutes;
  return m < 0 ? 0 : m;
}

class MessagesOverlay extends StatefulWidget {
  const MessagesOverlay({required this.desk, this.onNeedsChanged, super.key});

  final DeskController desk;
  final ValueChanged<int>? onNeedsChanged;

  @override
  State<MessagesOverlay> createState() => _MessagesOverlayState();
}

class _MessagesOverlayState extends State<MessagesOverlay> {
  List<ChatThread> _chats = [];
  bool _loading = true;
  String _seg = 'needs';
  String? _openId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final chats = await AppScope.read(context).fetchChats();
      if (!mounted) return;
      setState(() {
        _chats = chats;
        _loading = false;
      });
      widget.onNeedsChanged?.call(chats.where((c) => c.status == ChatStatus.needs).length);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _isBn => AppScope.of(context).language == AppLanguage.bn;
  String _t(String en, String bn) => _isBn ? bn : en;

  ChatThread? get _open => _openId == null ? null : _chats.where((c) => c.id == _openId).firstOrNull;

  Future<void> _reply(String id, String text) async {
    if (text.trim().isEmpty) return;
    try {
      final updated = await AppScope.read(context).replyToChat(id, text.trim());
      if (!mounted) return;
      setState(() => _chats = [for (final c in _chats) if (c.id == id) updated else c]);
      widget.onNeedsChanged?.call(_chats.where((c) => c.status == ChatStatus.needs).length);
    } catch (e) {
      widget.desk.showToast('$e');
    }
  }

  Future<void> _handBack(String id) async {
    try {
      final updated = await AppScope.read(context).handBackChat(id);
      if (!mounted) return;
      setState(() {
        _chats = [for (final c in _chats) if (c.id == id) updated else c];
        _openId = null;
      });
      widget.onNeedsChanged?.call(_chats.where((c) => c.status == ChatStatus.needs).length);
    } catch (e) {
      widget.desk.showToast('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.desk.setMsgOpen(false),
            child: const ColoredBox(color: Color(0x4D14180E)),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          width: 440,
          child: Container(
            decoration: const BoxDecoration(color: Dk.surface, border: Border(left: BorderSide(color: Dk.line2))),
            child: _open != null ? _thread(_open!) : _inbox(),
          ),
        ),
      ],
    );
  }

  Widget _inbox() {
    final needs = _chats.where((c) => c.status == ChatStatus.needs).length;
    final list = _seg == 'needs' ? _chats.where((c) => c.status == ChatStatus.needs).toList() : _chats;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Dk.line))),
          child: Row(
            children: [
              Container(width: 34, height: 34, decoration: BoxDecoration(color: Dk.accentTint, borderRadius: BorderRadius.circular(8)), child: const Center(child: DkIcon('chat', size: 19, color: Dk.accentStrong))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_t('Messages', 'মেসেজ'), style: dkText(17, weight: FontWeight.w700)),
                    Text('${_t('Bot live', 'বট লাইভ')} · $needs ${_t('need you', 'টি আপনার সাহায্য চায়')}', style: dkText(12.5, color: Dk.muted)),
                  ],
                ),
              ),
              DkXBtn(icon: 'x', size: 34, onTap: () => widget.desk.setMsgOpen(false)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: DkSeg(
            selected: _seg,
            onSelect: (id) => setState(() => _seg = id),
            items: [
              DkSegItem('needs', '${_t('Needs you', 'সাহায্য চায়')}  $needs'),
              DkSegItem('all', _t('All chats', 'সব চ্যাট')),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : list.isEmpty
                  ? Center(child: Text(_t('No conversations.', 'কোনো চ্যাট নেই'), style: dkText(14, color: Dk.muted)))
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) => _inboxRow(list[i]),
                    ),
        ),
      ],
    );
  }

  Widget _inboxRow(ChatThread c) {
    final last = c.messages.isNotEmpty ? c.messages.last : null;
    final prefix = last == null ? '' : (last.sender == ChatSender.customer ? '' : (last.sender == ChatSender.bot ? '🤖 ' : '↩ '));
    return GestureDetector(
      onTap: () => setState(() => _openId = c.id),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Dk.line))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _avatar(c.name, 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: dkText(14.5, weight: FontWeight.w700))),
                        Text('${_mins(c.updatedAt)}m', style: dkText(11.5, color: Dk.placeholder)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('$prefix${last?.text ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: dkText(12.5, color: Dk.muted)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (c.status == ChatStatus.needs)
                          DkBadge(label: c.reason ?? _t('Needs you', 'সাহায্য চায়'), variant: DkBadgeVariant.warning, icon: 'warn')
                        else if (c.status == ChatStatus.replied)
                          DkBadge(label: _t('You replied', 'উত্তর দেওয়া হয়েছে'), variant: DkBadgeVariant.neutral)
                        else
                          DkBadge(label: _t('Bot handling', 'বট সামলাচ্ছে'), variant: DkBadgeVariant.tint, icon: 'bot'),
                        if (c.unread > 0) ...[
                          const SizedBox(width: 6),
                          DkBadge(label: '${c.unread}', variant: DkBadgeVariant.danger),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thread(ChatThread chat) {
    return _ChatThreadView(
      key: ValueKey(chat.id),
      chat: chat,
      isBn: _isBn,
      onBack: () => setState(() => _openId = null),
      onClose: () => widget.desk.setMsgOpen(false),
      onReply: (text) => _reply(chat.id, text),
      onHandBack: () => _handBack(chat.id),
    );
  }

  Widget _avatar(String name, double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: Dk.surface3, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(_initials(name), style: dkText(size * 0.33, weight: FontWeight.w700, color: Dk.ink2)),
    );
  }
}

class _ChatThreadView extends StatefulWidget {
  const _ChatThreadView({required this.chat, required this.isBn, required this.onBack, required this.onClose, required this.onReply, required this.onHandBack, super.key});
  final ChatThread chat;
  final bool isBn;
  final VoidCallback onBack;
  final VoidCallback onClose;
  final ValueChanged<String> onReply;
  final VoidCallback onHandBack;
  @override
  State<_ChatThreadView> createState() => _ChatThreadViewState();
}

class _ChatThreadViewState extends State<_ChatThreadView> {
  final TextEditingController _text = TextEditingController();
  final ScrollController _scroll = ScrollController();

  String _t(String en, String bn) => widget.isBn ? bn : en;

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(String t) {
    if (t.trim().isEmpty) return;
    widget.onReply(t.trim());
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    final quick = chat.status == ChatStatus.needs ? (_quickByReason[chat.reason] ?? const <String>[]) : const <String>[];
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Dk.line))),
          child: Row(
            children: [
              DkXBtn(icon: 'back', size: 34, onTap: widget.onBack),
              const SizedBox(width: 10),
              Container(width: 38, height: 38, decoration: const BoxDecoration(color: Dk.surface3, shape: BoxShape.circle), alignment: Alignment.center, child: Text(_initials(chat.name), style: dkText(13, weight: FontWeight.w700, color: Dk.ink2))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(chat.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: dkText(15, weight: FontWeight.w700)),
                    Text(_t('via Messenger', 'মেসেঞ্জার-এর মাধ্যমে'), style: dkText(12, color: Dk.muted)),
                  ],
                ),
              ),
              Tooltip(
                message: _t('Hand back to bot', 'বটের কাছে ফেরত'),
                child: GestureDetector(
                  onTap: widget.onHandBack,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(color: Dk.surface, borderRadius: BorderRadius.circular(Dk.rMd), border: Border.all(color: Dk.line2)),
                      child: const Center(child: DkIcon('bot', size: 20, color: Dk.accentStrong)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: Dk.bg,
            child: ListView.separated(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: chat.messages.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _bubble(chat.messages[i]),
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(color: Dk.surface, border: Border(top: BorderSide(color: Dk.line))),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (quick.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [for (final q in quick) DkChip(label: q, tint: true, active: true, onTap: () => _send(q))],
                  ),
                ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _send(_t('Item photo', 'আইটেমের ছবি')),
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(color: Dk.surface, borderRadius: BorderRadius.circular(Dk.rMd), border: Border.all(color: Dk.line2)),
                      child: const Center(child: DkIcon('image', size: 20, color: Dk.ink)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DkField(
                      controller: _text,
                      icon: null,
                      placeholder: _t('Write a reply…', 'উত্তর লিখুন…'),
                      onSubmitted: _send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _send(_text.text),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: Dk.accent, borderRadius: BorderRadius.circular(Dk.rMd)),
                      child: const Center(child: DkIcon('send', size: 19, color: Dk.accentInk)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bubble(ChatMessage m) {
    if (m.sender == ChatSender.system) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Dk.warningSoft, borderRadius: BorderRadius.circular(Dk.rMd)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DkIcon('warn', size: 15, color: Dk.warning),
              const SizedBox(width: 6),
              Flexible(child: Text(m.text, textAlign: TextAlign.center, style: dkText(12.5, weight: FontWeight.w600, color: Dk.warning))),
            ],
          ),
        ),
      );
    }
    if (m.sender == ChatSender.customer) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(color: Dk.surface, borderRadius: BorderRadius.circular(13), border: Border.all(color: Dk.line)),
          child: Text(m.text, style: dkText(13.5, height: 1.4)),
        ),
      );
    }
    final isBot = m.sender == ChatSender.bot;
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isBot)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const DkIcon('bot', size: 12, color: Dk.accentStrong),
                  const SizedBox(width: 4),
                  Text('BYTES BOT', style: dkText(10, weight: FontWeight.w800, color: Dk.accentStrong, letterSpacing: 0.4)),
                ],
              ),
            ),
          Container(
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(color: isBot ? Dk.accentTint : Dk.ink, borderRadius: BorderRadius.circular(13)),
            child: m.isImage
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DkIcon('image', size: 18, color: isBot ? Dk.accentStrong : Colors.white),
                      const SizedBox(width: 8),
                      Flexible(child: Text(m.text, style: dkText(13.5, color: isBot ? Dk.ink : Colors.white))),
                    ],
                  )
                : Text(m.text, style: dkText(13.5, height: 1.4, color: isBot ? Dk.ink : Colors.white)),
          ),
        ],
      ),
    );
  }
}
