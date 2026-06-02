import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/core/theme/app_theme.dart';
import 'package:local_pos/src/features/settings/qr_pdf_screen.dart';
import 'package:local_pos/src/models/server_config.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  testWidgets('zero-table QR page keeps the restaurant menu QR first', (
    tester,
  ) async {
    final controller = PosAppController()
      ..language = AppLanguage.en
      ..serverConfig = ServerConfig(
        serverId: 'server-1',
        restaurantId: 'restaurant-1',
        outletId: 'outlet-1',
        restaurantName: 'Counter Only',
        outletName: 'Counter Only',
        publicSlug: 'counter-only',
        tableCount: 0,
      );

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(theme: AppTheme.light(), home: const QrPdfScreen()),
      ),
    );

    expect(find.byKey(const ValueKey('restaurant-main-qr-card')), findsOne);
    expect(find.text('Restaurant menu'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Table 1'), findsNothing);

    controller.dispose();
  });
}
