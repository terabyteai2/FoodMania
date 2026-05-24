import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app_scope.dart';
import '../../core/constants/cloud_defaults.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tf_design_system.dart';

class QrPdfScreen extends StatefulWidget {
  const QrPdfScreen({super.key});

  @override
  State<QrPdfScreen> createState() => _QrPdfScreenState();
}

class _QrPdfScreenState extends State<QrPdfScreen> {
  final _urlCtrl = TextEditingController();
  bool _printing = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_urlCtrl.text.isEmpty) {
      final app = AppScope.of(context);
      final outletId = app.serverConfig.outletId.trim();
      _urlCtrl.text = CloudDefaults.customerMenuUrl(
        baseUrl: app.cloudConfig.baseUrl.isNotEmpty
            ? app.cloudConfig.baseUrl
            : CloudDefaults.defaultPublicApiBase,
        outletId: outletId,
        publicSlug: app.serverConfig.publicSlug,
      );
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  String get _qrUrl => _urlCtrl.text.trim().replaceAll(RegExp(r'/+$'), '');

  Future<Uint8List> _qrBytes(String data) async {
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: true,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: ui.Color(0xFF1A1A2E),
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: ui.Color(0xFF1A1A2E),
      ),
    );
    final image = await painter.toImage(512);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<Uint8List> _buildPdfBytes() async {
    final url = _qrUrl;
    final app = AppScope.of(context);
    final restaurantName = app.serverConfig.restaurantName.isEmpty
        ? 'Restaurant'
        : app.serverConfig.restaurantName;
    final outletName = app.serverConfig.outletName;

    final qrBytes = await _qrBytes(url);
    final qrImage = pw.MemoryImage(qrBytes);

    const gold = PdfColor.fromInt(0xFFE8C547);
    const dark = PdfColor.fromInt(0xFF1A1A2E);
    const subtle = PdfColor.fromInt(0xFF6B7280);
    const bg = PdfColor.fromInt(0xFFFFFBF0);
    const line = PdfColor.fromInt(0xFFE5E7EB);

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (_) => pw.Center(
          child: pw.Container(
            width: 340,
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: line, width: 2),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(20)),
            ),
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 36,
            ),
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  width: 56,
                  height: 56,
                  decoration: pw.BoxDecoration(
                    color: gold,
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(14),
                    ),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      restaurantName.isNotEmpty
                          ? restaurantName[0].toUpperCase()
                          : 'R',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: dark,
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(height: 14),
                pw.Text(
                  restaurantName,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: dark,
                  ),
                ),
                if (outletName.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    outletName,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: 11, color: subtle),
                  ),
                ],
                pw.SizedBox(height: 24),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: pw.BoxDecoration(
                    color: bg,
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(10),
                    ),
                    border: pw.Border.all(color: gold, width: 1.5),
                  ),
                  child: pw.Text(
                    'স্ক্যান করে অর্ডার করুন  ·  Scan to Order',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: dark,
                    ),
                  ),
                ),
                pw.SizedBox(height: 24),
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(12),
                    ),
                    border: pw.Border.all(color: line, width: 1.5),
                  ),
                  child: pw.Image(
                    qrImage,
                    width: 200,
                    height: 200,
                    fit: pw.BoxFit.contain,
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  url,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 8, color: subtle),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return doc.save();
  }

  Future<void> _print() async {
    if (_printing || _saving || _qrUrl.isEmpty) return;
    setState(() => _printing = true);
    try {
      final app = AppScope.of(context);
      final restaurantName = app.serverConfig.restaurantName.isEmpty
          ? 'Restaurant'
          : app.serverConfig.restaurantName;
      final bytes = await _buildPdfBytes();
      if (!mounted) return;
      await Printing.layoutPdf(
        name: '${restaurantName.replaceAll(' ', '_')}_Menu_QR',
        onLayout: (_) async => bytes,
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _savePdf() async {
    if (_printing || _saving || _qrUrl.isEmpty) return;
    setState(() => _saving = true);
    try {
      final app = AppScope.of(context);
      final restaurantName = app.serverConfig.restaurantName.isEmpty
          ? 'Restaurant'
          : app.serverConfig.restaurantName;
      final bytes = await _buildPdfBytes();
      if (!mounted) return;
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${restaurantName.replaceAll(' ', '_')}_Menu_QR.pdf',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    final restaurantName = app.serverConfig.restaurantName.isEmpty
        ? 'Restaurant'
        : app.serverConfig.restaurantName;
    final busy = _printing || _saving;

    return Scaffold(
      backgroundColor: PosColors.background,
      appBar: AppBar(
        backgroundColor: PosColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: TfText(
          text.tableQrCodes,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 17,
            color: PosColors.slate,
          ),
        ),
        iconTheme: IconThemeData(color: PosColors.slate),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── URL field ───────────────────────────────────────────────
                _UrlField(
                  controller: _urlCtrl,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 24),

                // ── Full-width live QR preview ───────────────────────────────
                _QrPreviewCard(url: _qrUrl, restaurantName: restaurantName),
                const SizedBox(height: 28),

                // ── Action buttons ───────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: 'Print',
                        icon: Icons.print_rounded,
                        busy: _printing,
                        enabled: !busy && _qrUrl.isNotEmpty,
                        onPressed: _print,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionButton(
                        label: 'Save as PDF',
                        icon: Icons.picture_as_pdf_rounded,
                        busy: _saving,
                        enabled: !busy && _qrUrl.isNotEmpty,
                        onPressed: _savePdf,
                        outlined: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── URL field card ────────────────────────────────────────────────────────────

class _UrlField extends StatelessWidget {
  const _UrlField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    return TfCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TfText(
            text.orderingUrl,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12.5,
              color: PosColors.slate,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13.5,
              color: PosColors.slate,
            ),
            decoration: InputDecoration(
              hintText: text.orderingUrlHint,
              prefixIcon: const Icon(Icons.link_rounded),
              isDense: true,
            ),
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}

// ── Live QR preview ───────────────────────────────────────────────────────────

class _QrPreviewCard extends StatelessWidget {
  const _QrPreviewCard({required this.url, required this.restaurantName});

  final String url;
  final String restaurantName;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final qrSize = (screenWidth - 80).clamp(200.0, 400.0);

    return SizedBox(
      width: double.infinity,
      child: TfCard(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          children: [
            // Restaurant name
            TfText(
              restaurantName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 20,
                color: PosColors.slate,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 16),

            // "Scan to Order" pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: PosColors.primarySoft,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: PosColors.primary, width: 1.5),
              ),
              child: TfText(
                'স্ক্যান করে অর্ডার করুন  ·  Scan to Order',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: PosColors.primaryDark,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // QR code — live, large
            if (url.isEmpty)
              SizedBox(
                width: qrSize,
                height: qrSize,
                child: Center(
                  child: Icon(
                    Icons.qr_code_2_rounded,
                    size: qrSize * 0.5,
                    color: PosColors.line,
                  ),
                ),
              )
            else
              Container(
                width: qrSize,
                height: qrSize,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PosColors.line, width: 1.5),
                ),
                child: QrImageView(
                  data: url,
                  version: QrVersions.auto,
                  gapless: true,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: PosColors.slate,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: PosColors.slate,
                  ),
                ),
              ),
            const SizedBox(height: 14),

            // URL chip below QR
            if (url.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: PosColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: PosColors.line),
                ),
                child: TfText(
                  url,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w400,
                    color: PosColors.muted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.busy,
    required this.enabled,
    required this.onPressed,
    this.outlined = false,
  });

  final String label;
  final IconData icon;
  final bool busy;
  final bool enabled;
  final VoidCallback onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return TfButton(
      label: label,
      icon: icon,
      busy: busy,
      onPressed: enabled ? onPressed : null,
      variant: outlined ? TfButtonVariant.paper : TfButtonVariant.primary,
      size: TfButtonSize.lg,
    );
  }
}
