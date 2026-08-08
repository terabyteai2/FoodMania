import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/sales_report.dart';
import '../models/server_config.dart';

class ReportPdfService {
  ReportPdfService();

  final NumberFormat _currency = NumberFormat.currency(
    symbol: '৳',
    decimalDigits: 2,
  );
  final DateFormat _date = DateFormat('MMM d, yyyy');
  final DateFormat _shortDate = DateFormat('MMM d');

  Future<Uint8List> buildSalesReportPdf({
    required SalesReport report,
    required ServerConfig serverConfig,
  }) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: pw.EdgeInsets.all(28),
          theme: pw.ThemeData.withFont(),
        ),
        build: (context) => [
          _header(report, serverConfig),
          pw.SizedBox(height: 18),
          _summaryGrid(report),
          pw.SizedBox(height: 18),
          _dailyTable(report),
          pw.SizedBox(height: 18),
          _topItemsTable(report),
          pw.SizedBox(height: 18),
          _footer(),
        ],
      ),
    );
    return document.save();
  }

  Future<void> shareSalesReport({
    required SalesReport report,
    required ServerConfig serverConfig,
  }) async {
    final bytes = await buildSalesReportPdf(
      report: report,
      serverConfig: serverConfig,
    );
    await Printing.sharePdf(bytes: bytes, filename: _fileName(report));
  }

  Future<void> printSalesReport({
    required SalesReport report,
    required ServerConfig serverConfig,
  }) async {
    final bytes = await buildSalesReportPdf(
      report: report,
      serverConfig: serverConfig,
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: report.title);
  }

  pw.Widget _header(SalesReport report, ServerConfig serverConfig) {
    final restaurantName = serverConfig.restaurantName.trim().isEmpty
        ? 'Restaurant'
        : serverConfig.restaurantName.trim();
    final outletName = serverConfig.outletName.trim().isEmpty
        ? 'Outlet'
        : serverConfig.outletName.trim();
    final endDate = report.endAt.subtract(Duration(days: 1));
    return pw.Container(
      padding: pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#0F766E'),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            report.title,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            '$restaurantName · $outletName',
            style: pw.TextStyle(color: PdfColors.white, fontSize: 12),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${_date.format(report.startAt)} - ${_date.format(endDate)}',
            style: pw.TextStyle(color: PdfColors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }

  pw.Widget _summaryGrid(SalesReport report) {
    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _summaryTile('Total sales', _currency.format(report.totalSales)),
        _summaryTile('Orders', report.totalOrders.toString()),
        _summaryTile('Avg order', _currency.format(report.averageOrderValue)),
        _summaryTile('Items sold', report.totalItemsSold.toString()),
        _summaryTile('Open orders', report.openOrders.toString()),
        _summaryTile('Cancelled', report.cancelledOrders.toString()),
      ],
    );
  }

  pw.Widget _summaryTile(String label, String value) {
    return pw.Container(
      width: 165,
      padding: pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(color: PdfColors.grey700, fontSize: 9),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  pw.Widget _dailyTable(SalesReport report) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Daily breakdown'),
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Orders', 'Sales'],
          data: report.dailyBreakdown
              .map(
                (day) => [
                  _shortDate.format(day.date),
                  day.orders.toString(),
                  _currency.format(day.sales),
                ],
              )
              .toList(growable: false),
          headerDecoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#ECFDF5'),
          ),
          border: pw.TableBorder.all(color: PdfColor.fromHex('#E2E8F0')),
          cellAlignment: pw.Alignment.centerLeft,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellStyle: pw.TextStyle(fontSize: 10),
          cellPadding: pw.EdgeInsets.all(8),
        ),
      ],
    );
  }

  pw.Widget _topItemsTable(SalesReport report) {
    final data = report.topItems.isEmpty
        ? [
            ['No item sales in this period', '-', '-'],
          ]
        : report.topItems
              .map(
                (item) => [
                  item.name,
                  item.qty.toString(),
                  _currency.format(item.sales),
                ],
              )
              .toList(growable: false);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Top selling items'),
        pw.TableHelper.fromTextArray(
          headers: ['Item', 'Qty', 'Sales'],
          data: data,
          headerDecoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#FFF7ED'),
          ),
          border: pw.TableBorder.all(color: PdfColor.fromHex('#E2E8F0')),
          cellAlignment: pw.Alignment.centerLeft,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellStyle: pw.TextStyle(fontSize: 10),
          cellPadding: pw.EdgeInsets.all(8),
        ),
      ],
    );
  }

  pw.Widget _sectionTitle(String title) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _footer() {
    return pw.Text(
      'Generated by Hybrid POS Admin on ${DateFormat('MMM d, yyyy h:mm a').format(DateTime.now())}',
      style: pw.TextStyle(color: PdfColors.grey600, fontSize: 9),
    );
  }

  String _fileName(SalesReport report) {
    final stamp = DateFormat('yyyyMMdd').format(DateTime.now());
    return 'sales-report-${report.days}d-$stamp.pdf';
  }
}
