import 'package:flutter/material.dart';

import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/tf_design_system.dart';

/// Lightweight placeholder used for QuickBytes screens that are scaffolded in
/// the navigation but built out in a later phase (Tables, Control Tower,
/// Messages, Staff, Audit). Replace each with its real implementation.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({
    required this.title,
    required this.message,
    this.titleBn,
    this.messageBn,
    this.icon = Icons.construction_outlined,
    this.showBackButton = false,
    this.showDatePill = false,
    super.key,
  });

  final String title;
  final String? titleBn;
  final String message;
  final String? messageBn;
  final IconData icon;
  final bool showBackButton;
  final bool showDatePill;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: title,
      showBackButton: showBackButton,
      showDatePill: showDatePill,
      child: Padding(
        padding: const EdgeInsets.only(top: 48),
        child: TfEmptyState(
          icon: icon,
          title: title,
          titleBn: titleBn,
          message: message,
          messageBn: messageBn,
        ),
      ),
    );
  }
}
