import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/receipt_scan.dart';
import 'end_of_day_count_screen.dart';
import 'stock_in_screen.dart';
import 'stock_scan_screen.dart';

/// The stock-scan hero flow, callable from anywhere in the shell (the drawer's
/// Stock ▸ Scan entry): navigate to [StockScanScreen] where the user captures
/// one or more pages, then route into the pre-filled Stock-in or End-of-day
/// screen based on the backend classification, and refresh inventory summary.
Future<void> runStockScanFlow(
  BuildContext context, {
  required void Function(String message) showScanOverlay,
  required VoidCallback hideScanOverlay,
}) async {
  final navigator = Navigator.of(context);
  final app = AppScope.read(context);
  final text = app.strings;

  await navigator.push<StockScanResult>(
    MaterialPageRoute<StockScanResult>(
      builder: (_) => StockScanScreen(
        onScan: (uploads) async {
          showScanOverlay(text.scanningStock);
          StockScanResult? result;
          try {
            result = await app.scanInventoryStock(uploads);
          } catch (error) {
            hideScanOverlay();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: TfText('${text.receiptScanFailed}: $error')),
            );
            return;
          }
          hideScanOverlay();
          if (!context.mounted) return;

          final route = switch (result.category) {
            StockScanCategory.count => MaterialPageRoute<void>(
              builder: (_) => EndOfDayCountScreen(initialScan: result),
            ),
            StockScanCategory.stockIn => MaterialPageRoute<void>(
              builder: (_) => StockInScreen(initialScan: result),
            ),
          };
          await navigator.push<void>(route);
          if (context.mounted) {
            await AppScope.read(context).refreshInventorySummary();
          }
        },
      ),
    ),
  );
}
