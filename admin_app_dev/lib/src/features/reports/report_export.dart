import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Lightweight, model-agnostic export for the Reports section. Builds a plain
/// tabular PDF (shared via the OS sheet) and a CSV copied to the clipboard —
/// using only the existing `pdf` + `printing` deps (no new packages).
class ReportExport {
  /// Share a simple PDF: title, optional subtitle, then sections where each is
  /// (heading, list of (label, value)) rows.
  static Future<void> sharePdf({
    required String title,
    String? subtitle,
    required List<(String, List<(String, String)>)> sections,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (ctx) => [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          if (subtitle != null && subtitle.isNotEmpty)
            pw.Text(
              subtitle,
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
          pw.SizedBox(height: 14),
          for (final (heading, rows) in sections) ...[
            pw.Text(
              heading,
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Table(
              border: pw.TableBorder.symmetric(
                inside: const pw.BorderSide(
                  width: 0.5,
                  color: PdfColors.grey300,
                ),
              ),
              children: [
                for (final (label, value) in rows)
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 6,
                        ),
                        child: pw.Text(label),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 6,
                        ),
                        child: pw.Text(value, textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 14),
          ],
        ],
      ),
    );
    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: '${_slug(title)}.pdf');
  }

  /// Copy rows as CSV to the clipboard (our "Excel" export — no share_plus dep).
  static Future<void> copyCsv(List<List<String>> rows) async {
    final csv = rows.map((r) => r.map(_csvCell).join(',')).join('\n');
    await Clipboard.setData(ClipboardData(text: csv));
  }

  static String _csvCell(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  static String _slug(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
}
