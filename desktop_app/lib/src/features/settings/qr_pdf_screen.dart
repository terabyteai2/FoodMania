import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tf_design_system.dart';

class QrPdfScreen extends StatefulWidget {
  const QrPdfScreen({super.key});

  @override
  State<QrPdfScreen> createState() => _QrPdfScreenState();
}

class _QrPdfScreenState extends State<QrPdfScreen> {
  bool _printing = false;
  bool _saving = false;

  String? _slug(BuildContext context) {
    final slug = AppScope.of(
      context,
    ).serverConfig.publicSlug.trim().toLowerCase();
    if (RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$').hasMatch(slug)) {
      return slug;
    }
    return null;
  }

  int _tableCount(BuildContext context) {
    return AppScope.of(context).serverConfig.tableCount.clamp(0, 200);
  }

  String _mainUrl(String slug) {
    return 'https://$slug.quickbytes.buzz';
  }

  String _tableUrl(String slug, int tableNo) {
    return 'https://$slug.quickbytes.buzz/tableorder/$tableNo';
  }

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
    final image = await painter.toImage(420);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<Uint8List> _buildPdfBytes() async {
    final app = AppScope.of(context);
    final slug = _slug(context);
    if (slug == null) {
      throw StateError('Set a public menu slug before exporting QR codes.');
    }
    final restaurantName = app.serverConfig.restaurantName.trim().isEmpty
        ? 'Restaurant'
        : app.serverConfig.restaurantName.trim();
    final outletName = app.serverConfig.outletName.trim();
    final tableCount = _tableCount(context);
    final tableRows = await Future.wait(
      List.generate(tableCount, (index) async {
        final tableNo = index + 1;
        final url = _tableUrl(slug, tableNo);
        return _TableQrPdfEntry(
          title: 'TABLE $tableNo',
          description: 'Scan to order from this table',
          url: url,
          image: pw.MemoryImage(await _qrBytes(url)),
        );
      }),
    );
    final mainUrl = _mainUrl(slug);
    final rows = [
      _TableQrPdfEntry(
        title: 'RESTAURANT MENU',
        description: 'Scan to view the restaurant menu',
        url: mainUrl,
        image: pw.MemoryImage(await _qrBytes(mainUrl)),
      ),
      ...tableRows,
    ];

    const dark = PdfColor.fromInt(0xFF162033);
    const muted = PdfColor.fromInt(0xFF596275);
    const line = PdfColor.fromInt(0xFFE2E8F0);
    const accent = PdfColor.fromInt(0xFFE28714);

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 32),
        build: (_) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      restaurantName,
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: dark,
                      ),
                    ),
                    if (outletName.isNotEmpty) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(
                        outletName,
                        style: const pw.TextStyle(fontSize: 10, color: muted),
                      ),
                    ],
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: accent, width: 1.3),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                ),
                child: pw.Text(
                  'MAIN MENU + $tableCount TABLE QR CODES',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: dark,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final entry in rows)
                pw.Container(
                  width: 244,
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    border: pw.Border.all(color: line),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(8),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        entry.title,
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: dark,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Image(entry.image, width: 126, height: 126),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        entry.description,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: dark,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        entry.url,
                        textAlign: pw.TextAlign.center,
                        maxLines: 2,
                        style: const pw.TextStyle(fontSize: 6.5, color: muted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
    return doc.save();
  }

  Future<void> _print() async {
    if (_printing || _saving || _slug(context) == null) return;
    setState(() => _printing = true);
    try {
      final bytes = await _buildPdfBytes();
      if (!mounted) return;
      await Printing.layoutPdf(
        name: 'table_qr_codes',
        onLayout: (_) async => bytes,
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _savePdf() async {
    if (_printing || _saving || _slug(context) == null) return;
    setState(() => _saving = true);
    try {
      final app = AppScope.of(context);
      final restaurantName = app.serverConfig.restaurantName.trim().isEmpty
          ? 'Restaurant'
          : app.serverConfig.restaurantName.trim();
      final bytes = await _buildPdfBytes();
      if (!mounted) return;
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${restaurantName.replaceAll(' ', '_')}_Table_QR_Codes.pdf',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    final slug = _slug(context);
    final tableCount = _tableCount(context);
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 980
              ? 4
              : constraints.maxWidth >= 720
              ? 3
              : constraints.maxWidth >= 460
              ? 2
              : 1;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _QrHeader(
                      text: text,
                      slug: slug,
                      tableCount: tableCount,
                      onPrint: _print,
                      onSave: _savePdf,
                      printing: _printing,
                      saving: _saving,
                      busy: busy,
                    ),
                    const SizedBox(height: 18),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: tableCount + 1,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: 238,
                      ),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _TableQrCard(
                            key: const ValueKey('restaurant-main-qr-card'),
                            text: text,
                            isMain: true,
                            url: slug == null ? null : _mainUrl(slug),
                          );
                        }
                        final tableNo = index;
                        return _TableQrCard(
                          text: text,
                          tableNo: tableNo,
                          url: slug == null ? null : _tableUrl(slug, tableNo),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QrHeader extends StatelessWidget {
  const _QrHeader({
    required this.text,
    required this.slug,
    required this.tableCount,
    required this.onPrint,
    required this.onSave,
    required this.printing,
    required this.saving,
    required this.busy,
  });

  final AppStrings text;
  final String? slug;
  final int tableCount;
  final VoidCallback onPrint;
  final VoidCallback onSave;
  final bool printing;
  final bool saving;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final disabled = slug == null;
    return TfCard(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 14,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TfText(
                  disabled
                      ? text.qrUrlSetupRequired
                      : text.qrCodeSummary(tableCount, slug!),
                  style: TextStyle(
                    color: PosColors.slate,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                TfText(
                  disabled ? text.qrUrlSetupHelp : text.qrLinksHelp,
                  style: TextStyle(
                    color: PosColors.muted,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              TfButton(
                label: text.print,
                icon: TfNavIcon.printer,
                busy: printing,
                onPressed: disabled || busy ? null : onPrint,
                size: TfButtonSize.lg,
              ),
              TfButton(
                label: text.savePdf,
                icon: Icons.picture_as_pdf_rounded,
                busy: saving,
                onPressed: disabled || busy ? null : onSave,
                variant: TfButtonVariant.paper,
                size: TfButtonSize.lg,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TableQrCard extends StatelessWidget {
  const _TableQrCard({
    required this.text,
    this.tableNo,
    this.isMain = false,
    required this.url,
    super.key,
  });

  final AppStrings text;
  final int? tableNo;
  final bool isMain;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final enabled = url != null;
    return TfCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TfText(
                  isMain ? text.restaurantMenuQr : text.tableLabel(tableNo!),
                  style: TextStyle(
                    color: PosColors.slate,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                enabled ? Icons.qr_code_2_rounded : Icons.link_off_rounded,
                color: enabled ? PosColors.primaryDark : PosColors.muted,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: enabled
                  ? QrImageView(
                      data: url!,
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
                    )
                  : Icon(
                      Icons.qr_code_2_rounded,
                      size: 82,
                      color: PosColors.line,
                    ),
            ),
          ),
          const SizedBox(height: 10),
          TfText(
            url ?? text.publicSlugRequired,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: enabled ? PosColors.muted : PosColors.danger,
              fontSize: 10.5,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _TableQrPdfEntry {
  const _TableQrPdfEntry({
    required this.title,
    required this.description,
    required this.url,
    required this.image,
  });

  final String title;
  final String description;
  final String url;
  final pw.ImageProvider image;
}
