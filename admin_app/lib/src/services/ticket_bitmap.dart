import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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

class TicketCopyData {
  const TicketCopyData({
    required this.restaurantName,
    required this.outletName,
    required this.orderNumberDisplay,
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
    this.deliveryAddress,
    this.deliveryAddressLabel = 'Address',
    this.mobileNumber,
    this.mobileNumberLabel = 'Phone',
  });

  final String restaurantName;
  final String? outletName;
  final String orderNumberDisplay;
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
  final String? deliveryAddress;
  final String deliveryAddressLabel;
  final String? mobileNumber;
  final String mobileNumberLabel;
}

class TicketBitmapRenderer {
  TicketBitmapRenderer._();

  // Deli ES421-class 58mm printers expose 384 printable dots. Wider bitmaps
  // are clipped on the right, exactly where amounts and restaurant names sit.
  static const double _width = 384;
  static const double _padding = 16;

  static int get debugPrintableWidth => _width.toInt();

  static Future<Uint8List> render(TicketCopyData data) async {
    final dynamicRows = data.items.length * 76;
    final optionalRows =
        (data.customerName?.trim().isNotEmpty == true ? 32 : 0) +
        (data.deliveryAddress?.trim().isNotEmpty == true ? 64 : 0) +
        (data.mobileNumber?.trim().isNotEmpty == true ? 32 : 0) +
        (data.note?.trim().isNotEmpty == true ? 80 : 0);
    final height = (300 + dynamicRows + optionalRows).toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _width, height),
      Paint()..color = Colors.white,
    );

    var y = 0.0;
    y = _headerRow(canvas, data.orderNumberDisplay, data.restaurantName, y);
    y = _text(canvas, data.copyLabel, y, fontSize: 22, weight: FontWeight.w500);
    y = _text(canvas, data.dateLine, y, fontSize: 18);
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
    y = _rule(canvas, y + 4);

    for (final item in data.items) {
      y = _itemRow(canvas, item, y);
    }

    y = _rule(canvas, y + 4);
    y = _row(
      canvas,
      '${data.totalLabel} -',
      data.totalAmount,
      y,
      fontSize: 25,
      weight: FontWeight.w500,
    );
    if (data.note?.trim().isNotEmpty == true) {
      y = _text(
        canvas,
        '${data.noteLabel}: ${data.note!.trim()}',
        y + 6,
        fontSize: 21,
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

  static double _headerRow(
    Canvas canvas,
    String orderNumber,
    String restaurantName,
    double y,
  ) {
    final rightWidth = (_width - (_padding * 2)) * 0.58;
    final leftWidth = (_width - (_padding * 2)) - rightWidth - 10;
    final left = _painter(orderNumber, fontSize: 28, weight: FontWeight.w500)
      ..layout(maxWidth: leftWidth);
    final right = _painter(
      restaurantName,
      fontSize: 24,
      weight: FontWeight.w500,
      align: TextAlign.right,
      maxLines: 1,
    )..layout(maxWidth: rightWidth);
    left.paint(canvas, Offset(_padding, y));
    right.paint(canvas, Offset(_width - _padding - right.width, y + 2));
    return y + (left.height > right.height ? left.height : right.height) + 4;
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
    painter.paint(canvas, Offset(_padding, y));
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
    const amountWidth = 96.0;
    const qtyWidth = 42.0;
    const hyphenWidth = 10.0;
    const gap = 5.0;
    final nameWidth =
        totalWidth - amountWidth - qtyWidth - (hyphenWidth * 2) - (gap * 4);
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
    final dash = _painter('-', fontSize: 20, weight: FontWeight.w500)
      ..layout(maxWidth: hyphenWidth);

    name.paint(canvas, Offset(_padding, y));
    final dashOneX = _padding + nameWidth + gap;
    dash.paint(canvas, Offset(dashOneX, y));
    final qtyX = dashOneX + hyphenWidth + gap;
    qty.paint(canvas, Offset(qtyX, y));
    final dashTwoX = qtyX + qtyWidth + gap;
    dash.paint(canvas, Offset(dashTwoX, y));
    amount.paint(canvas, Offset(_width - _padding - amount.width, y));
    final rowHeight = [
      name.height,
      qty.height,
      amount.height,
    ].reduce((a, b) => a > b ? a : b);
    return y + rowHeight + 8;
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
