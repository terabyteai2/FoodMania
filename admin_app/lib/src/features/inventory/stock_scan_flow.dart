import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/receipt_scan.dart';
import '../../services/cloud_api_service.dart';
import '../../services/menu_image_service.dart';
import 'end_of_day_count_screen.dart';
import 'stock_in_screen.dart';

/// The stock-scan hero flow, callable from anywhere in the shell (the drawer's
/// Stock ▸ Scan entry): snap a supplier bill OR a count sheet, let the backend
/// classify it, then route into the pre-filled Stock-in or End-of-day screen.
///
/// Shows its own modal progress dialog while the backend classifies the page,
/// and refreshes the inventory summary after the routed screen closes.
Future<void> runStockScanFlow(BuildContext context) async {
  final app = AppScope.read(context);
  final text = app.strings;
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);

  final page = await MenuImageService().captureMenuScanPage(pageNumber: 1);
  if (page == null || !context.mounted) return;

  var progressOpen = true;
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(PosSpacing.sp4),
            decoration: BoxDecoration(
              color: PosColors.surface,
              borderRadius: BorderRadius.circular(PosRadii.md),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
                const SizedBox(width: PosSpacing.sp3),
                TfText(
                  text.scanningStock,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: PosColors.text,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() => progressOpen = false),
  );
  void closeProgress() {
    if (progressOpen) {
      progressOpen = false;
      navigator.pop();
    }
  }

  StockScanResult? result;
  try {
    result = await app.scanInventoryStock([
      MenuScanPageUpload(
        bytes: page.bytes,
        fileName: page.fileName,
        mimeType: page.mimeType,
      ),
    ]);
  } on CloudApiException catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
  } on MenuImageException catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.toString())));
  } finally {
    closeProgress();
  }
  if (result == null || !context.mounted) return;

  final route = switch (result.category) {
    StockScanCategory.count => MaterialPageRoute<void>(
      builder: (_) => EndOfDayCountScreen(initialScan: result),
    ),
    StockScanCategory.stockIn => MaterialPageRoute<void>(
      builder: (_) => StockInScreen(initialScan: result),
    ),
  };
  await navigator.push<void>(route);
  if (context.mounted) await AppScope.read(context).refreshInventorySummary();
}
