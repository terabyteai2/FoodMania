// QuickBytes Desktop — faithful line-icon set ported from the design source of
// truth (`taget_app/desktop_design/bytes-shared.jsx` PATHS). The jsx renders
// 20×20 stroke icons; we reproduce them exactly by parsing the same SVG path
// strings through a tiny path parser (no flutter_svg dependency).

import 'package:flutter/material.dart';

/// 20×20 SVG path data, copied verbatim from `bytes-shared.jsx`.
const Map<String, String> kDkIconPaths = {
  'search': 'M11 11l4 4 M7.5 13a5.5 5.5 0 100-11 5.5 5.5 0 000 11z',
  'plus': 'M10 4v12 M4 10h12',
  'minus': 'M4 10h12',
  'back': 'M12 4l-6 6 6 6',
  'fwd': 'M8 4l6 6-6 6',
  'chev': 'M7 4l6 6-6 6',
  'chevd': 'M5 8l5 5 5-5',
  'chevu': 'M5 12l5-5 5 5',
  'check': 'M4 10.5l4 4 8-9',
  'x': 'M5 5l10 10 M15 5L5 15',
  'receipt': 'M5 2.5h10v15l-2.2-1.4L10.5 17 8 16.1 5.5 17 5 2.5z M8 6.5h4 M8 9.5h4',
  'bag': 'M6 6V5a4 4 0 018 0v1 M4 6h12l-.8 11H4.8L4 6z',
  'grid': 'M3 3h6v6H3z M11 3h6v6h-6z M3 11h6v6H3z M11 11h6v6h-6z',
  'table': 'M3 7h14 M5 7v3a2 2 0 002 2h6a2 2 0 002-2V7 M7 12v4 M13 12v4',
  'box': 'M10 2.5l7 3.8v7.4l-7 3.8-7-3.8V6.3l7-3.8z M3.2 6.3L10 10l6.8-3.7 M10 10v7.5',
  'boxin': 'M10 2v7 M7 6.5l3 3 3-3 M3.5 11.5v4a1 1 0 001 1h11a1 1 0 001-1v-4',
  'chart': 'M3 17h14 M6 17V9 M10 17V4 M14 17v-6',
  'tower':
      'M10 9.5a2 2 0 100-4 2 2 0 000 4z M5.5 3a6.4 6.4 0 000 9 M14.5 3a6.4 6.4 0 010 9 M3 1.2a9 9 0 000 12.6 M17 1.2a9 9 0 010 12.6 M10 9.5l-2 8 M10 9.5l2 8 M8 15h4',
  'settings':
      'M10 7.2a2.8 2.8 0 100 5.6 2.8 2.8 0 000-5.6z M10 1.8l1.2 2 2.3-.4.6 2.3 2 1.2-1 2.1 1 2.1-2 1.2-.6 2.3-2.3-.4L10 18.2l-1.2-2-2.3.4-.6-2.3-2-1.2 1-2.1-1-2.1 2-1.2.6-2.3 2.3.4L10 1.8z',
  'bolt': 'M11 2L4 11h5l-1 7 7-9h-5l1-7z',
  'clock': 'M10 5.5v4.5l3 2 M10 2.5a7.5 7.5 0 100 15 7.5 7.5 0 000-15z',
  'user': 'M10 10a3 3 0 100-6 3 3 0 000 6z M4.5 17a5.5 5.5 0 0111 0',
  'users':
      'M7.5 9a2.6 2.6 0 100-5.2 2.6 2.6 0 000 5.2z M2.8 16a4.7 4.7 0 019.4 0 M13 4a2.6 2.6 0 010 5 M14.2 16a4.7 4.7 0 00-2.2-3.9',
  'trash': 'M4 6h12 M8 6V4.5h4V6 M5.5 6l.7 10h7.6l.7-10 M8.5 9v4 M11.5 9v4',
  'edit': 'M12.5 3.5l4 4-9 9H3.5v-4l9-9z M11 5l4 4',
  'printer':
      'M6 8V3h8v5 M6 14H4.5A1.5 1.5 0 013 12.5V9.5A1.5 1.5 0 014.5 8h11A1.5 1.5 0 0117 9.5v3a1.5 1.5 0 01-1.5 1.5H14 M6 12h8v5H6v-5z',
  'camera':
      'M3 6.5h2.5L7 4.5h6l1.5 2H17a1 1 0 011 1v8a1 1 0 01-1 1H3a1 1 0 01-1-1v-8a1 1 0 011-1z M10 13.5a3 3 0 100-6 3 3 0 000 6z',
  'sparkle':
      'M10 2.5l1.6 4.3L16 8.4l-4.4 1.6L10 14.3 8.4 10 4 8.4l4.4-1.6L10 2.5z M15.5 13l.7 1.8 1.8.7-1.8.7-.7 1.8-.7-1.8-1.8-.7 1.8-.7.7-1.8z',
  'scan': 'M3 7V5a2 2 0 012-2h2 M13 3h2a2 2 0 012 2v2 M17 13v2a2 2 0 01-2 2h-2 M7 17H5a2 2 0 01-2-2v-2 M3 10h14',
  'qr': 'M3 3h5v5H3z M12 3h5v5h-5z M3 12h5v5H3z M5 5h1v1H5z M14 5h1v1h-1z M5 14h1v1H5z M12 12h2v2h-2z M16 12v5 M12 16h2',
  'globe':
      'M10 2.5a7.5 7.5 0 100 15 7.5 7.5 0 000-15z M2.5 10h15 M10 2.5c2.2 2 3.3 4.8 3.3 7.5S12.2 15.5 10 17.5 6.7 12.7 6.7 10 7.8 4.5 10 2.5z',
  'chat': 'M3 5.5A1.5 1.5 0 014.5 4h11A1.5 1.5 0 0117 5.5v6a1.5 1.5 0 01-1.5 1.5H8l-4 3v-3H4.5A1.5 1.5 0 013 11.5v-6z',
  'store':
      'M3.5 8.5V16h13V8.5 M2.5 8.5L4 4h12l1.5 4.5a2 2 0 01-3.75 1 2 2 0 01-3.75 0 2 2 0 01-3.75 0 2 2 0 01-3.75-1z',
  'bell': 'M10 3a4.5 4.5 0 014.5 4.5c0 4 1.5 5 1.5 5H4s1.5-1 1.5-5A4.5 4.5 0 0110 3z M8.5 16a1.5 1.5 0 003 0',
  'truck':
      'M2.5 5h9v8h-9z M11.5 8h3l2.5 2.5V13h-5.5 M5.5 16a1.6 1.6 0 100-3.2 1.6 1.6 0 000 3.2z M14 16a1.6 1.6 0 100-3.2 1.6 1.6 0 000 3.2z',
  'card': 'M3 6h14v8H3z M3 9h14',
  'cash': 'M2.5 5h15v9h-15z M10 12a2.5 2.5 0 100-5 2.5 2.5 0 000 5z',
  'tag': 'M3.2 3.2h6l7.6 7.6-6 6L3.2 9.2v-6z M6.5 6.5h.01',
  'note': 'M4 3h9l3 3v11H4V3z M7 8h6 M7 11h6 M7 14h3',
  'dots': 'M5 10h.01 M10 10h.01 M15 10h.01',
  'dotsv': 'M10 5h.01 M10 10h.01 M10 15h.01',
  'wifi': 'M2 6.5a11 11 0 0116 0 M5 9.5a7 7 0 0110 0 M8 12.5a3 3 0 014 0 M10 15.3h.01',
  'arrowr': 'M4 10h12 M11 5l5 5-5 5',
  'arrowu': 'M10 16V4 M5 9l5-5 5 5',
  'arrowd': 'M10 4v12 M5 11l5 5 5-5',
  'trendup': 'M3 14l4.5-5 3 3L17 6 M13 6h4v4',
  'trenddn': 'M3 6l4.5 5 3-3L17 14 M13 14h4v-4',
  'filter': 'M3 5h14 M5.5 10h9 M8 15h4',
  'sort': 'M5 7l3-3 3 3 M8 4v12 M15 13l-3 3-3-3 M12 16V4',
  'list': 'M6 5h11 M6 10h11 M6 15h11 M3 5h.01 M3 10h.01 M3 15h.01',
  'count': 'M4 5l1.5 1.5L8 4 M4 10l1.5 1.5L8 9 M4 15l1.5 1.5L8 14 M11 5h6 M11 10h6 M11 15h6',
  'check2': 'M5 10l3.5 3.5L16 6',
  'warn': 'M10 3l8 14H2L10 3z M10 8v4 M10 15h.01',
  'pin': 'M10 2.5c3.3 0 5.5 2.4 5.5 5.4 0 3.7-5.5 9.6-5.5 9.6S4.5 11.6 4.5 7.9C4.5 4.9 6.7 2.5 10 2.5z M10 10a2 2 0 100-4 2 2 0 000 4z',
  'phone':
      'M5 3h3l1.5 4-2 1.5a9 9 0 004 4l1.5-2 4 1.5v3a1.5 1.5 0 01-1.6 1.5C8 19.5 1 12.5.5 5.1A1.5 1.5 0 012 3.5',
  'star': 'M10 2.5l2.2 4.6 5 .7-3.6 3.5.9 5L10 13.9 5.5 16.3l.9-5L2.8 7.8l5-.7L10 2.5z',
  'flame':
      'M10 17c3.3 0 5.5-2.4 5.5-5.4 0-2-1-3.6-2.2-5C12 5 11.4 3.4 11.4 2c-1.6 1-2.4 2.6-2.4 4.2 0 .8.2 1.5.5 2.2-1.6-.4-2.4-1.8-2.4-1.8-.7 1-1.6 2.6-1.6 4.6C5.5 14.4 6.7 17 10 17z',
  'history': 'M10.5 5.5v4.5l3 1.8 M3.5 10a6.5 6.5 0 112.2 4.9 M3.5 10H6 M3.5 10V7.5',
  'download': 'M10 3v9 M6 8.5l4 4 4-4 M4 16h12',
  'refresh': 'M16 5v4h-4 M15.5 9a6 6 0 10-1.5 5.5',
  'open': 'M5 5h6 M5 5v6 M5 5l9 9 M14 9v5h-5',
  'taka': 'M5 7.5h4 M9 5v8c0 1.5 1 2.5 2.5 2.5 M5 11h7',
  'bot':
      'M6 7.5h8a1.5 1.5 0 011.5 1.5v4a1.5 1.5 0 01-1.5 1.5H6a1.5 1.5 0 01-1.5-1.5V9A1.5 1.5 0 016 7.5z M10 4.5v3 M10 3.6a.9.9 0 100-.01 M8 10.5h.01 M12 10.5h.01 M2.5 10v2.5 M17.5 10v2.5 M8.5 13.5h3',
  'send': 'M3.5 10L17 3.5 11 17l-2.2-5.3L3.5 10z',
  'image': 'M3.5 4h13v12h-13z M3.5 13l4-4 3 3 3-3.5 3 3.5 M7 8a1 1 0 100-2 1 1 0 000 2z',
  'reply': 'M8 5L3 10l5 5 M3 10h8a5 5 0 015 5v1',
  'burger': 'M4 12h12 M4 9.5h12 M5 7c0-1.8 2.2-3 5-3s5 1.2 5 3 M4.5 12c0 2 1.5 3.5 3 3.5h5c1.5 0 3-1.5 3-3.5',
  'pizza': 'M10 3.5L3 16l7-1.5L17 16 10 3.5z M9 9.5h.01 M11.5 11.5h.01',
  'fries': 'M6 8l-.5-3.5 1.8-.3L8 8 M9.2 8l.3-4 1.9.1-.3 3.9 M12.5 8l1-3.3 1.8.5-1 2.8 M5 8h10l-1 8H6l-1-8z',
  'drink': 'M6 5h8l-1 12H7L6 5z M5.5 8h9 M10 2.5V5',
  'rice':
      'M3.5 11h13c0 3.3-2.9 5.5-6.5 5.5S3.5 14.3 3.5 11z M6 11c0-2 1.8-3.5 4-3.5s4 1.5 4 3.5 M8 5.5c0-1 .9-1.8 2-1.8s2 .8 2 1.8',
  'kebab': 'M10 2.5v15 M7 6a3 3 0 016 0 6 6 0 01-6 0z M7 11a3 3 0 016 0 6 6 0 01-6 0z',
  'salad': 'M4 9h12c0 3.5-2.7 6.5-6 6.5S4 12.5 4 9z M8 6.5c0-1 1-2 2-2s2 1 2 2 M6.5 8.5c-.5-1 0-2.5 1-3',
  'dessert': 'M5 8a5 5 0 0110 0z M5 8h10 M6.5 8l1 8h5l1-8 M10 4.5V2.5',
  'language': 'M3 5h7 M6.5 3.5V5 M5 5c0 3-1.2 5.5-3 6.5 M4.5 8.5c1 1.6 2.6 2.5 4 3 M11 16.5l3-7 3 7 M12 14h4',
  'percent': 'M6 6a1 1 0 100-.01 M14 14a1 1 0 100-.01 M5 15L15 5',
};

/// A stroke icon faithful to the jsx `<Icon>` (20×20 viewBox, round caps/joins).
class DkIcon extends StatelessWidget {
  const DkIcon(
    this.name, {
    this.size = 19,
    this.color,
    this.strokeWidth = 1.8,
    this.fill = false,
    super.key,
  });

  final String name;
  final double size;
  final Color? color;
  final double strokeWidth;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final c = color ?? DefaultTextStyle.of(context).style.color ?? const Color(0xFF14180E);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DkIconPainter(
          path: kDkIconPaths[name] ?? '',
          color: c,
          strokeWidth: strokeWidth,
          fill: fill,
        ),
      ),
    );
  }
}

class _DkIconPainter extends CustomPainter {
  _DkIconPainter({
    required this.path,
    required this.color,
    required this.strokeWidth,
    required this.fill,
  });

  final String path;
  final Color color;
  final double strokeWidth;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 20.0;
    canvas.save();
    canvas.scale(scale);
    final p = parseSvgPath(path);
    if (fill) {
      canvas.drawPath(p, Paint()..color = color..style = PaintingStyle.fill);
    } else {
      canvas.drawPath(
        p,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DkIconPainter old) =>
      old.path != path || old.color != color || old.strokeWidth != strokeWidth || old.fill != fill;
}

/// The QuickBytes brand mark: lime rounded square + ink lightning bolt
/// (`bytes-shared.jsx` `Mark`, 100×100 viewBox).
class DkMark extends StatelessWidget {
  const DkMark({this.size = 40, super.key});

  final double size;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size, height: size, child: CustomPaint(painter: _DkMarkPainter()));
}

class _DkMarkPainter extends CustomPainter {
  static const double _vb = 100;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _vb;
    canvas.save();
    canvas.scale(scale);
    final r = _vb * 0.26;
    final rect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(4, 4, 92, 92),
      Radius.circular(r / _vb * 100),
    );
    canvas.drawRRect(rect, Paint()..color = const Color(0xFF99FF47));
    final bolt = parseSvgPath('M56 21 L31 56 H46 L42 79 L69 42 H53 L58 21 Z');
    canvas.drawPath(bolt, Paint()..color = const Color(0xFF14180E));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DkMarkPainter old) => false;
}

// ---------------------------------------------------------------------------
// Minimal SVG path parser → Flutter Path. Supports the command subset used by
// the icon set: M/m L/l H/h V/v C/c S/s Q/q T/t A/a Z/z. Arc flags are read as
// single characters per the SVG grammar (so "100-11" → large=1 sweep=0 x=0…).
// ---------------------------------------------------------------------------
Path parseSvgPath(String data) {
  final path = Path();
  final tok = _PathTokens(data);
  double cx = 0, cy = 0, sx = 0, sy = 0;
  double lastC1x = 0, lastC1y = 0; // reflection point for S/T (last control)
  String prevCmd = '';

  while (tok.hasMore) {
    final cmd = tok.readCommand() ?? prevCmd;
    final rel = cmd == cmd.toLowerCase() && cmd != cmd.toUpperCase();
    switch (cmd.toUpperCase()) {
      case 'M':
        cx = (rel ? cx : 0) + tok.num();
        cy = (rel ? cy : 0) + tok.num();
        path.moveTo(cx, cy);
        sx = cx;
        sy = cy;
        // Subsequent coordinate pairs are implicit lineto.
        while (tok.peekIsNumber) {
          cx = (rel ? cx : 0) + tok.num();
          cy = (rel ? cy : 0) + tok.num();
          path.lineTo(cx, cy);
        }
        break;
      case 'L':
        while (tok.peekIsNumber) {
          cx = (rel ? cx : 0) + tok.num();
          cy = (rel ? cy : 0) + tok.num();
          path.lineTo(cx, cy);
        }
        break;
      case 'H':
        while (tok.peekIsNumber) {
          cx = (rel ? cx : 0) + tok.num();
          path.lineTo(cx, cy);
        }
        break;
      case 'V':
        while (tok.peekIsNumber) {
          cy = (rel ? cy : 0) + tok.num();
          path.lineTo(cx, cy);
        }
        break;
      case 'C':
        while (tok.peekIsNumber) {
          final x1 = (rel ? cx : 0) + tok.num();
          final y1 = (rel ? cy : 0) + tok.num();
          final x2 = (rel ? cx : 0) + tok.num();
          final y2 = (rel ? cy : 0) + tok.num();
          cx = (rel ? cx : 0) + tok.num();
          cy = (rel ? cy : 0) + tok.num();
          path.cubicTo(x1, y1, x2, y2, cx, cy);
          lastC1x = x2;
          lastC1y = y2;
        }
        break;
      case 'S':
        while (tok.peekIsNumber) {
          final reflectX = (prevCmd.toUpperCase() == 'C' || prevCmd.toUpperCase() == 'S') ? 2 * cx - lastC1x : cx;
          final reflectY = (prevCmd.toUpperCase() == 'C' || prevCmd.toUpperCase() == 'S') ? 2 * cy - lastC1y : cy;
          final x2 = (rel ? cx : 0) + tok.num();
          final y2 = (rel ? cy : 0) + tok.num();
          cx = (rel ? cx : 0) + tok.num();
          cy = (rel ? cy : 0) + tok.num();
          path.cubicTo(reflectX, reflectY, x2, y2, cx, cy);
          lastC1x = x2;
          lastC1y = y2;
        }
        break;
      case 'Q':
        while (tok.peekIsNumber) {
          final x1 = (rel ? cx : 0) + tok.num();
          final y1 = (rel ? cy : 0) + tok.num();
          cx = (rel ? cx : 0) + tok.num();
          cy = (rel ? cy : 0) + tok.num();
          path.quadraticBezierTo(x1, y1, cx, cy);
          lastC1x = x1;
          lastC1y = y1;
        }
        break;
      case 'T':
        while (tok.peekIsNumber) {
          final reflectX = (prevCmd.toUpperCase() == 'Q' || prevCmd.toUpperCase() == 'T') ? 2 * cx - lastC1x : cx;
          final reflectY = (prevCmd.toUpperCase() == 'Q' || prevCmd.toUpperCase() == 'T') ? 2 * cy - lastC1y : cy;
          cx = (rel ? cx : 0) + tok.num();
          cy = (rel ? cy : 0) + tok.num();
          path.quadraticBezierTo(reflectX, reflectY, cx, cy);
          lastC1x = reflectX;
          lastC1y = reflectY;
        }
        break;
      case 'A':
        while (tok.peekIsNumber) {
          final rx = tok.num();
          final ry = tok.num();
          final rot = tok.num();
          final large = tok.flag();
          final sweep = tok.flag();
          cx = (rel ? cx : 0) + tok.num();
          cy = (rel ? cy : 0) + tok.num();
          path.arcToPoint(
            Offset(cx, cy),
            radius: Radius.elliptical(rx, ry),
            rotation: rot,
            largeArc: large,
            clockwise: sweep,
          );
        }
        break;
      case 'Z':
        path.close();
        cx = sx;
        cy = sy;
        break;
    }
    prevCmd = cmd;
  }
  return path;
}

class _PathTokens {
  _PathTokens(this._s);
  final String _s;
  int _i = 0;

  static const _ws = {0x20, 0x09, 0x0A, 0x0D, 0x2C}; // space tab nl cr comma

  void _skipWs() {
    while (_i < _s.length && _ws.contains(_s.codeUnitAt(_i))) {
      _i++;
    }
  }

  bool get hasMore {
    _skipWs();
    return _i < _s.length;
  }

  bool _isAlpha(int c) => (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);

  /// Reads a command letter if the next non-ws char is alphabetic; else null
  /// (an implicit repeat of the previous command).
  String? readCommand() {
    _skipWs();
    if (_i < _s.length && _isAlpha(_s.codeUnitAt(_i))) {
      return _s[_i++];
    }
    return null;
  }

  bool get peekIsNumber {
    _skipWs();
    if (_i >= _s.length) return false;
    final c = _s.codeUnitAt(_i);
    return (c >= 0x30 && c <= 0x39) || c == 0x2E || c == 0x2D || c == 0x2B; // 0-9 . - +
  }

  double num() {
    _skipWs();
    final start = _i;
    if (_i < _s.length && (_s.codeUnitAt(_i) == 0x2D || _s.codeUnitAt(_i) == 0x2B)) _i++;
    var seenDot = false;
    while (_i < _s.length) {
      final c = _s.codeUnitAt(_i);
      if (c >= 0x30 && c <= 0x39) {
        _i++;
      } else if (c == 0x2E && !seenDot) {
        seenDot = true;
        _i++;
      } else {
        break;
      }
    }
    return double.parse(_s.substring(start, _i));
  }

  /// Arc flag: a single '0' or '1' character.
  bool flag() {
    _skipWs();
    final c = _s[_i];
    _i++;
    return c == '1';
  }
}
