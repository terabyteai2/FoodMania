import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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
    required this.isManagerCopy,
    required this.footerLine,
    required this.customerName,
    required this.customerNameLabel,
    required this.note,
    required this.noteLabel,
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
  final bool isManagerCopy;
  final String footerLine;
  final String? customerName;
  final String customerNameLabel;
  final String? note;
  final String noteLabel;
}

class TicketBitmapRenderer {
  TicketBitmapRenderer._();

  static const double _width = 576;
  static const double _padding = 28;

  static Future<Uint8List> render(TicketCopyData data) async {
    final dynamicRows = data.items.length * 68;
    final optionalRows =
        (data.customerName?.trim().isNotEmpty == true ? 42 : 0) +
        (data.note?.trim().isNotEmpty == true ? 84 : 0);
    final height = (560 + dynamicRows + optionalRows).toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _width, height),
      Paint()..color = Colors.white,
    );

    var y = 26.0;
    y = _text(
      canvas,
      data.restaurantName,
      y,
      fontSize: 34,
      weight: FontWeight.w800,
      align: TextAlign.center,
    );
    if (data.outletName?.trim().isNotEmpty == true) {
      y = _text(canvas, data.outletName!.trim(), y, align: TextAlign.center);
    }
    y += 8;
    y = _rule(canvas, y);
    y = _text(
      canvas,
      data.orderNumberDisplay,
      y,
      fontSize: 31,
      weight: FontWeight.w800,
    );
    y = _text(canvas, data.copyLabel, y, weight: FontWeight.w700);
    y = _text(canvas, data.dateLine, y);
    y = _text(canvas, '${data.tableLine}  |  ${data.sourceLine}', y);
    if (data.customerName?.trim().isNotEmpty == true) {
      y = _text(
        canvas,
        '${data.customerNameLabel}: ${data.customerName!.trim()}',
        y,
      );
    }
    y = _rule(canvas, y + 5);

    for (final item in data.items) {
      y = _text(
        canvas,
        '${item.index}. ${item.name}',
        y,
        weight: FontWeight.w600,
      );
      y = _text(
        canvas,
        '${item.qtyText}                         ${item.lineTotalText}',
        y,
      );
    }

    y = _rule(canvas, y + 5);
    y = _text(
      canvas,
      '${data.totalLabel}                         ${data.totalAmount}',
      y,
      fontSize: 30,
      weight: FontWeight.w800,
    );
    if (data.note?.trim().isNotEmpty == true) {
      y = _text(canvas, '${data.noteLabel}: ${data.note!.trim()}', y + 8);
    }
    y = _text(
      canvas,
      data.footerLine,
      y + 14,
      weight: FontWeight.w700,
      align: TextAlign.center,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(_width.toInt(), y.ceil() + 32);
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
        ..strokeWidth = 2,
    );
    return y + 18;
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
}
