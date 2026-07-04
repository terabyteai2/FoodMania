import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/desktop_pos.dart';

class TableQrLabelsScreen extends StatefulWidget {
  const TableQrLabelsScreen({super.key});

  @override
  State<TableQrLabelsScreen> createState() => _TableQrLabelsScreenState();
}

class _TableQrLabelsScreenState extends State<TableQrLabelsScreen> {
  DesktopPosSettings? _settings;
  String? _slug;
  bool _loading = true;
  String? _loadError;
  final Set<String> _printing = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final app = AppScope.of(context);

      debugPrint(
        '[TableQrLabels] serverConfig.tableCount=${app.serverConfig.tableCount}',
      );
      debugPrint('[TableQrLabels] publicSlug="${app.serverConfig.publicSlug}"');

      final settings = await app.loadDesktopPosSettings();
      final tableCount = settings.tableCount;
      debugPrint(
        '[TableQrLabels] loaded floorLayout zones=${settings.floorLayout.length} tableCount=$tableCount',
      );

      for (var zi = 0; zi < settings.floorLayout.length; zi++) {
        final zone = settings.floorLayout[zi];
        debugPrint(
          '[TableQrLabels]   zone[$zi] id="${zone.id}" name="${zone.name}" tables=${zone.tables.length}',
        );
        for (var ti = 0; ti < zone.tables.length; ti++) {
          final t = zone.tables[ti];
          debugPrint(
            '[TableQrLabels]     table[$ti] id="${t.id}" label="${t.label}" seats=${t.seats} order=${t.sortOrder}',
          );
        }
      }

      final raw = app.serverConfig.publicSlug.trim().toLowerCase();
      final slug =
          RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$').hasMatch(raw)
          ? raw
          : null;
      debugPrint('[TableQrLabels] slug validated="${slug ?? "(none)"}"');

      if (!mounted) return;
      setState(() {
        _settings = settings;
        _slug = slug;
        _loading = false;
        _loadError = null;
      });
    } catch (e) {
      debugPrint('[TableQrLabels] load error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  String _tableUrl(String tableLabel) =>
      'https://$_slug.quickbytes.buzz/tableorder/$tableLabel';

  List<PosFloorTable> _allTables() {
    final settings = _settings;
    if (settings == null) return [];
    final tables = <PosFloorTable>[];
    for (final zone in settings.floorLayout) {
      tables.addAll(zone.tables);
    }
    tables.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return tables;
  }

  String _displayLabel(PosFloorTable table) {
    final label = table.label.trim();
    if (label.isEmpty) return 'Table ?';
    final parsed = int.tryParse(label);
    if (parsed != null) {
      final app = AppScope.of(context);
      return app.strings.tableLabel(parsed);
    }
    return 'Table $label';
  }

  Future<void> _printLabel(PosFloorTable table) async {
    final app = AppScope.of(context);
    final text = app.strings;
    final label = table.label;
    final slug = _slug;
    if (slug == null) return;

    debugPrint(
      '[TableQrLabels] printLabel label="$label" slug="$slug" url=${_tableUrl(label)}',
    );
    debugPrint(
      '[TableQrLabels] printerState connected=${app.printerState.connected} hasSelected=${app.printerState.hasSelectedPrinter}',
    );

    if (!app.printerState.connected && !app.printerState.hasSelectedPrinter) {
      debugPrint('[TableQrLabels] print aborted — no printer connected');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(text.printerNotConnectedHint)));
      return;
    }

    setState(() => _printing.add(label));
    try {
      await app.printerService.printTableQrLabel(
        tableLabel: label,
        qrUrl: _tableUrl(label),
      );
      debugPrint('[TableQrLabels] print success label="$label"');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label ${text.tableLabelPrinted}')),
      );
    } catch (e) {
      debugPrint('[TableQrLabels] print error label="$label" error=$e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${text.printFailed}: $e')));
    } finally {
      if (mounted) setState(() => _printing.remove(label));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    final printerConnected = app.printerState.connected;

    return Scaffold(
      backgroundColor: PosColors.background,
      appBar: AppBar(
        backgroundColor: PosColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: TfText(
          text.tableQrLabels,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 17,
            color: PosColors.slate,
          ),
        ),
        iconTheme: IconThemeData(color: PosColors.slate),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  printerConnected
                      ? Icons.print_rounded
                      : Icons.print_disabled_rounded,
                  size: 18,
                  color: printerConnected ? PosColors.success : PosColors.muted,
                ),
                const SizedBox(width: 5),
                TfText(
                  printerConnected ? text.connected : text.connect,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: printerConnected
                        ? PosColors.success
                        : PosColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _buildBody(text),
    );
  }

  Widget _buildBody(AppStrings text) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: PosColors.danger,
              ),
              const SizedBox(height: 12),
              TfText(
                'Load error',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: PosColors.slate,
                ),
              ),
              const SizedBox(height: 6),
              TfText(
                _loadError!,
                style: TextStyle(fontSize: 13, color: PosColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TfButton(
                label: 'Retry',
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _loadError = null;
                  });
                  _load();
                },
              ),
            ],
          ),
        ),
      );
    }

    final slug = _slug;
    if (slug == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link_off_rounded, size: 56, color: PosColors.muted),
              const SizedBox(height: 12),
              TfText(
                text.qrUrlSetupRequired,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: PosColors.slate,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              TfText(
                text.qrUrlSetupHelp,
                style: TextStyle(fontSize: 13, color: PosColors.muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final tables = _allTables();
    final rawSlug = slug;

    if (tables.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.table_restaurant_outlined,
                size: 56,
                color: PosColors.muted,
              ),
              const SizedBox(height: 12),
              TfText(
                text.noTablesConfigured,
                style: TextStyle(fontSize: 15, color: PosColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              TfText(
                'Go to Settings → Table Numbers to add tables',
                style: TextStyle(fontSize: 12, color: PosColors.mutedSoft),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: tables.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _DiagnosticBanner(
            slug: rawSlug,
            tablesCount: tables.length,
            printerConnected: AppScope.of(context).printerState.connected,
          );
        }
        final table = tables[index - 1];
        final label = table.label;
        final url = _tableUrl(label);
        final isPrinting = _printing.contains(label);

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TfCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TfText(
                  _displayLabel(table).toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: PosColors.muted,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 150,
                  child: Center(
                    child: QrImageView(
                      data: url,
                      version: QrVersions.auto,
                      gapless: true,
                      size: 150,
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
                ),
                const SizedBox(height: 8),
                TfText(
                  text.scanToOrder,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: PosColors.slate,
                    letterSpacing: -0.56,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    icon: Icon(
                      isPrinting
                          ? Icons.hourglass_top_rounded
                          : Icons.print_rounded,
                      size: 20,
                      color: isPrinting
                          ? PosColors.muted
                          : PosColors.accentStrong,
                    ),
                    onPressed: isPrinting ? null : () => _printLabel(table),
                    tooltip: text.print,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DiagnosticBanner extends StatelessWidget {
  const _DiagnosticBanner({
    required this.slug,
    required this.tablesCount,
    required this.printerConnected,
  });

  final String slug;
  final int tablesCount;
  final bool printerConnected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TfCard(
        padding: const EdgeInsets.all(12),
        color: PosColors.neutralSoft,
        borderColor: PosColors.neutralWash,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: PosColors.accentStrong,
                ),
                const SizedBox(width: 6),
                TfText(
                  'Diagnostics',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: PosColors.accentStrong,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _diagRow('Slug', slug),
            _diagRow('Tables loaded', '$tablesCount'),
            _diagRow(
              'Printer',
              printerConnected ? 'Connected' : 'Disconnected',
            ),
            _diagRow('QR base URL', 'https://$slug.quickbytes.buzz'),
          ],
        ),
      ),
    );
  }

  Widget _diagRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          TfText(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: PosColors.inkSoft,
            ),
          ),
          Expanded(
            child: TfText(
              value,
              style: TextStyle(fontSize: 11, color: PosColors.slate),
            ),
          ),
        ],
      ),
    );
  }
}
