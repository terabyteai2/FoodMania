import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/core/widgets/tf_design_system.dart';

void main() {
  testWidgets('TfText gives Bangla digits safe font metrics', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('bn'),
        supportedLocales: [Locale('en'), Locale('bn')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: TfText(
            '1',
            style: TextStyle(fontSize: 38, height: 1, letterSpacing: -1.1),
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('১'));
    expect(text.style?.fontFamily, tfBanglaFontFamily);
    expect(text.style?.height, greaterThanOrEqualTo(tfBanglaMinLineHeight));
    expect(text.style?.letterSpacing, 0);
    expect(text.strutStyle?.fontFamily, tfBanglaFontFamily);
    expect(
      text.strutStyle?.height,
      greaterThanOrEqualTo(tfBanglaMinLineHeight),
    );
    expect(text.textHeightBehavior?.applyHeightToLastDescent, isTrue);
  });
}
