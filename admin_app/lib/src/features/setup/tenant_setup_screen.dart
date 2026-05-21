import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';

class TenantSetupScreen extends StatefulWidget {
  const TenantSetupScreen({required this.onProvisioned, super.key});

  final VoidCallback onProvisioned;

  @override
  State<TenantSetupScreen> createState() => _TenantSetupScreenState();
}

class _TenantSetupScreenState extends State<TenantSetupScreen> {
  final _restaurantCtrl = TextEditingController();
  final _tableCountCtrl = TextEditingController(text: '10');
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _restaurantCtrl.addListener(() => setState(() {}));
    _tableCountCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _restaurantCtrl.dispose();
    _tableCountCtrl.dispose();
    super.dispose();
  }

  int? get _tableCount {
    final parsed = int.tryParse(_tableCountCtrl.text.trim());
    if (parsed == null || parsed < 1 || parsed > 200) return null;
    return parsed;
  }

  bool get _canContinue =>
      _restaurantCtrl.text.trim().isNotEmpty && _tableCount != null && !_busy;

  Future<void> _submit() async {
    if (!_canContinue) return;
    setState(() => _busy = true);
    try {
      final app = AppScope.of(context);
      final name = _restaurantCtrl.text.trim();
      await app.saveLocalSetup(
        restaurantName: name,
        outletName: name,
        tableCount: _tableCount!,
      );
      if (!mounted) return;
      widget.onProvisioned();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final phone = app.verifiedPhoneDisplay;
    final email = app.accountEmail.isEmpty ? null : app.accountEmail;
    final identity = phone ?? email;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF14110E)),
          onPressed: () {},
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (identity != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFE5E0D0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          phone != null
                              ? Icons.phone_android_rounded
                              : Icons.mail_outline_rounded,
                          size: 16,
                          color: const Color(0xFF5A5450),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          identity,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF14110E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],
              const Text(
                "What's your\nrestaurant name?",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                  color: Color(0xFF14110E),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'This is what your staff and customers will see.',
                style: TextStyle(fontSize: 13.5, color: Color(0xFF5A5450)),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _restaurantCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                decoration: const InputDecoration(hintText: 'Restaurant name'),
              ),
              const SizedBox(height: 8),
              const Text(
                'You can change this in Settings.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF9A9388)),
              ),
              const SizedBox(height: 22),
              const Text(
                'How many tables are in this outlet?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF14110E),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('tenant-setup-table-count'),
                controller: _tableCountCtrl,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'Table count',
                  errorText:
                      _tableCountCtrl.text.trim().isEmpty || _tableCount != null
                      ? null
                      : 'Use a number from 1 to 200.',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Default is 10. You can edit this later in Settings.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF9A9388)),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _canContinue
                        ? PosColors.primary
                        : const Color(0xFFEFEAD8),
                    foregroundColor: _canContinue
                        ? const Color(0xFF14110E)
                        : const Color(0xFF9A9388),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _canContinue ? _submit : null,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF14110E),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Continue',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}
