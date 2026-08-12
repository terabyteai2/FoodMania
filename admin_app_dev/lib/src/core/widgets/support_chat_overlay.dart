import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../localization/app_strings.dart';
import '../theme/app_theme.dart';
import 'guided_tour.dart';
import 'notification_center.dart';
import 'tf_design_system.dart';

/// Help-desk chat between this outlet (client) and the platform
/// (server / LLM helper) — all UI and chat state live in this file.
///
/// Transport: the existing per-outlet WebSocket (`/ws/{outlet_id}`) carries
/// `support_msg` events in both directions; REST (`/admin/support-chat`)
/// provides history and a send fallback when the socket is down.
///
/// Server messages may carry:
///  - `actions: [{label, target}]` — tappable deeplink buttons that jump
///    straight to a page/modal (targets: `tab:<name>`, `screen:<name>`,
///    `modal:<name>`, `highlight:<spot>`).
///  - `steps: [{title, body, target?, spot?}]` — guide cards; steps with a
///    known [TourSpot] name launch the spotlight overlay over the real UI.
///    A step's `target` deeplink auto-navigates the app (tab switch, pushed
///    screen, modal) before its spotlight shows — the assistant maneuvers the
///    user through the app. Starting a guide closes the chat first, and a
///    live guide message auto-starts while the chat is open.

class SupportChatAction {
  const SupportChatAction({required this.label, required this.target});

  final String label;
  final String target;

  factory SupportChatAction.fromJson(Map<String, Object?> json) {
    return SupportChatAction(
      label: json['label']?.toString() ?? 'Open',
      target: json['target']?.toString() ?? '',
    );
  }
}

class SupportChatStep {
  const SupportChatStep({
    required this.title,
    required this.body,
    this.spot,
    this.target,
    this.shape,
  });

  final String title;
  final String body;

  /// Optional [TourSpot] name for a spotlight overlay ("Show me" affordance).
  final String? spot;

  /// Optional deeplink target auto-executed before the step is shown, so the
  /// app navigates itself (e.g. `tab:stock`, `screen:staff`,
  /// `modal:menu_discounts`).
  final String? target;

  /// Optional spotlight cutout shape: `circle` for round targets (FABs),
  /// `roundedRect` (default) for buttons/cards. Mirrors the vocabulary
  /// metadata the assistant reads via get_guide_deeplinks.
  final String? shape;

  factory SupportChatStep.fromJson(Map<String, Object?> json) {
    final spot = json['spot']?.toString().trim();
    final target = json['target']?.toString().trim();
    final shape = json['shape']?.toString().trim();
    return SupportChatStep(
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      spot: (spot == null || spot.isEmpty) ? null : spot,
      target: (target == null || target.isEmpty) ? null : target,
      shape: (shape == 'circle' || shape == 'roundedRect') ? shape : null,
    );
  }
}

class SupportChatMessage {
  const SupportChatMessage({
    required this.id,
    required this.role,
    this.senderName,
    required this.text,
    this.actions = const [],
    this.steps = const [],
    this.createdAt,
  });

  final String id;

  /// 'client' (this outlet) or 'server' (platform/LLM helper).
  final String role;
  final String? senderName;
  final String text;
  final List<SupportChatAction> actions;
  final List<SupportChatStep> steps;
  final DateTime? createdAt;

  bool get mine => role == 'client';

  factory SupportChatMessage.fromJson(Map<String, Object?> json) {
    final rawActions = json['actions'];
    final rawSteps = json['steps'];
    final rawCreatedAt = json['createdAt']?.toString();
    return SupportChatMessage(
      id: json['id']?.toString() ?? '',
      role: json['role']?.toString() ?? 'client',
      senderName: json['senderName']?.toString(),
      text: json['text']?.toString() ?? '',
      actions: rawActions is List
          ? rawActions
                .whereType<Map>()
                .map(
                  (e) => SupportChatAction.fromJson(
                    Map<String, Object?>.from(e),
                  ),
                )
                .toList(growable: false)
          : const [],
      steps: rawSteps is List
          ? rawSteps
                .whereType<Map>()
                .map(
                  (e) => SupportChatStep.fromJson(
                    Map<String, Object?>.from(e),
                  ),
                )
                .toList(growable: false)
          : const [],
      createdAt: DateTime.tryParse(rawCreatedAt ?? '')?.toLocal(),
    );
  }
}

/// Executes a deeplink target at the shell level (tab switches, pushes, modals).
typedef SupportChatNavigator = void Function(String target);

class SupportChatController extends ChangeNotifier {
  SupportChatController._();

  static final SupportChatController instance = SupportChatController._();

  final List<SupportChatMessage> _messages = <SupportChatMessage>[];
  final Set<String> _knownIds = <String>{};
  int _unread = 0;
  bool _open = false;
  bool _loading = false;
  bool _sending = false;
  bool _connected = false;
  bool _disposed = false;
  String? _lastError;
  String? _lastToastMessageId;

  BuildContext? _hostContext;
  SupportChatNavigator? _navigator;
  OverlayEntry? _entry;
  OverlayEntry? _guideEntry;
  Timer? _connectionTimer;

  List<SupportChatMessage> get messages =>
      List<SupportChatMessage>.unmodifiable(_messages);
  int get unread => _unread;
  bool get isOpen => _open;
  bool get loading => _loading;
  bool get sending => _sending;
  bool get connected => _connected;
  String? get lastError => _lastError;

  /// Wires shell-level navigation (MainShell initState). Deeplink targets are
  /// executed here.
  void attachNavigator(SupportChatNavigator navigator) {
    _navigator = navigator;
  }

  /// Wires a long-lived host context (the shell) used for toast + overlay
  /// insertion. Guarded by `mounted` at use sites.
  void attachHost(BuildContext context) {
    _hostContext = context;
  }

  void _refreshConnection() {
    final host = _hostContext;
    if (host == null || !host.mounted) return;
    if (host.getInheritedWidgetOfExactType<AppScope>() == null) return;
    final app = AppScope.read(host);
    final next = app.cloudRealtimeService.isSubscribed;
    if (next != _connected) {
      _connected = next;
      notifyListeners();
    }
  }

  void _startConnectionTimer() {
    _connectionTimer?.cancel();
    _connectionTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_disposed || !_open) {
        _connectionTimer?.cancel();
        return;
      }
      _refreshConnection();
    });
  }

  void open() {
    final host = _hostContext;
    if (host == null || _open) return;
    _open = true;
    _unread = 0;
    _refreshConnection();
    _startConnectionTimer();
    unawaited(loadHistory());
    _entry = OverlayEntry(
      builder: (_) => SupportChatOverlay(controller: this),
    );
    Overlay.of(host, rootOverlay: true).insert(_entry!);
    notifyListeners();
  }

  void close() {
    if (!_open) return;
    _open = false;
    _connectionTimer?.cancel();
    _connectionTimer = null;
    _entry?.remove();
    _entry = null;
    notifyListeners();
  }

  void toggle() => _open ? close() : open();

  Future<void> loadHistory() async {
    final host = _hostContext;
    if (host == null) return;
    final app = AppScope.read(host);
    _loading = true;
    _lastError = null;
    notifyListeners();
    try {
      final raw = await app.cloudApiService.fetchSupportChatHistory();
      final incoming = raw
          .map(SupportChatMessage.fromJson)
          .where((m) => _knownIds.add(m.id))
          .toList(growable: false);
      _messages.addAll(incoming);
      if (_messages.length > 400) {
        final overflow = _messages.length - 400;
        for (var i = 0; i < overflow; i++) {
          _knownIds.remove(_messages.first.id);
          _messages.removeAt(0);
        }
      }
    } catch (error) {
      _lastError = error.toString();
    } finally {
      _loading = false;
      _refreshConnection();
      notifyListeners();
    }
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sending) return;
    final host = _hostContext;
    if (host == null) return;
    final app = AppScope.read(host);
    _sending = true;
    _lastError = null;
    notifyListeners();
    try {
      // Prefer the live socket; fall back to REST persistence when offline.
      final sentOverWs = await app.cloudRealtimeService.sendMessage(<String, Object?>{
        'type': 'support_msg',
        'data': <String, Object?>{
          'text': trimmed,
          'senderName': app.accountDisplayName,
        },
      });
      if (!sentOverWs) {
        await app.cloudApiService.sendSupportChatMessage(trimmed);
      }
      _refreshConnection();
      unawaited(loadHistory());
    } catch (error) {
      _lastError = error.toString();
      notifyListeners();
    } finally {
      _sending = false;
    }
  }

  /// Routes an incoming `support_msg` WS event (called from
  /// [PosAppController._handleRemoteSyncEvent]).
  Future<void> handleRemoteEvent(Map<String, Object?> event) async {
    final data = event['data'];
    if (data is! Map) return;
    final message = SupportChatMessage.fromJson(Map<String, Object?>.from(data));
    if (!_knownIds.add(message.id)) return;
    _messages.add(message);
    if (_messages.length > 400) {
      final overflow = _messages.length - 400;
      for (var i = 0; i < overflow; i++) {
        _knownIds.remove(_messages.first.id);
        _messages.removeAt(0);
      }
    }
    _refreshConnection();
    if (!_open && !message.mine && message.id != _lastToastMessageId) {
      _lastToastMessageId = message.id;
      _unread++;
      _showIncomingToast(message);
    }
    notifyListeners();
    // Assistant sent a guide while the chat is open: close the chat and run
    // the walkthrough over the real UI. History replay never auto-starts.
    if (!message.mine && message.steps.isNotEmpty && _open) {
      close();
      startGuide(message.steps);
    }
  }

  void _showIncomingToast(SupportChatMessage message) {
    final host = _hostContext;
    if (host == null || !host.mounted) return;
    showTopNotificationToast(
      host,
      title: AppStrings.of(AppScope.read(host).language).supportChatNewMessage,
      body: message.text,
      duration: const Duration(seconds: 6),
      onOpen: () {
        _lastToastMessageId = null;
        open();
      },
    );
  }

  /// Executes a message action. `highlight:<spot>` opens a spotlight overlay;
  /// everything else delegates to the shell navigator.
  void runAction(SupportChatAction action) {
    final target = action.target;
    if (target.startsWith('highlight:')) {
      final spot = target.substring('highlight:'.length).trim();
      if (spot.isNotEmpty) {
        showGuide(
          SupportChatStep(
            title: action.label,
            body: '',
            spot: spot,
          ),
        );
      }
      return;
    }
    if (_navigator != null) _navigator!(target);
  }

  /// Launches a single-step spotlight over the real UI (reuses the guided-tour
  /// overlay; unknown spots skip silently). The chat closes first so the tour
  /// is the only thing on screen.
  void showGuide(SupportChatStep step) {
    close();
    _showTour([_tourStepFor(step)]);
  }

  /// Launches a full Skip walkthrough for a multi-step guide. Each step
  /// auto-navigates via its `target` deeplink before its spotlight shows.
  /// The chat closes first.
  void startGuide(List<SupportChatStep> steps) {
    if (steps.isEmpty) return;
    close();
    _showTour([for (final step in steps) _tourStepFor(step)]);
  }

  /// Wraps a chat step as a [TourStep]. When the target element is not visible
  /// yet, the guided-tour overlay runs [TourStep.onEnter] — the step's
  /// deeplink — and waits for the spot to mount, so the assistant maneuvers
  /// the user through the app (switch tab / push screen / open modal) before
  /// the spotlight appears.
  TourStep _tourStepFor(SupportChatStep step) {
    final target = step.target?.trim() ?? '';
    final navigator = _navigator;
    return TourStep.spot(
      spot: step.spot ?? '',
      title: step.title,
      body: step.body,
      shape: step.shape == 'circle'
          ? TourSpotlightShape.circle
          : TourSpotlightShape.roundedRect,
      onEnter: (target.isNotEmpty && navigator != null)
          ? () => navigator(target)
          : null,
    );
  }

  void _showTour(List<TourStep> steps) {
    final host = _hostContext;
    if (host == null || _guideEntry != null) return;
    _guideEntry = OverlayEntry(
      builder: (_) => GuidedTourOverlay(
        steps: steps,
        onFinished: () {
          _guideEntry?.remove();
          _guideEntry = null;
        },
      ),
    );
    Overlay.of(host, rootOverlay: true).insert(_guideEntry!);
  }

  @override
  void dispose() {
    _disposed = true;
    _connectionTimer?.cancel();
    _entry?.remove();
    _guideEntry?.remove();
    _hostContext = null;
    super.dispose();
  }
}

/// Centered help-desk chat card. Scrim tap dismisses; the card holds the
/// conversation (bubbles + action buttons + guide cards) and the input row.
class SupportChatOverlay extends StatefulWidget {
  const SupportChatOverlay({required this.controller, super.key});

  final SupportChatController controller;

  @override
  State<SupportChatOverlay> createState() => _SupportChatOverlayState();
}

class _SupportChatOverlayState extends State<SupportChatOverlay> {
  final TextEditingController _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _input.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  void _submit() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    unawaited(widget.controller.send(text));
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final strings = AppStrings.of(AppScope.read(context).language);
    final media = MediaQuery.of(context);
    final cardWidth = (media.size.width - 32).clamp(0.0, 420.0);
    final cardHeight = (media.size.height - 96).clamp(240.0, 560.0);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: controller.close,
            child: ColoredBox(color: PosColors.tourScrim),
          ),
        ),
        Center(
          child: SafeArea(
            child: SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: Material(
                color: PosColors.surface,
                borderRadius: BorderRadius.circular(PosRadii.xl),
                elevation: 0,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _Header(controller: controller, strings: strings),
                    const Divider(height: 1, color: PosColors.line),
                    if (controller.lastError != null)
                      _ErrorBanner(message: controller.lastError!),
                    Expanded(
                      child: controller.messages.isEmpty && controller.loading
                          ? const Center(
                              child: SizedBox.square(
                                dimension: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: PosColors.primary,
                                ),
                              ),
                            )
                          : controller.messages.isEmpty
                          ? _EmptyState(strings: strings)
                          : ListView.builder(
                              reverse: true,
                              padding: const EdgeInsets.all(PosSpacing.sp3),
                              itemCount: controller.messages.length,
                              itemBuilder: (context, index) {
                                final message =
                                    controller.messages[controller.messages.length - 1 - index];
                                return _MessageBubble(message: message);
                              },
                            ),
                    ),
                    if (!controller.connected)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          PosSpacing.sp3,
                          0,
                          PosSpacing.sp3,
                          PosSpacing.sp2,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.cloud_off_rounded,
                              size: 14,
                              color: PosColors.muted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: TfText(
                                strings.supportChatOfflineHint,
                                style: TfTextStyles.label.copyWith(
                                  color: PosColors.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    _InputRow(
                      controller: _input,
                      strings: strings,
                      sending: controller.sending,
                      onSend: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.strings});

  final SupportChatController controller;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PosSpacing.sp4,
        PosSpacing.sp2,
        PosSpacing.sp2,
        PosSpacing.sp2,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              TfText(strings.supportChatTitle, style: TfTextStyles.appBarTitle),
              const SizedBox(width: PosSpacing.sp2),
              _ConnectionDot(connected: controller.connected),
            ],
          ),
          TfIconButton(
            icon: Icons.close_rounded,
            tooltip: strings.supportChatTitle,
            bare: true,
            onPressed: controller.close,
          ),
        ],
      ),
    );
  }
}

class _ConnectionDot extends StatelessWidget {
  const _ConnectionDot({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final color = connected ? PosColors.success : PosColors.muted;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: PosColors.dangerSoft,
      padding: const EdgeInsets.symmetric(
        horizontal: PosSpacing.sp3,
        vertical: PosSpacing.sp2,
      ),
      child: TfText(
        message,
        style: TfTextStyles.label.copyWith(color: PosColors.danger),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PosSpacing.sp4),
        child: TfText(
          strings.supportChatEmpty,
          textAlign: TextAlign.center,
          style: TfTextStyles.body.copyWith(color: PosColors.ink2),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final SupportChatMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    final alignment = mine ? Alignment.centerRight : Alignment.centerLeft;

    return Padding(
      padding: const EdgeInsets.only(bottom: PosSpacing.sp3),
      child: Align(
        alignment: alignment,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!mine && message.senderName?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(
                    left: PosSpacing.sp1,
                    bottom: 2,
                  ),
                  child: TfText(
                    message.senderName!,
                    style: TfTextStyles.label.copyWith(color: PosColors.muted),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: PosSpacing.sp3,
                  vertical: PosSpacing.sp2,
                ),
                decoration: BoxDecoration(
                  color: mine ? PosColors.primary : PosColors.surface,
                  borderRadius: BorderRadius.circular(PosRadii.md),
                  border: mine
                      ? null
                      : Border.all(color: PosColors.line, width: 1),
                  boxShadow: PosShadows.soft,
                ),
                child: TfText(
                  message.text,
                  style: mine
                      ? TfTextStyles.body.copyWith(color: PosColors.accentInk)
                      : TfTextStyles.body.copyWith(color: PosColors.text),
                ),
              ),
              if (message.createdAt != null)
                Padding(
                  padding: const EdgeInsets.only(
                    top: 2,
                    left: PosSpacing.sp1,
                  ),
                  child: TfText(
                    _formatTime(message.createdAt!),
                    style: TfTextStyles.label.copyWith(color: PosColors.muted),
                  ),
                ),
              if (message.actions.isNotEmpty) ..._buildActions(context),
              if (message.steps.isNotEmpty) ..._buildSteps(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    return [
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final action in message.actions)
            TfButton(
              label: action.label,
              variant: TfButtonVariant.accent,
              size: TfButtonSize.sm,
              fullWidth: false,
              onPressed: () => SupportChatController.instance.runAction(action),
            ),
        ],
      ),
    ];
  }

  List<Widget> _buildSteps(BuildContext context) {
    final strings = AppStrings.of(AppScope.read(context).language);
    return [
      if (message.steps.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: PosSpacing.sp2),
          child: TfButton(
            label: strings.supportChatStartGuide,
            variant: TfButtonVariant.accent,
            size: TfButtonSize.sm,
            fullWidth: false,
            onPressed: () =>
                SupportChatController.instance.startGuide(message.steps),
          ),
        ),
      for (var i = 0; i < message.steps.length; i++)
        Padding(
          padding: const EdgeInsets.only(top: PosSpacing.sp2),
          child: _GuideStepCard(
            index: i + 1,
            step: message.steps[i],
            showMeLabel: strings.supportChatShowMe,
            openLabel: strings.supportChatOpen,
          ),
        ),
    ];
  }

  String _formatTime(DateTime time) {
    final h = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$h:$minute $period';
  }
}

class _GuideStepCard extends StatelessWidget {
  const _GuideStepCard({
    required this.index,
    required this.step,
    required this.showMeLabel,
    required this.openLabel,
  });

  final int index;
  final SupportChatStep step;
  final String showMeLabel;
  final String openLabel;

  @override
  Widget build(BuildContext context) {
    final hasSpot = step.spot?.isNotEmpty == true;
    final hasTarget = step.target?.isNotEmpty == true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PosSpacing.sp3),
      decoration: BoxDecoration(
        color: PosColors.surfaceSunk,
        borderRadius: BorderRadius.circular(PosRadii.card),
        border: Border.all(color: PosColors.neutralWash, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: PosColors.primary,
                  shape: BoxShape.circle,
                ),
                child: TfText(
                  '$index',
                  style: TfTextStyles.label.copyWith(color: PosColors.accentInk),
                ),
              ),
              const SizedBox(width: PosSpacing.sp2),
              Expanded(
                child: TfText(
                  step.title,
                  style: TfTextStyles.rowTitle.copyWith(color: PosColors.text),
                ),
              ),
            ],
          ),
          if (step.body.isNotEmpty) ...[
            const SizedBox(height: PosSpacing.sp1),
            Padding(
              padding: const EdgeInsets.only(left: PosSpacing.sp8),
              child: TfText(
                step.body,
                style: TfTextStyles.body.copyWith(color: PosColors.ink2),
              ),
            ),
          ],
          if (hasSpot || hasTarget) ...[
            const SizedBox(height: PosSpacing.sp2),
            Padding(
              padding: const EdgeInsets.only(left: PosSpacing.sp8),
              child: TfButton(
                label: hasSpot ? showMeLabel : openLabel,
                variant: TfButtonVariant.accent,
                size: TfButtonSize.sm,
                fullWidth: false,
                onPressed: () =>
                    SupportChatController.instance.showGuide(step),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.controller,
    required this.strings,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final AppStrings strings;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PosSpacing.sp3),
      decoration: BoxDecoration(
        color: PosColors.surface,
        border: const Border(top: BorderSide(color: PosColors.line, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: TfTextStyles.body.copyWith(color: PosColors.text),
              decoration: InputDecoration(
                hintText: strings.supportChatInputHint,
                hintStyle: TfTextStyles.body.copyWith(color: PosColors.muted),
                filled: true,
                fillColor: PosColors.surfaceSunk,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: PosSpacing.sp3,
                  vertical: PosSpacing.sp2,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PosRadii.md),
                  borderSide: const BorderSide(color: PosColors.neutralWash),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PosRadii.md),
                  borderSide: const BorderSide(color: PosColors.neutralWash),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PosRadii.md),
                  borderSide: const BorderSide(
                    color: PosColors.primary,
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: PosSpacing.sp2),
          SizedBox(
            width: 44,
            height: 44,
            child: Material(
              color: sending ? PosColors.line : PosColors.primary,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: sending ? null : onSend,
                child: sending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: PosColors.accentInk,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        size: 20,
                        color: PosColors.accentInk,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Top-bar chat button with unread badge (TfGlobalTopBar trailing cluster).
class HeaderSupportChatButton extends StatelessWidget {
  const HeaderSupportChatButton({this.color, super.key});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SupportChatController.instance,
      builder: (context, _) {
        final controller = SupportChatController.instance;
        return TfBarButton(
          icon: TfSourceIconName.support,
          tooltip: AppStrings.of(AppScope.read(context).language).supportChatTooltip,
          badge: controller.unread,
          bare: true,
          iconColor: color,
          onPressed: () {
            controller.attachHost(context);
            controller.toggle();
          },
        );
      },
    );
  }
}
