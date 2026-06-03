import 'package:flutter/material.dart';

import 'pc_theme.dart';
import 'pc_widgets.dart';

/// Desktop navigation destinations (mirrors the left rail in tf-pc-shell.jsx).
enum PcNav { counter, floor, orders, menu, stock, reports, settings }

/// A single keyboard hint shown in the footer.
class PcKey {
  const PcKey(this.k, this.l);
  final String k;
  final String l;
}

/// App-level context shared by the rail / topbar / footer chrome. Built once by
/// the desktop shell and threaded down to every screen so each screen can wrap
/// itself in [PcShell] the same way every JSX artboard wraps in `<PcShell>`.
class PcChrome {
  const PcChrome({
    required this.onNav,
    required this.outletName,
    required this.counterLabel,
    required this.online,
    required this.pendingCount,
    required this.printerLabel,
    required this.printerReady,
    required this.isBn,
    required this.onToggleLang,
    required this.shiftOpen,
    required this.shiftClock,
    required this.userInitials,
    this.lastSyncLabel,
    this.onPrinter,
    this.alertBadge = 0,
  });

  final ValueChanged<PcNav> onNav;
  final String outletName;
  final String counterLabel;
  final bool online;
  final int pendingCount;
  final String? lastSyncLabel;
  final String printerLabel;
  final bool printerReady;
  final VoidCallback? onPrinter;
  final bool isBn;
  final VoidCallback onToggleLang;
  final bool shiftOpen;
  final String? shiftClock;
  final String userInitials;
  final int alertBadge;
}

/// Full desktop frame: rail · (topbar + body + footer). Layout only — the host
/// [Scaffold] (and ScaffoldMessenger / keyboard Shortcuts) lives in the shell.
class PcShell extends StatelessWidget {
  const PcShell({
    required this.chrome,
    required this.activeNav,
    required this.title,
    required this.child,
    this.sub,
    this.topActions,
    this.footerHints,
    this.statusTools = const ['bn', 'printer', 'drawer', 'shift'],
    super.key,
  });

  final PcChrome chrome;
  final PcNav activeNav;
  final String title;
  final String? sub;
  final List<Widget>? topActions;
  final List<PcKey>? footerHints;
  final List<String> statusTools;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      PcRail(active: activeNav, chrome: chrome),
      Expanded(
        child: Column(
          children: [
            PcTopBar(
              chrome: chrome,
              title: title,
              sub: sub,
              actions: topActions,
              tools: statusTools,
            ),
            Expanded(child: child),
            PcFooter(chrome: chrome, hints: footerHints),
          ],
        ),
      ),
    ],
  );
}

class _PcBrandDot extends StatelessWidget {
  const _PcBrandDot();

  @override
  Widget build(BuildContext context) => Container(
    width: 16,
    height: 16,
    decoration: BoxDecoration(
      color: Pc.accent,
      borderRadius: BorderRadius.circular(4),
    ),
    child: const Icon(
      Icons.local_fire_department,
      size: 10.5,
      color: Pc.accentInk,
    ),
  );
}

class PcRail extends StatelessWidget {
  const PcRail({required this.active, required this.chrome, super.key});
  final PcNav active;
  final PcChrome chrome;

  static const _items = <(PcNav, String, String, String)>[
    (PcNav.counter, 'counter', 'Counter', 'F1'),
    (PcNav.floor, 'people', 'Dine-in', 'F2'),
    (PcNav.orders, 'orders', 'Orders', 'F3'),
    (PcNav.menu, 'menu', 'Menu', 'F4'),
    (PcNav.stock, 'inventory', 'Stock', 'F5'),
    (PcNav.reports, 'chart', 'Reports', 'F6'),
  ];

  @override
  Widget build(BuildContext context) => Container(
    width: Pc.railW,
    decoration: const BoxDecoration(
      color: Pc.surface,
      border: Border(right: BorderSide(color: Pc.border)),
    ),
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: _PcBrandDot(),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              children: [
                for (final item in _items)
                  _PcRailItem(
                    kind: item.$2,
                    label: item.$3,
                    sk: item.$4,
                    active: item.$1 == active,
                    onTap: () => chrome.onNav(item.$1),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            children: [
              _PcRailItem(
                kind: 'bell',
                label: 'Alerts',
                badge: chrome.alertBadge > 0 ? '${chrome.alertBadge}' : null,
                active: false,
                onTap: () {},
              ),
              _PcRailItem(
                kind: 'settings',
                label: 'Settings',
                active: active == PcNav.settings,
                onTap: () => chrome.onNav(PcNav.settings),
              ),
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                color: Pc.border,
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Pc.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  chrome.userInitials,
                  style: const TextStyle(
                    color: Pc.accentInk,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PcRailItem extends StatelessWidget {
  const _PcRailItem({
    required this.kind,
    required this.label,
    required this.active,
    required this.onTap,
    this.sk,
    this.badge,
  });
  final String kind;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final String? sk;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final color = active ? Pc.accent : Pc.textSec;
    return Tooltip(
      message: sk == null ? label : '$label  $sk',
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 52,
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            color: active ? Pc.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (active)
                Positioned(
                  left: -10,
                  top: 14,
                  bottom: 14,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: Pc.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      PcIcon(kind, size: 20, color: color),
                      if (badge != null)
                        Positioned(
                          top: -4,
                          right: -8,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 16),
                            height: 16,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: Pc.late,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Pc.surface, width: 1.5),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              badge!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PcTopBar extends StatelessWidget {
  const PcTopBar({
    required this.chrome,
    required this.title,
    this.sub,
    this.actions,
    this.tools = const ['bn', 'printer', 'drawer', 'shift'],
    super.key,
  });
  final PcChrome chrome;
  final String title;
  final String? sub;
  final List<Widget>? actions;
  final List<String> tools;

  @override
  Widget build(BuildContext context) => Container(
    height: Pc.topbar,
    padding: const EdgeInsets.symmetric(horizontal: 18),
    decoration: const BoxDecoration(
      color: Pc.surface,
      border: Border(bottom: BorderSide(color: Pc.border)),
    ),
    child: Row(
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Pc.text,
                letterSpacing: -0.3,
                height: 1,
              ),
            ),
            if (sub != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  sub!,
                  style: const TextStyle(fontSize: 11.5, color: Pc.textSec),
                ),
              ),
          ],
        ),
        const Spacer(),
        if (actions != null) ...[
          for (final action in actions!) ...[action, const SizedBox(width: 8)],
        ],
        _PcStatusPills(chrome: chrome, only: tools),
      ],
    ),
  );
}

class _PcStatusPills extends StatelessWidget {
  const _PcStatusPills({required this.chrome, required this.only});
  final PcChrome chrome;
  final List<String> only;

  @override
  Widget build(BuildContext context) {
    Widget? pill(String key) => switch (key) {
      'offline' =>
        chrome.online
            ? PcPill(
                label: chrome.lastSyncLabel ?? 'Synced',
                tone: PcTone.good,
                dot: true,
                icon: 'cloud',
              )
            : PcPill(
                label: '${chrome.pendingCount} offline',
                tone: PcTone.warn,
                dot: true,
                icon: 'cloudOff',
              ),
      'bn' => PcLangToggle(isBn: chrome.isBn, onToggle: chrome.onToggleLang),
      'printer' => MouseRegion(
        cursor: chrome.onPrinter == null
            ? MouseCursor.defer
            : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: chrome.onPrinter,
          child: PcPill(
            label: chrome.printerLabel,
            tone: chrome.printerReady ? PcTone.good : PcTone.muted,
            dot: true,
            icon: 'printer',
          ),
        ),
      ),
      'drawer' => PcPill(
        label: chrome.shiftOpen ? 'Drawer open' : 'Drawer closed',
        tone: PcTone.muted,
        dot: true,
        icon: 'drawer',
      ),
      'shift' => PcPill(
        label: chrome.shiftOpen
            ? (chrome.shiftClock ?? 'Shift open')
            : 'No shift',
        tone: chrome.shiftOpen ? PcTone.muted : PcTone.warn,
        icon: 'clock',
      ),
      _ => null,
    };
    final pills = [for (final key in only) ?pill(key)];
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: pills,
    );
  }
}

class PcLangToggle extends StatelessWidget {
  const PcLangToggle({required this.isBn, required this.onToggle, super.key});
  final bool isBn;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Pc.surfaceAlt,
          border: Border.all(color: Pc.border),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [_seg('EN', !isBn), _seg('বাংলা', isBn)],
        ),
      ),
    ),
  );

  Widget _seg(String label, bool on) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: on ? Pc.surface : Colors.transparent,
      border: Border.all(color: on ? Pc.borderStrong : Colors.transparent),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: on ? Pc.text : Pc.textSec,
      ),
    ),
  );
}

class PcFooter extends StatelessWidget {
  const PcFooter({required this.chrome, this.hints, super.key});
  final PcChrome chrome;
  final List<PcKey>? hints;

  static const _default = [
    PcKey('F1', 'Counter'),
    PcKey('F2', 'Tables'),
    PcKey('F8', 'Search'),
    PcKey('Ctrl+P', 'Print'),
    PcKey('Ctrl+S', 'Sync'),
    PcKey('Esc', 'Cancel'),
  ];

  @override
  Widget build(BuildContext context) => Container(
    height: Pc.footer,
    padding: const EdgeInsets.symmetric(horizontal: 18),
    decoration: const BoxDecoration(
      color: Pc.surface,
      border: Border(top: BorderSide(color: Pc.border)),
    ),
    child: Row(
      children: [
        for (final h in (hints ?? _default)) ...[
          _chip(h.k),
          const SizedBox(width: 5),
          Text(
            h.l,
            style: Pc.mono(11, weight: FontWeight.w600, color: Pc.textSec),
          ),
          const SizedBox(width: 18),
        ],
        const Spacer(),
        Text(
          '${chrome.outletName} · ${chrome.counterLabel}',
          style: Pc.mono(11, weight: FontWeight.w600, color: Pc.textSec),
        ),
      ],
    ),
  );

  Widget _chip(String k) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: Pc.surfaceAlt,
      border: Border.all(color: Pc.border),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(k, style: Pc.mono(10, color: Pc.text)),
  );
}
