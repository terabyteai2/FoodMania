import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/models/order_item.dart';
import 'package:local_pos/src/models/order_model.dart';
import 'package:local_pos/src/models/order_source.dart';
import 'package:local_pos/src/models/order_status.dart';
import 'package:local_pos/src/services/printer_service.dart';
import 'package:local_pos/src/services/ticket_bitmap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('manager copy preview uses compact order data format', () async {
    final order = OrderModel(
      id: 'order-30',
      orderNo: 'ORD-30',
      sequenceNo: 30,
      status: OrderStatus.accepted,
      source: OrderSource.manual,
      subtotal: 700,
      vatRatePercent: 5,
      vatAmount: 35,
      total: 735,
      createdAt: DateTime(2026, 5, 24, 13, 17),
      updatedAt: DateTime(2026, 5, 24, 13, 17),
      items: [
        OrderItem(
          id: 'line-1',
          orderId: 'order-30',
          menuItemId: 'burger-1',
          name: 'Chicken Burger',
          nameEn: 'Chicken Burger',
          qty: 1,
          price: 500,
          lineTotal: 500,
        ),
        OrderItem(
          id: 'line-2',
          orderId: 'order-30',
          menuItemId: 'burger-2',
          name: 'Egger Burger',
          nameEn: 'Egger Burger',
          qty: 2,
          price: 100,
          lineTotal: 200,
        ),
      ],
    );

    final ticket = await PrinterService().previewTicket(
      order,
      restaurantName: 'Helium',
      language: AppLanguage.en,
    );

    expect(ticket, contains('#30'));
    expect(ticket, contains('Order: #30'));
    expect(ticket, contains('Helium'));
    expect(ticket, contains('DINE IN'));
    expect(ticket, contains('24 May 2026 - 1.17 pm'));
    expect(ticket, contains('001 1x Chicken Burger'));
    expect(ticket, contains('1x'));
    expect(ticket, contains('500/-'));
    expect(ticket, contains('002 2x Egger Burger'));
    expect(ticket, contains('2x'));
    expect(ticket, contains('200/-'));
    expect(ticket, contains('Total (VAT included)'));
    expect(ticket, contains('700/-'));
    expect(ticket, contains('SCAN FOR LIVE ORDER DETAILS'));
  });

  test(
    'preview falls back to price times qty when line total is missing',
    () async {
      final order = OrderModel(
        id: 'order-fallback',
        orderNo: 'ORD-FALLBACK',
        sequenceNo: 31,
        status: OrderStatus.accepted,
        source: OrderSource.manual,
        subtotal: 0,
        vatRatePercent: 0,
        vatAmount: 0,
        total: 0,
        createdAt: DateTime(2026, 5, 24, 13, 20),
        updatedAt: DateTime(2026, 5, 24, 13, 20),
        items: [
          OrderItem(
            id: 'line-fallback',
            orderId: 'order-fallback',
            menuItemId: 'burger-fallback',
            name: 'Fallback Burger',
            nameEn: 'Fallback Burger',
            qty: 2,
            price: 175,
            lineTotal: 0,
          ),
        ],
      );

      final ticket = await PrinterService().previewTicket(
        order,
        restaurantName: 'Helium',
        language: AppLanguage.en,
      );

      expect(ticket, contains('Fallback Burger'));
      expect(ticket, contains('350/-'));
      expect(ticket, contains('Total (VAT included)'));
    },
  );

  test(
    'receipt total reflects a discount on an unsettled mobile order',
    () async {
      final order = OrderModel(
        id: 'order-discount-mobile',
        orderNo: 'ORD-DISC',
        sequenceNo: 32,
        status: OrderStatus.accepted,
        source: OrderSource.manual,
        subtotal: 700,
        vatRatePercent: 0,
        vatAmount: 0,
        discountLabel: 'Staff 50',
        discountAmount: 50,
        total: 700,
        createdAt: DateTime(2026, 5, 24, 14, 0),
        updatedAt: DateTime(2026, 5, 24, 14, 0),
        items: [
          OrderItem(
            id: 'line-disc',
            orderId: 'order-discount-mobile',
            menuItemId: 'burger-disc',
            name: 'Discount Burger',
            nameEn: 'Discount Burger',
            qty: 1,
            price: 700,
            lineTotal: 700,
          ),
        ],
      );

      final ticket = await PrinterService().previewTicket(
        order,
        restaurantName: 'Helium',
        language: AppLanguage.en,
      );

      expect(ticket, contains('Discount'));
      expect(ticket, contains('-50/-'));
      expect(ticket, contains('700/-'));
      expect(ticket, contains('650/-'));
    },
  );

  test('receipt keeps the folded total of a settled desktop order', () async {
    final order = OrderModel(
      id: 'order-discount-settled',
      orderNo: 'ORD-SETTLED',
      sequenceNo: 33,
      status: OrderStatus.served,
      source: OrderSource.desktopPos,
      subtotal: 700,
      vatRatePercent: 0,
      vatAmount: 0,
      discountLabel: 'Staff 50',
      discountAmount: 50,
      total: 650,
      settledAt: DateTime(2026, 5, 24, 14, 30),
      createdAt: DateTime(2026, 5, 24, 14, 0),
      updatedAt: DateTime(2026, 5, 24, 14, 30),
      items: [
        OrderItem(
          id: 'line-settled',
          orderId: 'order-discount-settled',
          menuItemId: 'burger-settled',
          name: 'Settled Burger',
          nameEn: 'Settled Burger',
          qty: 1,
          price: 700,
          lineTotal: 700,
        ),
      ],
    );

    final ticket = await PrinterService().previewTicket(
      order,
      restaurantName: 'Helium',
      language: AppLanguage.en,
    );

    expect(ticket, contains('Discount'));
    expect(ticket, contains('-50/-'));
    expect(ticket, contains('650/-'));
  });

  test('bitmap renderer targets 58mm printable width', () {
    expect(TicketBitmapRenderer.debugPrintableWidth, 384);
  });

  test('built-in printer label is hidden in the mobile app', () {
    final state = PrinterRuntimeState(
      autoPrintEnabled: true,
      connected: true,
      busy: false,
      activeTransport: PrinterTransport.builtIn,
      builtInPrinterAvailable: true,
      usbPrinterAvailable: true,
      selectedPrinterName: 'Bluetooth fallback',
      selectedPrinterAddress: '00:11:22:33:44:55',
    );

    expect(state.hasSelectedPrinter, isTrue);
    expect(state.selectedPrinterLabel, 'Bluetooth fallback');
  });

  test('USB printer remains a selected local fallback', () {
    final state = PrinterRuntimeState(
      autoPrintEnabled: true,
      connected: true,
      busy: false,
      activeTransport: PrinterTransport.usb,
      usbPrinterAvailable: true,
    );

    expect(state.hasSelectedPrinter, isTrue);
    expect(state.selectedPrinterLabel, 'USB printer (type-C)');
  });
}
