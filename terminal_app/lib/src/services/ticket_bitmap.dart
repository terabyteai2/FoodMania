import 'dart:typed_data';
import 'dart:ui' as ui;

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
    required this.copyLabel,
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
  });

  final String restaurantName;
  final String? outletName;
  final String? restaurantSubtitle;
  final String orderNumberDisplay;
  final String orderTypeLabel;
  final String copyLabel;
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
  const UtilityTicketSection({
    required this.title,
    required this.lines,
  });

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
    final footerRows = data.serverName?.trim().isNotEmpty == true ? 46 : 0;
    final hasTable =
        data.tableLabel?.trim().isNotEmpty == true &&
        data.tableValue?.trim().isNotEmpty == true;
    final height =
        (300 +
                dynamicRows +
                noteRows +
                footerRows +
                (hasTable ? 30 : 0))
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
    y = _text(canvas, data.itemsLabel, y, fontSize: 28, weight: FontWeight.w700);
    for (final item in data.items) {
      y = _kotItemRow(canvas, item, y);
    }

    final notedItems = [
      for (final item in data.items)
        if (item.note?.trim().isNotEmpty == true) item,
    ];
    if (notedItems.isNotEmpty) {
      y = _rule(canvas, y + 8);
      y = _text(canvas, data.noteLabel, y, fontSize: 28, weight: FontWeight.w700);
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

    final server = data.serverName?.trim();
    if (server != null && server.isNotEmpty) {
      y = _text(
        canvas,
        '${data.serverLabel}: $server',
        y + 16,
        fontSize: 26,
        weight: FontWeight.w700,
        align: TextAlign.right,
      );
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
    final dynamicRows = data.items.length * 58;
    final optionalRows =
        (data.restaurantSubtitle?.trim().isNotEmpty == true ? 82 : 0) +
        (data.customerName?.trim().isNotEmpty == true ? 32 : 0) +
        (data.deliveryAddress?.trim().isNotEmpty == true ? 64 : 0) +
        (data.mobileNumber?.trim().isNotEmpty == true ? 32 : 0) +
        (data.note?.trim().isNotEmpty == true ? 80 : 0);
    final summaryRows = data.summaryRows.length * 34;
    final paymentRows = data.paymentLine?.trim().isNotEmpty == true ? 42 : 0;
    final qrRows = data.orderDetailsUrl?.trim().isNotEmpty == true ? 168 : 0;
    final footerRows = data.footerText?.trim().isNotEmpty == true ? 38 : 0;
    final height =
        (430 + dynamicRows + optionalRows + summaryRows + paymentRows + qrRows + footerRows)
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
      data.orderNumberDisplay,
      y + 8,
      fontSize: 82,
      weight: FontWeight.w700,
      align: TextAlign.center,
    );
    y = _serviceBox(canvas, data.orderTypeLabel.toUpperCase(), y + 4);
    y = _text(
      canvas,
      data.dateLine,
      y + 8,
      fontSize: 20,
      align: TextAlign.center,
    );
    y = _ornament(canvas, y + 8);
    y = _text(
      canvas,
      data.restaurantName,
      y + 6,
      fontSize: 44,
      weight: FontWeight.w700,
      align: TextAlign.center,
    );
    final restaurantSubtitle = data.restaurantSubtitle?.trim();
    if (restaurantSubtitle != null && restaurantSubtitle.isNotEmpty) {
      y = _text(
        canvas,
        restaurantSubtitle,
        y,
        fontSize: 19,
        align: TextAlign.center,
      );
    }
    if (data.tableLine.trim().isNotEmpty) {
      y = _text(
        canvas,
        data.tableLine,
        y,
        fontSize: 18,
        align: TextAlign.center,
      );
    }
    if (data.customerName?.trim().isNotEmpty == true) {
      y = _text(
        canvas,
        '${data.customerNameLabel}: ${data.customerName!.trim()}',
        y,
      );
    }
    if (data.deliveryAddress?.trim().isNotEmpty == true) {
      y = _text(
        canvas,
        '${data.deliveryAddressLabel}: ${data.deliveryAddress!.trim()}',
        y,
      );
    }
    if (data.mobileNumber?.trim().isNotEmpty == true) {
      y = _text(
        canvas,
        '${data.mobileNumberLabel}: ${data.mobileNumber!.trim()}',
        y,
      );
    }
    y = _ornament(canvas, y + 8);

    for (final item in data.items) {
      y = _itemRow(canvas, item, y);
    }

    y = _rule(canvas, y + 8);
    if (data.summaryRows.isEmpty) {
      y = _row(
        canvas,
        data.totalLabel,
        data.totalAmount,
        y,
        fontSize: 27,
        weight: FontWeight.w700,
      );
    } else {
      for (final row in data.summaryRows) {
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
    if (data.paymentLine?.trim().isNotEmpty == true) {
      y = _rule(canvas, y + 8);
      y = _text(
        canvas,
        data.paymentLine!.trim(),
        y,
        fontSize: 24,
        weight: FontWeight.w700,
        align: TextAlign.center,
      );
    }
    if (data.note?.trim().isNotEmpty == true) {
      y = _text(
        canvas,
        '${data.noteLabel}: ${data.note!.trim()}',
        y + 6,
        fontSize: 21,
      );
    }
    final qrUrl = data.orderDetailsUrl?.trim();
    if (qrUrl != null && qrUrl.isNotEmpty) {
      y = _ornament(canvas, y + 8);
      y = _drawQrCentered(canvas, qrUrl, y + 4);
      y = _text(
        canvas,
        data.qrCaption?.trim().isNotEmpty == true
            ? data.qrCaption!.trim()
            : 'SCAN FOR LIVE ORDER DETAILS',
        y + 6,
        fontSize: 17,
        weight: FontWeight.w700,
        align: TextAlign.center,
      );
    }
    if (data.footerText?.trim().isNotEmpty == true) {
      y = _text(
        canvas,
        data.footerText!.trim(),
        y + 8,
        fontSize: 20,
        weight: FontWeight.w600,
        align: TextAlign.center,
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(_width.toInt(), y.ceil());
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) {
      throw StateError('Ticket bitmap encoding failed.');
    }
    return png.buffer.asUint8List();
  }

  static Future<Uint8List> renderUtility(UtilityTicketData data) async {
    final sectionLines = data.sections.fold<int>(
      0,
      (total, section) => total + section.lines.length + 1,
    );
    final height =
        (260 + data.headerRows.length * 34 + sectionLines * 34 + data.totalRows.length * 38 + data.footerLines.length * 34)
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

  static double _serviceBox(Canvas canvas, String value, double y) {
    final painter = _painter(
      value,
      fontSize: 20,
      weight: FontWeight.w700,
      align: TextAlign.center,
      maxLines: 1,
    )..layout(maxWidth: _width - (_padding * 2) - 40);
    final width = painter.width + 34;
    final height = painter.height + 14;
    final rect = Rect.fromLTWH((_width - width) / 2, y, width, height);
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    painter.paint(canvas, Offset((_width - painter.width) / 2, y + 7));
    return y + height + 6;
  }

  static double _ornament(Canvas canvas, double y) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.4;
    final center = _width / 2;
    canvas.drawLine(Offset(_padding, y + 8), Offset(center - 28, y + 8), paint);
    canvas.drawLine(
      Offset(center + 28, y + 8),
      Offset(_width - _padding, y + 8),
      paint,
    );
    final star = _painter('✦', fontSize: 18, weight: FontWeight.w500)
      ..layout(maxWidth: 24);
    star.paint(canvas, Offset(center - (star.width / 2), y));
    return y + 24;
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
      return y + qrSizePx + 4;
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
    final totalWidth = _width - (_padding * 2);
    const amountWidth = 98.0;
    const qtyWidth = 42.0;
    const gap = 8.0;
    final nameWidth = totalWidth - amountWidth - qtyWidth - (gap * 2);
    final name = _painter(
      '${item.index}. ${item.name}',
      fontSize: 20,
      weight: FontWeight.w500,
      maxLines: 2,
    )..layout(maxWidth: nameWidth);
    final qty = _painter(
      item.qtyText,
      fontSize: 20,
      weight: FontWeight.w500,
      align: TextAlign.center,
      maxLines: 1,
    )..layout(maxWidth: qtyWidth);
    final amount = _painter(
      item.lineTotalText,
      fontSize: 20,
      weight: FontWeight.w500,
      align: TextAlign.right,
      maxLines: 1,
    )..layout(maxWidth: amountWidth);

    name.paint(canvas, Offset(_padding, y));
    final qtyX = _padding + nameWidth + gap;
    qty.paint(canvas, Offset(qtyX, y));
    amount.paint(canvas, Offset(_width - _padding - amount.width, y));
    final rowHeight = [
      name.height,
      qty.height,
      amount.height,
    ].reduce((a, b) => a > b ? a : b);
    return y + rowHeight + 8;
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
