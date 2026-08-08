import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../app_scope.dart';
import '../../core/constants/payment_defaults.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/bkash_payment_session.dart';
import '../../models/payment_gateway_config.dart';

/// Runs UddoktaPay sandbox checkout (or demo dialog) and returns true when paid.
class SubscriptionCheckoutFlow {
  SubscriptionCheckoutFlow._();

  static Future<bool> run(
    BuildContext context, {
    required double amount,
    required String plan,
    String? email,
    String? fullName,
  }) async {
    if (PaymentDefaults.useDemoBkashGateway) {
      return _runDemoDialog(context, amount: amount, plan: plan);
    }
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => _UddoktaCheckoutPage(
          amount: amount,
          plan: plan,
          email: email,
          fullName: fullName,
        ),
        fullscreenDialog: true,
      ),
    );
    return completed == true;
  }

  static Future<bool> _runDemoDialog(
    BuildContext context, {
    required double amount,
    required String plan,
  }) async {
    final app = AppScope.of(context);
    final completed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const TfText('Demo payment'),
        content: TfText(
          'Sandbox bypass for $plan (৳${amount.toStringAsFixed(0)}).\n'
          'Tap Complete to continue without UddoktaPay.',
        ),
        actions: [
          TfButton(
            label: 'Cancel',
            variant: TfButtonVariant.paper,
            fullWidth: false,
            onPressed: () => Navigator.pop(context, false),
          ),
          TfButton(
            label: 'Complete',
            fullWidth: false,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (completed != true) return false;
    await app.markTemporaryBkashPaymentVerified(plan: plan, amount: amount);
    return true;
  }
}

class _UddoktaCheckoutPage extends StatefulWidget {
  const _UddoktaCheckoutPage({
    required this.amount,
    required this.plan,
    this.email,
    this.fullName,
  });

  final double amount;
  final String plan;
  final String? email;
  final String? fullName;

  @override
  State<_UddoktaCheckoutPage> createState() => _UddoktaCheckoutPageState();
}

/// Chrome mobile UA — default WebView UA is often blocked by Cloudflare (502).
const _kCheckoutUserAgent =
    'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

class _UddoktaCheckoutPageState extends State<_UddoktaCheckoutPage> {
  WebViewController? _controller;
  BkashPaymentSession? _session;
  PaymentGatewayConfig? _gatewayConfig;
  String? _returnInvoiceId;
  bool _loading = true;
  bool _completing = false;
  bool _gatewayPageError = false;
  String? _error;
  String _checkoutTitle = 'Secure payment';

  bool get _sandboxMode => _gatewayConfig?.uddoktaPaySandbox ?? false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCheckout());
  }

  Future<void> _startCheckout() async {
    final app = AppScope.of(context);
    try {
      app.cloudApiService.configure(
        cloudConfig: app.cloudConfig,
        serverConfig: app.serverConfig,
      );
      _gatewayConfig = await app.cloudApiService.fetchPaymentGatewayConfig();
      if (_gatewayConfig != null) {
        _checkoutTitle = _gatewayConfig!.uddoktaPaySandbox
            ? 'UddoktaPay · Sandbox'
            : 'Secure payment';
        final warning = _gatewayConfig!.redirectUrlWarning;
        if (warning != null && warning.isNotEmpty) {
          setState(() {
            _loading = false;
            _error = warning;
          });
          return;
        }
      }
      final session = await app.createSubscriptionCheckout(
        amount: widget.amount,
        plan: widget.plan,
        email: widget.email,
        fullName: widget.fullName,
      );
      if (!mounted) return;
      final url = session.checkoutUrl.trim();
      if (url.isEmpty) {
        setState(() {
          _loading = false;
          _error =
              'No checkout URL from server. Check UDDOKTAPAY_API_KEY and UDDOKTAPAY_BASE_URL in backend/.env';
        });
        return;
      }
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setUserAgent(_kCheckoutUserAgent);
      controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (_isSuccessUrl(request.url)) {
              unawaited(_complete());
            }
            return NavigationDecision.navigate;
          },
          onPageFinished: (pageUrl) {
            if (_isSuccessUrl(pageUrl)) {
              unawaited(_complete());
              return;
            }
            unawaited(_checkGatewayPageError(controller));
          },
          onWebResourceError: (err) {
            if (!mounted) return;
            final desc = err.description.toLowerCase();
            final isGatewayError =
                desc.contains('502') ||
                desc.contains('503') ||
                desc.contains('bad gateway');
            setState(() {
              _gatewayPageError = isGatewayError;
              _error = isGatewayError
                  ? _gatewayUnavailableMessage
                  : 'Could not load payment page (${err.description}).';
              _loading = false;
            });
          },
        ),
      );
      await controller.loadRequest(Uri.parse(url));
      if (!mounted) return;
      setState(() {
        _session = session;
        _controller = controller;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      setState(() {
        _loading = false;
        _error = message;
        _gatewayPageError =
            message.contains('public HTTPS') ||
            message.contains('NGROK') ||
            message.contains('502');
      });
    }
  }

  String get _gatewayUnavailableMessage => _sandboxMode
      ? 'Payment page could not load (502).\n'
            '• Wait a minute and retry\n'
            '• Use public HTTPS redirect URLs in backend/.env\n'
            '• Or use demo payment below for local testing'
      : 'Payment page could not load.\n'
            '• Check internet and retry\n'
            '• Confirm UDDOKTAPAY_BASE_URL and API key in backend/.env\n'
            '• BASE_URL must be public HTTPS (ngrok or your domain)';

  Future<void> _checkGatewayPageError(WebViewController web) async {
    if (!mounted || _completing) return;
    try {
      final title = (await web.getTitle())?.toLowerCase() ?? '';
      final body = await web.runJavaScriptReturningResult(
        'document.body ? document.body.innerText.substring(0, 800) : ""',
      );
      final text = body.toString().toLowerCase();
      final bad =
          title.contains('502') ||
          title.contains('bad gateway') ||
          text.contains('502') ||
          text.contains('bad gateway') ||
          text.contains('origin_bad_gateway') ||
          text.contains('cloudflare');
      if (!bad || !mounted) return;
      setState(() {
        _gatewayPageError = true;
        _error = _gatewayUnavailableMessage;
      });
    } catch (_) {
      // ignore probe failures
    }
  }

  Future<void> _useDemoPayment() async {
    final ok = await SubscriptionCheckoutFlow._runDemoDialog(
      context,
      amount: widget.amount,
      plan: widget.plan,
    );
    if (ok && mounted) Navigator.pop(context, true);
  }

  bool _isSuccessUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final path = uri.path.toLowerCase();
    if (path.contains('/payments/uddokta/cancel') ||
        path.contains('/payments/uddokta/fail')) {
      return false;
    }
    final status = uri.queryParameters['status']?.toLowerCase();
    if (status != null &&
        {
          'failed',
          'failure',
          'error',
          'declined',
          'canceled',
          'cancelled',
        }.contains(status)) {
      return false;
    }
    final invoiceId = uri.queryParameters['invoice_id']?.trim();
    if (invoiceId != null && invoiceId.isNotEmpty) {
      _returnInvoiceId = invoiceId;
    }
    if (path.contains('/payments/uddokta/return')) {
      return status == null ||
          status == 'success' ||
          status == 'completed' ||
          status == 'paid';
    }
    return status == 'success' || status == 'completed' || status == 'paid';
  }

  Future<void> _complete() async {
    if (_completing) return;
    _completing = true;
    final app = AppScope.of(context);
    final paymentId = _session?.paymentId;
    if (paymentId == null || paymentId.isEmpty) {
      if (mounted) Navigator.pop(context, false);
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final ok = await app.verifySubscriptionPayment(
      paymentId,
      invoiceId: _returnInvoiceId ?? _session?.invoiceId,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _error = app.lastError ?? 'Payment not completed yet.';
        _completing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PosColors.background,
      appBar: AppBar(
        title: TfText(
          _checkoutTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
            color: PosColors.slate,
          ),
        ),
        backgroundColor: PosColors.background,
        elevation: 0,
        foregroundColor: PosColors.slate,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _completing ? null : () => Navigator.pop(context, false),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && (_controller == null || _gatewayPageError)
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: PosColors.danger, size: 48),
                  const SizedBox(height: 16),
                  TfText(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: PosColors.danger,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TfButton(
                    label: 'Retry',
                    onPressed: () {
                      setState(() {
                        _error = null;
                        _gatewayPageError = false;
                        _loading = true;
                        _controller = null;
                      });
                      _startCheckout();
                    },
                  ),
                  if (_gatewayPageError && _sandboxMode) ...[
                    const SizedBox(height: 12),
                    TfButton(
                      label: 'Use demo payment (dev)',
                      variant: TfButtonVariant.paper,
                      onPressed: _useDemoPayment,
                    ),
                  ],
                ],
              ),
            )
          : Stack(
              children: [
                if (_controller != null)
                  WebViewWidget(controller: _controller!),
                if (_completing)
                  const ColoredBox(
                    color: Color(0x88FFFFFF),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
    );
  }
}
