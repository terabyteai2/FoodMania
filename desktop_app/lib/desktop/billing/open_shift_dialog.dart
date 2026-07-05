import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/desk_theme.dart';

/// Minimal "open register" prompt: capture the opening cash float. Denomination
/// counting and shift close / Z-report arrive in Phase 5; billing only needs an
/// open shift to exist (createDesktopOrder requires it).
Future<double?> showOpenShiftDialog(BuildContext context) {
  return showDialog<double>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _OpenShiftDialog(),
  );
}

class _OpenShiftDialog extends StatefulWidget {
  const _OpenShiftDialog();

  @override
  State<_OpenShiftDialog> createState() => _OpenShiftDialogState();
}

class _OpenShiftDialogState extends State<_OpenShiftDialog> {
  final _cash = TextEditingController(text: '0');

  @override
  void dispose() {
    _cash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosRadii.xl),
      ),
      title: const Text('Open register',
          style: TextStyle(fontWeight: FontWeight.w800)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Enter the opening cash float (৳) to start the shift.',
              style: TextStyle(fontSize: 13, color: PosColors.ink2)),
          const SizedBox(height: 14),
          TextField(
            controller: _cash,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              isDense: true,
              prefixText: '৳ ',
              labelText: 'Opening cash',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(PosRadii.md),
              ),
            ),
            onSubmitted: (_) => _confirm(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: PosColors.ink2)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: PosColors.primary),
          onPressed: _confirm,
          child: const Text('Open shift',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  void _confirm() {
    final value = double.tryParse(_cash.text.trim()) ?? 0;
    Navigator.pop(context, value < 0 ? 0 : value);
  }
}
