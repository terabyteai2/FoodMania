import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tf_design_system.dart';

/// Recipient details captured by [showDeliveryDetailsSheet].
class DeliveryDetails {
  const DeliveryDetails({
    required this.name,
    required this.phone,
    required this.address,
  });

  final String name;
  final String phone;
  final String address;
}

/// Delivery details bottom sheet — opened when the user picks Delivery in the
/// order wizard (and from the review step on counter-only outlets). Returns
/// null when dismissed; Confirm is enabled only once all three fields are
/// filled (spec §4.3: delivery requires name + phone + address).
Future<DeliveryDetails?> showDeliveryDetailsSheet(
  BuildContext context, {
  String? initialName,
  String? initialPhone,
  String? initialAddress,
}) {
  return showModalBottomSheet<DeliveryDetails>(
    context: context,
    isScrollControlled: true,
    backgroundColor: PosColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(PosRadii.xl)),
    ),
    builder: (_) => _DeliveryDetailsSheet(
      initialName: initialName ?? '',
      initialPhone: initialPhone ?? '',
      initialAddress: initialAddress ?? '',
    ),
  );
}

class _DeliveryDetailsSheet extends StatefulWidget {
  const _DeliveryDetailsSheet({
    required this.initialName,
    required this.initialPhone,
    required this.initialAddress,
  });

  final String initialName;
  final String initialPhone;
  final String initialAddress;

  @override
  State<_DeliveryDetailsSheet> createState() => _DeliveryDetailsSheetState();
}

class _DeliveryDetailsSheetState extends State<_DeliveryDetailsSheet> {
  late final _nameCtrl = TextEditingController(text: widget.initialName);
  late final _phoneCtrl = TextEditingController(text: widget.initialPhone);
  late final _addrCtrl = TextEditingController(text: widget.initialAddress);

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_refresh);
    _phoneCtrl.addListener(_refresh);
    _addrCtrl.addListener(_refresh);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addrCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  bool get _valid =>
      _nameCtrl.text.trim().isNotEmpty &&
      _phoneCtrl.text.trim().isNotEmpty &&
      _addrCtrl.text.trim().isNotEmpty;

  void _confirm() {
    if (!_valid) return;
    Navigator.pop(
      context,
      DeliveryDetails(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        address: _addrCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            PosSpacing.sp4,
            PosSpacing.sp4,
            PosSpacing.sp4,
            PosSpacing.sp4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TfText(
                text.isBn ? 'ডেলিভারির তথ্য' : 'Delivery details',
                style: TfTextStyles.sectionHeader.copyWith(
                  color: PosColors.text,
                ),
              ),
              const SizedBox(height: PosSpacing.sp4),
              TfField(
                label: text.isBn ? 'গ্রাহকের নাম' : 'Recipient name',
                controller: _nameCtrl,
                autofocus: widget.initialName.isEmpty,
                prefix: const Icon(Icons.person_outline_rounded, size: 18),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: PosSpacing.sp3),
              TfField(
                label: text.isBn ? 'ফোন নম্বর' : 'Phone number',
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                prefix: const Icon(Icons.phone_outlined, size: 18),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: PosSpacing.sp3),
              TfField(
                label: text.isBn ? 'ঠিকানা' : 'Address',
                controller: _addrCtrl,
                maxLines: 2,
                prefix: const Icon(Icons.location_on_outlined, size: 18),
              ),
              const SizedBox(height: PosSpacing.sp4),
              TfButton(
                label: text.confirmAction,
                trailingIcon: TfNavIcon.arrow,
                size: TfButtonSize.lg,
                onPressed: _valid ? _confirm : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
