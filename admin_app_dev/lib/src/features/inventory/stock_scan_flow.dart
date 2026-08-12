import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/receipt_scan.dart';
import 'stock_scan_screen.dart';

/// The stock-scan hero flow, callable from anywhere in the shell (the drawer's
/// Stock ▸ Scan entry): navigate to [StockScanScreen] where the user captures
/// one or more pages, run the unified inventory scan, then return the parsed
/// result so the shell can surface the changes directly on the Stock page
/// table for review (Confirm / Cancel CTA lives on the table itself).
Future<StockScanResult?> runStockScanFlow(
  BuildContext context, {
  required void Function(String message) showScanOverlay,
  required VoidCallback hideScanOverlay,
}) async {
  final navigator = Navigator.of(context);
  final app = AppScope.read(context);
  final text = app.strings;

  return navigator.push<StockScanResult>(
    MaterialPageRoute<StockScanResult>(
      builder: (_) => StockScanScreen(
        onScan: (uploads) async {
          showScanOverlay(text.scanningStock);
          try {
            final result = await app.scanInventoryStock(uploads);
            hideScanOverlay();
            return result;
          } catch (error) {
            hideScanOverlay();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: TfText('${text.receiptScanFailed}: $error')),
              );
            }
            return null;
          }
        },
      ),
    ),
  );
}