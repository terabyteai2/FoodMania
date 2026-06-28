import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/enums/business_tier.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tf_design_system.dart';

class TenantSetupScreen extends StatefulWidget {
  const TenantSetupScreen({required this.onProvisioned, super.key});

  final VoidCallback onProvisioned;

  @override
  State<TenantSetupScreen> createState() => _TenantSetupScreenState();
}

class _TenantSetupScreenState extends State<TenantSetupScreen> {
  static const int _totalSteps = 3;
  static const int _defaultTableCount = 10;

  final _managerCtrl = TextEditingController();
  final _restaurantCtrl = TextEditingController();
  final _pageController = PageController();

  int _step = 0;
  bool _busy = false;
  BusinessTier? _selectedTier;

  @override
  void initState() {
    super.initState();
    _managerCtrl.addListener(_refresh);
    _restaurantCtrl.addListener(_refresh);
  }

  @override
  void dispose() {
    _managerCtrl
      ..removeListener(_refresh)
      ..dispose();
    _restaurantCtrl
      ..removeListener(_refresh)
      ..dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  bool get _managerReady => _managerCtrl.text.trim().isNotEmpty;
  bool get _restaurantReady => _restaurantCtrl.text.trim().isNotEmpty;

  void _goTo(int step) {
    if (_busy || step < 0 || step >= _totalSteps) return;
    setState(() => _step = step);
    _pageController.jumpToPage(step);
  }

  Future<void> _finish(BusinessTier tier) async {
    if (_busy || !_restaurantReady || !_managerReady) return;
    setState(() {
      _busy = true;
      _selectedTier = tier;
    });
    final app = AppScope.of(context);
    try {
      await app.setBusinessTier(tier);
      await app.saveLocalSetup(
        restaurantName: _restaurantCtrl.text.trim(),
        managerName: _managerCtrl.text.trim(),
        tableCount: _defaultTableCount,
      );
      if (!mounted) return;
      widget.onProvisioned();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBn = tfIsBn(context);
    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 38,
                    height: 38,
                    child: _step > 0
                        ? TfIconButton(
                            icon: TfNavIcon.back,
                            tooltip: isBn ? 'পেছনে' : 'Back',
                            onPressed: () => _goTo(_step - 1),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TfText(
                      isBn
                          ? 'ধাপ ${tfToBnNumbers('${_step + 1}')} এর ${tfToBnNumbers('$_totalSteps')}'
                          : 'STEP ${_step + 1} OF $_totalSteps',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: PosColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 5,
                  value: (_step + 1) / _totalSteps,
                  backgroundColor: PosColors.line,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    PosColors.primary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _SetupStep(
                    title: isBn ? 'আপনার নাম কী?' : 'What is your name?',
                    subtitle: isBn
                        ? 'এই নামটি ম্যানেজার অ্যাকাউন্টে দেখানো হবে।'
                        : 'This will appear on the manager account.',
                    field: TfField(
                      label: 'Manager name',
                      labelBn: 'ম্যানেজারের নাম',
                      hint: 'e.g. Ahmed Rahman',
                      hintBn: 'যেমন আহমেদ রহমান',
                      controller: _managerCtrl,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) {
                        if (_managerReady) _goTo(1);
                      },
                    ),
                    cta: TfButton(
                      label: 'Continue',
                      labelBn: 'চালিয়ে যান',
                      trailingIcon: TfNavIcon.arrow,
                      onPressed: _managerReady ? () => _goTo(1) : null,
                    ),
                  ),
                  _SetupStep(
                    title: isBn
                        ? 'রেস্টুরেন্টের নাম দিন'
                        : 'Name your restaurant',
                    subtitle: isBn
                        ? 'এই নামটি POS, রসিদ এবং কাস্টমার মেনুতে ব্যবহৃত হবে।'
                        : 'This name appears in POS, receipts, and the customer menu.',
                    field: TfField(
                      label: 'Restaurant name',
                      labelBn: 'রেস্টুরেন্টের নাম',
                      hint: 'e.g. Terafoods Cafe',
                      hintBn: 'যেমন টেরাফুডস ক্যাফে',
                      controller: _restaurantCtrl,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) {
                        if (_restaurantReady) _goTo(2);
                      },
                    ),
                    cta: TfButton(
                      label: 'Continue',
                      labelBn: 'চালিয়ে যান',
                      trailingIcon: TfNavIcon.arrow,
                      onPressed: _restaurantReady ? () => _goTo(2) : null,
                    ),
                  ),
                  _RestaurantTypeStep(
                    busy: _busy,
                    selectedTier: _selectedTier,
                    onSelected: _finish,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestaurantTypeStep extends StatelessWidget {
  const _RestaurantTypeStep({
    required this.busy,
    required this.selectedTier,
    required this.onSelected,
  });

  final bool busy;
  final BusinessTier? selectedTier;
  final ValueChanged<BusinessTier> onSelected;

  @override
  Widget build(BuildContext context) {
    final isBn = tfIsBn(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 54, 20, 24),
      children: [
        TfText(
          isBn ? 'কী ধরনের রেস্টুরেন্ট?' : 'What type of restaurant?',
          style: TextStyle(
            fontFamily: tfFontFamily(context),
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: PosColors.slate,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 10),
        TfText(
          isBn
              ? 'আপনার POS সাজাতে একটি অপশন বেছে নিন।'
              : 'Choose one option to tailor your POS.',
          style: const TextStyle(
            fontSize: 15,
            color: PosColors.muted,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        for (final option in _restaurantTypeOptions) ...[
          _RestaurantTypeCard(
            option: option,
            selected: selectedTier == option.tier,
            busy: busy,
            onTap: () => onSelected(option.tier),
          ),
          if (option != _restaurantTypeOptions.last)
            const SizedBox(height: PosSpacing.sp3),
        ],
      ],
    );
  }
}

class _RestaurantTypeCard extends StatelessWidget {
  const _RestaurantTypeCard({
    required this.option,
    required this.selected,
    required this.busy,
    required this.onTap,
  });

  final _RestaurantTypeOption option;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isBn = tfIsBn(context);
    final foreground = selected ? PosColors.primaryDark : PosColors.inkSoft;
    return Material(
      key: ValueKey('restaurant-type-${option.tier.key}'),
      color: selected ? PosColors.primarySoft : PosColors.surface,
      borderRadius: BorderRadius.circular(PosRadii.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(PosSpacing.sp4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosRadii.md),
            border: Border.all(
              color: selected ? PosColors.lineStrong : PosColors.line,
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TfText(
                      isBn ? option.labelBn : option.label,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: PosSpacing.sp1),
                    TfText(
                      isBn ? option.subtitleBn : option.subtitle,
                      style: TextStyle(
                        color: selected ? PosColors.inkSoft : PosColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: PosSpacing.sp3),
              if (selected && busy)
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    color: PosColors.inkSoft,
                    strokeWidth: 2,
                  ),
                )
              else
                Icon(TfNavIcon.arrow, color: foreground, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestaurantTypeOption {
  const _RestaurantTypeOption({
    required this.tier,
    required this.label,
    required this.labelBn,
    required this.subtitle,
    required this.subtitleBn,
  });

  final BusinessTier tier;
  final String label;
  final String labelBn;
  final String subtitle;
  final String subtitleBn;
}

const _restaurantTypeOptions = [
  _RestaurantTypeOption(
    tier: BusinessTier.simple,
    label: 'Food Cart',
    labelBn: 'ফুড কার্ট',
    subtitle: 'Counter service',
    subtitleBn: 'কাউন্টার সার্ভিস',
  ),
  _RestaurantTypeOption(
    tier: BusinessTier.standard,
    label: 'Cafe',
    labelBn: 'ক্যাফে',
    subtitle: '1-10 tables',
    subtitleBn: '১-১০টি টেবিল',
  ),
  _RestaurantTypeOption(
    tier: BusinessTier.advanced,
    label: 'Restaurant',
    labelBn: 'রেস্টুরেন্ট',
    subtitle: '11-20 tables',
    subtitleBn: '১১-২০টি টেবিল',
  ),
  _RestaurantTypeOption(
    tier: BusinessTier.enterprise,
    label: 'Enterprise',
    labelBn: 'এন্টারপ্রাইজ',
    subtitle: '20+ tables',
    subtitleBn: '২০টির বেশি টেবিল',
  ),
];

class _SetupStep extends StatelessWidget {
  const _SetupStep({
    required this.title,
    required this.subtitle,
    required this.field,
    required this.cta,
  });

  final String title;
  final String subtitle;
  final Widget field;
  final Widget cta;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 54, 20, 24),
      children: [
        TfText(
          title,
          style: TextStyle(
            fontFamily: tfFontFamily(context),
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: PosColors.slate,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 10),
        TfText(
          subtitle,
          style: const TextStyle(
            fontSize: 15,
            color: PosColors.muted,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 30),
        field,
        const SizedBox(height: 14),
        cta,
      ],
    );
  }
}
