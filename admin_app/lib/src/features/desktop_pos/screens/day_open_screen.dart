import 'package:flutter/material.dart';

import '../widgets/pc_denomination.dart';
import '../widgets/pc_shell.dart';
import '../widgets/pc_theme.dart';
import '../widgets/pc_widgets.dart';

/// 4 · Open day — count the opening cash float before the register can sell.
/// Gates the POS when no shift is open. Reuses `openDesktopShift`.
class DayOpenScreen extends StatefulWidget {
  const DayOpenScreen({
    required this.chrome,
    required this.onStart,
    this.expectedFloat,
    super.key,
  });

  final PcChrome chrome;
  final double? expectedFloat;
  final Future<void> Function(double total, Map<String, int> denominations)
  onStart;

  @override
  State<DayOpenScreen> createState() => _DayOpenScreenState();
}

class _DayOpenScreenState extends State<DayOpenScreen> {
  double _total = 0;
  Map<String, int> _denoms = const {};
  bool _busy = false;

  String tr(String en, String bn) => widget.chrome.isBn ? bn : en;

  @override
  Widget build(BuildContext context) {
    final expected = widget.expectedFloat;
    final variance = expected == null ? null : _total - expected;
    return PcShell(
      chrome: widget.chrome,
      activeNav: PcNav.counter,
      statusTools: const ['bn', 'printer'],
      title: tr('Open day · register', 'দিন শুরু · রেজিস্টার'),
      sub: tr(
        'Count the opening cash to start the shift',
        'শিফট শুরু করতে শুরুর ক্যাশ গণনা করুন',
      ),
      footerHints: const [
        PcKey('Enter', 'Confirm'),
        PcKey('Tab', 'Next'),
        PcKey('Esc', 'Cancel'),
      ],
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: PcCard(
                    pad: 22,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PcEyebrow(
                          tr(
                            'Step 1 · count opening cash',
                            'ধাপ ১ · শুরুর ক্যাশ গণনা',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tr(
                            'How much is in the drawer right now?',
                            'এখন ড্রয়ারে কত আছে?',
                          ),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr(
                            'Count notes & coins by denomination — this is the float for today’s variance check.',
                            'ডিনোমিনেশন অনুযায়ী নোট ও কয়েন গণনা করুন।',
                          ),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Pc.textSec,
                          ),
                        ),
                        const SizedBox(height: 20),
                        PcDenominationGrid(
                          isBn: widget.chrome.isBn,
                          onChanged: (total, denoms) => setState(() {
                            _total = total;
                            _denoms = denoms;
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                SizedBox(
                  width: 360,
                  child: Column(
                    children: [
                      PcCard(
                        pad: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PcEyebrow(
                              tr('Counted opening cash', 'গণনাকৃত শুরুর ক্যাশ'),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              pcMoney(_total),
                              style: Pc.num(44, letterSpacing: -1.2),
                            ),
                            const SizedBox(height: 18),
                            _summaryRow(
                              tr('Expected float', 'প্রত্যাশিত ফ্লোট'),
                              expected == null ? '—' : pcMoney(expected),
                            ),
                            if (variance != null)
                              _summaryRow(
                                tr('Variance', 'পার্থক্য'),
                                pcMoney(variance),
                                color: variance == 0
                                    ? Pc.textSec
                                    : (variance > 0 ? Pc.good : Pc.late),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      PcCard(
                        pad: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PcEyebrow(tr('Printer', 'প্রিন্টার')),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Pc.surfaceAlt,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Row(
                                children: [
                                  const PcIcon(
                                    'printer',
                                    size: 16,
                                    color: Pc.textSec,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      widget.chrome.printerLabel,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: widget.chrome.printerReady
                                          ? Pc.good
                                          : Pc.warn,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.chrome.onPrinter != null) ...[
                              const SizedBox(height: 10),
                              PcBtn(
                                label: tr(
                                  'Configure printer',
                                  'প্রিন্টার কনফিগার',
                                ),
                                variant: PcVariant.surface,
                                size: PcSize.sm,
                                full: true,
                                onTap: widget.chrome.onPrinter,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      PcBtn(
                        label: _busy
                            ? tr('Starting…', 'শুরু হচ্ছে…')
                            : tr(
                                'Start day · open POS',
                                'দিন শুরু · POS খুলুন',
                              ),
                        variant: PcVariant.primary,
                        size: PcSize.xl,
                        icon: 'check',
                        full: true,
                        onTap: _busy ? null : _start,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? color}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, color: Pc.textSec)),
        const Spacer(),
        Text(
          value,
          style: Pc.num(12.5, weight: FontWeight.w600, color: color ?? Pc.text),
        ),
      ],
    ),
  );

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      await widget.onStart(_total, _denoms);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
