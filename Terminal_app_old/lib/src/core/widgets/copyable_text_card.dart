import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'tf_design_system.dart';

class CopyableTextCard extends StatelessWidget {
  const CopyableTextCard({
    required this.label,
    required this.value,
    this.icon = Icons.link,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final canCopy = value.trim().isNotEmpty && !value.contains('Unavailable');
    return TfCard(
      padding: EdgeInsets.all(14),
      color: PosColors.surfaceTinted,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: PosColors.primarySoft,
              borderRadius: BorderRadius.circular(PosRadii.sm),
              border: Border.all(color: PosColors.line),
            ),
            child: Icon(icon, color: PosColors.primaryDark, size: 19),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TfText(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: PosColors.muted,
                    fontWeight: FontWeight.w500,
                    fontSize: 10.6,
                    letterSpacing: 0,
                  ),
                ),
                SizedBox(height: 4),
                SelectableText(
                  value,
                  maxLines: 2,
                  style: TextStyle(
                    color: PosColors.slate,
                    fontWeight: FontWeight.w500,
                    fontSize: 13.4,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: PosColors.surface,
            borderRadius: BorderRadius.circular(PosRadii.sm),
            child: InkWell(
              borderRadius: BorderRadius.circular(PosRadii.sm),
              onTap: canCopy
                  ? () async {
                      await Clipboard.setData(ClipboardData(text: value));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('$label copied')));
                    }
                  : null,
              child: Container(
                padding: EdgeInsets.all(9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(PosRadii.sm),
                  border: Border.all(color: PosColors.line),
                ),
                child: Icon(
                  Icons.copy_rounded,
                  size: 17,
                  color: canCopy ? PosColors.primaryDark : PosColors.muted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
