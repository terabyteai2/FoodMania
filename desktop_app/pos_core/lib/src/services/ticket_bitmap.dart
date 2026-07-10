import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

import '../core/widgets/tf_design_system.dart';

class TicketLineItem {
  const TicketLineItem({
    required this.index,
    required this.name,
    required this.qtyText,
    required this.lineTotalText,
  });

  final int index;
  final String name;
  final String qtyText;
  final String lineTotalText;
}

class TicketSummaryRow {
  const TicketSummaryRow({
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool emphasis;
}

class TicketCopyData {
  const TicketCopyData({
    required this.restaurantName,
    required this.outletName,
    this.restaurantSubtitle,
    required this.orderNumberDisplay,
    required this.orderTypeLabel,
    required this.dateLine,
    required this.tableLine,
    required this.sourceLine,
    required this.items,
    required this.totalLabel,
    required this.totalAmount,
    required this.totalNote,
    required this.isManagerCopy,
    required this.customerName,
    required this.customerNameLabel,
    required this.note,
    required this.noteLabel,
    this.orderDetailsUrl,
    this.deliveryAddress,
    this.deliveryAddressLabel = 'Address',
    this.mobileNumber,
    this.mobileNumberLabel = 'Phone',
    this.summaryRows = const [],
    this.paymentLine,
    this.qrCaption,
    this.footerText,
    this.serverRole,
  });

  final String restaurantName;
  final String? outletName;
  final String? restaurantSubtitle;
  final String orderNumberDisplay;
  final String orderTypeLabel;
  final String dateLine;
  final String tableLine;
  final String sourceLine;
  final List<TicketLineItem> items;
  final String totalLabel;
  final String totalAmount;
  final String totalNote;
  final bool isManagerCopy;
  final String? customerName;
  final String customerNameLabel;
  final String? note;
  final String noteLabel;
  final String? orderDetailsUrl;
  final String? deliveryAddress;
  final String deliveryAddressLabel;
  final String? mobileNumber;
  final String mobileNumberLabel;
  final List<TicketSummaryRow> summaryRows;
  final String? paymentLine;
  final String? qrCaption;
  final String? footerText;
  final String? serverRole;
}

class KotLineItem {
  const KotLineItem({
    required this.qtyText,
    required this.name,
    this.modifiers = '',
    this.note,
  });

  final String qtyText;
  final String name;
  final String modifiers;
  final String? note;
}

class KotTicketData {
  const KotTicketData({
    required this.restaurantName,
    this.restaurantSubtitle,
    required this.serialLabel,
    required this.serialValue,
    required this.dateLabel,
    required this.dateValue,
    required this.timeLabel,
    required this.timeValue,
    required this.typeLabel,
    required this.typeValue,
    required this.items,
    this.itemsLabel = 'Items',
    this.noteLabel = 'Note',
    this.serverLabel = 'Server',
    this.tableLabel,
    this.tableValue,
    this.serverName,
  });

  final String restaurantName;
  final String? restaurantSubtitle;
  final String serialLabel;
  final String serialValue;
  final String dateLabel;
  final String dateValue;
  final String timeLabel;
  final String timeValue;
  final String typeLabel;
  final String typeValue;
  final String? tableLabel;
  final String? tableValue;
  final List<KotLineItem> items;
  final String itemsLabel;
  final String noteLabel;
  final String serverLabel;
  final String? serverName;
}

class UtilityTicketSection {
  const UtilityTicketSection({required this.title, required this.lines});

  final String title;
  final List<String> lines;
}

class UtilityTicketData {
  const UtilityTicketData({
    required this.title,
    this.subtitle,
    this.warning,
    this.headerRows = const [],
    this.sections = const [],
    this.totalRows = const [],
    this.footerLines = const [],
  });

  final String title;
  final String? subtitle;
  final String? warning;
  final List<TicketSummaryRow> headerRows;
  final List<UtilityTicketSection> sections;
  final List<TicketSummaryRow> totalRows;
  final List<String> footerLines;
}

class TicketBitmapRenderer {
  TicketBitmapRenderer._();

  // Deli ES421-class 58mm printers expose 384 printable dots. Wider bitmaps
  // are clipped on the right, exactly where amounts and restaurant names sit.
  static const double _width = 384;
  static const double _padding = 16;

  static int get debugPrintableWidth => _width.toInt();

  static int debugPrintableWidthForPaper(int paperWidthMm) {
    return paperWidthMm == 80 ? 576 : 384;
  }

  static Future<Uint8List> renderKot(KotTicketData data) async {
    final noteCount = data.items
        .where((item) => item.note?.trim().isNotEmpty == true)
        .length;
    final dynamicRows = data.items.length * 44;
    final noteRows = noteCount == 0 ? 0 : 46 + (noteCount * 38);
    final hasTable =
        data.tableLabel?.trim().isNotEmpty == true &&
        data.tableValue?.trim().isNotEmpty == true;
    final height = (336 + dynamicRows + noteRows + (hasTable ? 30 : 0))
        .toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _width, height),
      Paint()..color = Colors.white,
    );

    var y = 0.0;
    y = _text(
      canvas,
      'KITCHEN ORDER',
      y + 10,
      fontSize: 42,
      weight: FontWeight.w800,
      align: TextAlign.center,
    );
    y = _rule(canvas, y + 8);
    y = _row(canvas, '${data.serialLabel}:', data.serialValue, y, fontSize: 26);
    y = _row(canvas, '${data.dateLabel}:', data.dateValue, y, fontSize: 26);
    y = _row(canvas, '${data.timeLabel}:', data.timeValue, y, fontSize: 26);
    y = _row(canvas, '${data.typeLabel}:', data.typeValue, y, fontSize: 26);
    if (hasTable) {
      y = _row(
        canvas,
        '${data.tableLabel!.trim()}:',
        data.tableValue!.trim(),
        y,
        fontSize: 26,
      );
    }
    y = _rule(canvas, y + 8);
    y = _text(
      canvas,
      data.itemsLabel,
      y,
      fontSize: 28,
      weight: FontWeight.w700,
    );
    for (final item in data.items) {
      y = _kotItemRow(canvas, item, y);
    }

    final notedItems = [
      for (final item in data.items)
        if (item.note?.trim().isNotEmpty == true) item,
    ];
    if (notedItems.isNotEmpty) {
      y = _rule(canvas, y + 8);
      y = _text(
        canvas,
        data.noteLabel,
        y,
        fontSize: 28,
        weight: FontWeight.w700,
      );
      for (final item in notedItems) {
        y = _text(
          canvas,
          item.note!.trim(),
          y,
          fontSize: 25,
          weight: FontWeight.w700,
        );
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(_width.toInt(), y.ceil());
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) {
      throw StateError('KOT bitmap encoding failed.');
    }
    return png.buffer.asUint8List();
  }

  static Future<Uint8List> render(TicketCopyData data) async {
    final isDelivery = data.deliveryAddress?.trim().isNotEmpty == true;

    final height = 4000.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _width, height),
      Paint()..color = Colors.white,
    );

    var y = 0.0;

    // 1. Restaurant name (Double-W/H, max 24 chars)
    final name = data.restaurantName.length > 24
        ? data.restaurantName.substring(0, 24)
        : data.restaurantName;
    y = _text(
      canvas,
      name,
      y + 8,
      fontSize: 48,
      weight: FontWeight.w800,
      align: TextAlign.center,
    );

    // 3. Service type heading (Bold, centered)
    y = _text(
      canvas,
      data.orderTypeLabel.toUpperCase(),
      y,
      fontSize: 24,
      weight: FontWeight.w700,
      align: TextAlign.center,
    );

    // 4. Order number (Bold, left)
    y = _text(
      canvas,
      'Order: ${data.orderNumberDisplay}',
      y,
      fontSize: 22,
      weight: FontWeight.w700,
      align: TextAlign.left,
    );

    // 5. Table line (same typography as Order #)
    if (!isDelivery && data.tableLine.trim().isNotEmpty == true) {
      y = _text(
        canvas,
        data.tableLine,
        y,
        fontSize: 22,
        weight: FontWeight.w700,
        align: TextAlign.left,
      );
    }

    // 6. Date line
    y = _text(
      canvas,
      'Date: ${data.dateLine}',
      y,
      fontSize: 22,
      weight: FontWeight.w500,
      align: TextAlign.left,
    );

    // 7. Source line
    y = _text(
      canvas,
      'Source: ${data.sourceLine}',
      y,
      fontSize: 22,
      weight: FontWeight.w500,
      align: TextAlign.left,
    );

    // 7. Single divider
    y = _rule(canvas, y + 4);

    // 8. Item rows
    for (final item in data.items) {
      y = _itemRow(canvas, item, y);
    }

    // 10. Single divider
    y = _rule(canvas, y + 4);

    // 11. Summary rows
    if (data.summaryRows.isEmpty) {
      y = _row(
        canvas,
        data.totalLabel,
        data.totalAmount,
        y,
        fontSize: 24,
        weight: FontWeight.w700,
      );
    } else {
      for (final row in data.summaryRows) {
        y = _row(
          canvas,
          row.label,
          row.value,
          y,
          fontSize: row.emphasis ? 24 : 22,
          weight: row.emphasis ? FontWeight.w800 : FontWeight.w500,
        );
      }
    }

    // 12. Single divider + payment
    if (data.paymentLine?.trim().isNotEmpty == true) {
      y = _rule(canvas, y + 4);
      y = _text(
        canvas,
        data.paymentLine!.trim(),
        y,
        fontSize: 22,
        weight: FontWeight.w700,
        align: TextAlign.left,
      );
    }

    // 13. Customer info section
    if (data.customerName?.trim().isNotEmpty == true) {
      y = _text(
        canvas,
        '${data.customerNameLabel}: ${data.customerName!.trim()}',
        y,
        fontSize: 22,
      );
    }
    if (isDelivery && data.deliveryAddress?.trim().isNotEmpty == true) {
      y = _multilineText(
        canvas,
        '${data.deliveryAddressLabel}: ${data.deliveryAddress!.trim()}',
        y,
        fontSize: 22,
      );
    }
    if (isDelivery && data.mobileNumber?.trim().isNotEmpty == true) {
      y = _text(
        canvas,
        '${data.mobileNumberLabel}: ${data.mobileNumber!.trim()}',
        y,
        fontSize: 22,
      );
    }
    // 14. QR code
    final qrUrl = data.orderDetailsUrl?.trim();
    if (qrUrl != null && qrUrl.isNotEmpty) {
      y = _drawQrCentered(canvas, qrUrl, y + 6);
    }

    // 15. QR caption
    if (data.qrCaption?.trim().isNotEmpty == true) {
      y = _text(
        canvas,
        data.qrCaption!.trim(),
        y + 4,
        fontSize: 20,
        weight: FontWeight.w500,
        align: TextAlign.center,
      );
    }
    if (data.footerText?.trim().isNotEmpty == true) {
      y = _text(
        canvas,
        data.footerText!.trim(),
        y,
        fontSize: 20,
        weight: FontWeight.w500,
        align: TextAlign.center,
      );
    }

    // 16. Double-line bottom border
    y = _doubleRule(canvas, y + 8);

    final picture = recorder.endRecording();
    final image = await picture.toImage(_width.toInt(), y.ceil());
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) {
      throw StateError('Ticket bitmap encoding failed.');
    }
    return png.buffer.asUint8List();
  }

  static Future<Uint8List> renderTableQrLabel({
    required String tableLabel,
    required String qrUrl,
    String? restaurantName,
    double paperWidthPx = 384,
  }) async {
    debugPrint(
      '[TicketBitmap] renderTableQrLabel tableLabel="$tableLabel" qrUrl="$qrUrl" paperWidthPx=$paperWidthPx',
    );
    const qrTargetPx = 156;
    final qrCode = QrCode.fromData(
      data: qrUrl,
      errorCorrectLevel: QrErrorCorrectLevel.L,
    );
    final qrImage = QrImage(qrCode);
    final modules = qrImage.moduleCount;
    final modulePx = (qrTargetPx / modules).floor().clamp(1, 6);
    final qrSizePx = modules * modulePx;
    debugPrint(
      '[TicketBitmap] renderTableQrLabel modules=$modules modulePx=$modulePx qrSizePx=$qrSizePx',
    );

    const labelFontSize = 26.0;
    const labelHeight = 39.0;
    const nameFontSize = 21.0;
    const nameHeight = 36.0;
    const scanFontSize = 49.0;
    const scanHeight = 68.0;
    const topPad = 18.0;
    const gap1 = 13.0;
    const gap2 = 13.0;
    const gap3 = 8.0;
    const botPad = 23.0;
    final hasName = restaurantName != null && restaurantName.trim().isNotEmpty;

    final height =
        (topPad + labelHeight + gap1 + qrSizePx + gap2 +
         (hasName ? nameHeight + gap3 : 0) +
         scanHeight + botPad)
            .toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, paperWidthPx, height),
      Paint()..color = Colors.white,
    );

    var y = topPad;
    y = _text(
      canvas,
      tableLabel,
      y,
      fontSize: labelFontSize,
      weight: FontWeight.w700,
      align: TextAlign.center,
    );
    y += gap1;

    final left = (paperWidthPx - qrSizePx) / 2;
    final paint = Paint()..color = Colors.black;
    for (var row = 0; row < modules; row++) {
      for (var col = 0; col < modules; col++) {
        if (!qrImage.isDark(row, col)) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            left + col * modulePx.toDouble(),
            y + row * modulePx.toDouble(),
            modulePx.toDouble(),
            modulePx.toDouble(),
          ),
          paint,
        );
      }
    }
    y += qrSizePx + gap2;

    if (hasName) {
      y = _text(
        canvas,
        restaurantName.trim(),
        y,
        fontSize: nameFontSize,
        weight: FontWeight.w500,
        align: TextAlign.center,
      );
      y += gap3;
    }

    _text(
      canvas,
      'SCAN TO ORDER',
      y,
      fontSize: scanFontSize,
      weight: FontWeight.w800,
      align: TextAlign.center,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(paperWidthPx.toInt(), height.ceil());
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) {
      throw StateError('Table QR label bitmap encoding failed.');
    }
    return png.buffer.asUint8List();
  }

  static Future<Uint8List> renderUtility(UtilityTicketData data) async {
    final sectionLines = data.sections.fold<int>(
      0,
      (total, section) => total + section.lines.length + 1,
    );
    final height =
        (260 +
                data.headerRows.length * 34 +
                sectionLines * 34 +
                data.totalRows.length * 38 +
                data.footerLines.length * 34)
            .toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _width, height),
      Paint()..color = Colors.white,
    );

    var y = 0.0;
    final warning = data.warning?.trim();
    if (warning != null && warning.isNotEmpty) {
      y = _text(
        canvas,
        warning,
        y + 10,
        fontSize: 22,
        weight: FontWeight.w800,
        align: TextAlign.center,
      );
      y = _rule(canvas, y + 4);
    }
    y = _text(
      canvas,
      data.title,
      y + 10,
      fontSize: 34,
      weight: FontWeight.w800,
      align: TextAlign.center,
    );
    final subtitle = data.subtitle?.trim();
    if (subtitle != null && subtitle.isNotEmpty) {
      y = _text(
        canvas,
        subtitle,
        y,
        fontSize: 20,
        weight: FontWeight.w600,
        align: TextAlign.center,
      );
    }
    y = _rule(canvas, y + 8);
    for (final row in data.headerRows) {
      y = _row(
        canvas,
        row.label,
        row.value,
        y,
        fontSize: row.emphasis ? 25 : 22,
        weight: row.emphasis ? FontWeight.w800 : FontWeight.w500,
      );
    }
    for (final section in data.sections) {
      y = _rule(canvas, y + 8);
      y = _text(
        canvas,
        section.title,
        y,
        fontSize: 24,
        weight: FontWeight.w800,
      );
      for (final line in section.lines) {
        y = _text(canvas, line, y, fontSize: 22);
      }
    }
    if (data.totalRows.isNotEmpty) {
      y = _rule(canvas, y + 8);
      for (final row in data.totalRows) {
        y = _row(
          canvas,
          row.label,
          row.value,
          y,
          fontSize: row.emphasis ? 27 : 22,
          weight: row.emphasis ? FontWeight.w800 : FontWeight.w500,
        );
      }
    }
    if (data.footerLines.isNotEmpty) {
      y = _rule(canvas, y + 8);
      for (final line in data.footerLines) {
        y = _text(
          canvas,
          line,
          y,
          fontSize: 21,
          weight: FontWeight.w600,
          align: TextAlign.center,
        );
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(_width.toInt(), y.ceil());
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) {
      throw StateError('Utility ticket bitmap encoding failed.');
    }
    return png.buffer.asUint8List();
  }

  static double _doubleRule(Canvas canvas, double y) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(_padding, y), Offset(_width - _padding, y), paint);
    canvas.drawLine(
      Offset(_padding, y + 3),
      Offset(_width - _padding, y + 3),
      paint,
    );
    return y + 12;
  }

  static double _multilineText(
    Canvas canvas,
    String value,
    double y, {
    double fontSize = 25,
    FontWeight weight = FontWeight.w500,
  }) {
    final maxWidth = _width - (_padding * 2);
    final painter = _painter(value, fontSize: fontSize, weight: weight)
      ..layout(maxWidth: maxWidth);
    painter.paint(canvas, Offset(_padding, y));
    return y + painter.height + 5;
  }

  static double _drawQrCentered(Canvas canvas, String data, double y) {
    try {
      final qrCode = QrCode.fromData(
        data: data,
        errorCorrectLevel: QrErrorCorrectLevel.L,
      );
      final qrImage = QrImage(qrCode);
      const targetPx = 116;
      final modules = qrImage.moduleCount;
      final modulePx = (targetPx / modules).floor().clamp(1, 6);
      final qrSizePx = modules * modulePx;
      final left = (_width - qrSizePx) / 2;
      final paint = Paint()..color = Colors.black;
      for (var row = 0; row < modules; row++) {
        for (var col = 0; col < modules; col++) {
          if (!qrImage.isDark(row, col)) continue;
          canvas.drawRect(
            Rect.fromLTWH(
              left + col * modulePx.toDouble(),
              y + row * modulePx.toDouble(),
              modulePx.toDouble(),
              modulePx.toDouble(),
            ),
            paint,
          );
        }
      }
      return y + qrSizePx + 8;
    } catch (_) {
      return y;
    }
  }

  static double _rule(Canvas canvas, double y) {
    canvas.drawLine(
      Offset(_padding, y),
      Offset(_width - _padding, y),
      Paint()
        ..color = Colors.black
        ..strokeWidth = 1.5,
    );
    return y + 14;
  }

  static double _text(
    Canvas canvas,
    String value,
    double y, {
    double fontSize = 25,
    FontWeight weight = FontWeight.w500,
    TextAlign align = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: Colors.black,
          fontFamily: _fontFamily(value),
          fontSize: fontSize,
          fontWeight: weight,
          height: 1.18,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _width - (_padding * 2));
    final x = switch (align) {
      TextAlign.center => (_width - painter.width) / 2,
      TextAlign.right || TextAlign.end => _width - _padding - painter.width,
      _ => _padding,
    };
    painter.paint(canvas, Offset(x, y));
    return y + painter.height + 5;
  }

  static double _row(
    Canvas canvas,
    String left,
    String right,
    double y, {
    double fontSize = 25,
    FontWeight weight = FontWeight.w500,
  }) {
    final leftPainter = _painter(left, fontSize: fontSize, weight: weight);
    final rightPainter = _painter(
      right,
      fontSize: fontSize,
      weight: weight,
      align: TextAlign.right,
    );
    final maxRightWidth = (_width - (_padding * 2)) * 0.5;
    rightPainter.layout(maxWidth: maxRightWidth);
    final leftMaxWidth = (_width - (_padding * 2)) - rightPainter.width - 18;
    leftPainter.layout(maxWidth: leftMaxWidth.clamp(72, _width).toDouble());

    leftPainter.paint(canvas, Offset(_padding, y));
    rightPainter.paint(
      canvas,
      Offset(_width - _padding - rightPainter.width, y),
    );
    return y +
        (leftPainter.height > rightPainter.height
            ? leftPainter.height
            : rightPainter.height) +
        5;
  }

  static double _itemRow(Canvas canvas, TicketLineItem item, double y) {
    const maxRightWidth = 98.0;
    final amount = _painter(
      item.lineTotalText,
      fontSize: 20,
      weight: FontWeight.w500,
      align: TextAlign.right,
    )..layout(maxWidth: maxRightWidth);
    final leftMaxWidth = (_width - (_padding * 2)) - amount.width - 18;
    final left = _painter(
      '${item.qtyText} ${item.name}',
      fontSize: 20,
      weight: FontWeight.w500,
      maxLines: 2,
    )..layout(maxWidth: leftMaxWidth.clamp(72, _width).toDouble());

    left.paint(canvas, Offset(_padding, y));
    amount.paint(canvas, Offset(_width - _padding - amount.width, y));

    return y +
        (left.height > amount.height ? left.height : amount.height) +
        8;
  }

  static double _kotItemRow(Canvas canvas, KotLineItem item, double y) {
    final left = '${item.qtyText} x ${item.name}';
    final modifiers = item.modifiers.trim();
    if (modifiers.isEmpty) {
      return _text(canvas, left, y, fontSize: 25, weight: FontWeight.w700);
    }
    return _row(
      canvas,
      left,
      modifiers,
      y,
      fontSize: 25,
      weight: FontWeight.w700,
    );
  }

  static TextPainter _painter(
    String value, {
    required double fontSize,
    required FontWeight weight,
    TextAlign align = TextAlign.left,
    int? maxLines,
  }) {
    return TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: Colors.black,
          fontFamily: _fontFamily(value),
          fontSize: fontSize,
          fontWeight: weight,
          height: 1.18,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: maxLines == null ? null : '...',
    );
  }

  static String _fontFamily(String value) {
    return RegExp(r'[\u0980-\u09FF]').hasMatch(value)
        ? tfBanglaFontFamily
        : tfEnglishFontFamily;
  }
}
