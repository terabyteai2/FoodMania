import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/models/order_item.dart';
import 'package:local_pos/src/models/order_model.dart';
import 'package:local_pos/src/models/order_service_type.dart';
import 'package:local_pos/src/models/order_source.dart';
import 'package:local_pos/src/models/order_status.dart';
import 'package:local_pos/src/services/printer/printer_vendor.dart';
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
    expect(ticket, contains('Helium'));
    expect(ticket, contains('[DINE IN]'));
    expect(ticket, contains('24 May 2026 - 1.17 pm'));
    expect(ticket, contains('1. Chicken Burger'));
    expect(ticket, contains('1x'));
    expect(ticket, contains('500/-'));
    expect(ticket, contains('2. Egger Burger'));
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
    'KOT preview uses kitchen-only data without prices totals or QR',
    () async {
      final order = OrderModel(
        id: 'order-kot',
        orderNo: 'ORD-KOT',
        sequenceNo: 24,
        status: OrderStatus.accepted,
        source: OrderSource.manual,
        serviceType: OrderServiceType.dineIn,
        tableNo: 'T5',
        customerName: 'Ayesha',
        deliveryAddress: 'House 5',
        mobileNumber: '01711223344',
        subtotal: 1200,
        vatRatePercent: 5,
        vatAmount: 60,
        total: 1260,
        createdAt: DateTime(2026, 5, 24, 19, 30),
        updatedAt: DateTime(2026, 5, 24, 19, 30),
        items: [
          OrderItem(
            id: 'line-kacchi',
            orderId: 'order-kot',
            menuItemId: 'kacchi',
            name: 'Kacchi Biryani',
            nameEn: 'Kacchi Biryani',
            qty: 2,
            price: 500,
            lineTotal: 1000,
            note: 'Extra spicy',
          ),
          OrderItem(
            id: 'line-burger',
            orderId: 'order-kot',
            menuItemId: 'burger',
            name: 'Beef Smash Burger (No onions)',
            nameEn: 'Beef Smash Burger (No onions)',
            qty: 1,
            price: 200,
            lineTotal: 200,
          ),
        ],
      );

      final ticket = await PrinterService().previewKot(
        order,
        restaurantName: 'Spice Garden, Dhanmondi',
        serverName: 'Rahim',
        language: AppLanguage.en,
      );

      expect(ticket, contains('KOT'));
      expect(ticket, contains('Spice Garden, Dhanmondi'));
      expect(ticket, contains('Serial #: #24'));
      expect(ticket, contains('Time: 7:30 PM'));
      expect(ticket, contains('Type: Dine-in'));
      expect(ticket, contains('Table: T5'));
      expect(ticket, contains('Items'));
      expect(ticket, contains('2 x Kacchi Biryani'));
      expect(ticket, contains('1 x Beef Smash Burger (No onions)'));
      expect(ticket, contains('Note'));
      expect(ticket, contains('Extra spicy'));
      expect(ticket, contains('Server: Rahim'));
      expect(ticket, isNot(contains('500/-')));
      expect(ticket, isNot(contains('200/-')));
      expect(ticket, isNot(contains('Total')));
      expect(ticket, isNot(contains('VAT')));
      expect(ticket, isNot(contains('Manager Copy')));
      expect(ticket, isNot(contains('Customer Copy')));
      expect(ticket, isNot(contains('SCAN FOR LIVE ORDER DETAILS')));
      expect(ticket, isNot(contains('House 5')));
      expect(ticket, isNot(contains('01711223344')));
    },
  );

  test('KOT preview omits table for parcel orders', () async {
    final order = OrderModel(
      id: 'order-parcel-kot',
      orderNo: 'ORD-PARCEL-KOT',
      sequenceNo: 25,
      status: OrderStatus.accepted,
      source: OrderSource.manual,
      serviceType: OrderServiceType.takeaway,
      tableNo: 'T5',
      total: 100,
      createdAt: DateTime(2026, 5, 24, 20),
      updatedAt: DateTime(2026, 5, 24, 20),
      items: [
        OrderItem(
          id: 'line-parcel',
          orderId: 'order-parcel-kot',
          menuItemId: 'tea',
          name: 'Tea',
          nameEn: 'Tea',
          qty: 1,
          price: 100,
          lineTotal: 100,
        ),
      ],
    );

    final ticket = await PrinterService().previewKot(
      order,
      restaurantName: 'Spice Garden',
      language: AppLanguage.en,
    );

    expect(ticket, contains('Type: Parcel'));
    expect(ticket, isNot(contains('Table:')));
  });

  test('bitmap renderer targets 58mm printable width', () {
    expect(TicketBitmapRenderer.debugPrintableWidth, 384);
  });

  test('detected vendor reports as a selected built-in printer', () {
    final state = PrinterRuntimeState(
      autoPrintEnabled: true,
      connected: true,
      busy: false,
      detectedVendor: PrinterVendor.sunmi,
    );

    expect(state.hasDetectedPrinter, isTrue);
    expect(state.selectedPrinterLabel, 'Sunmi printer');
  });

  test('no detected vendor reports as no printer', () {
    final state = PrinterRuntimeState(
      autoPrintEnabled: true,
      connected: false,
      busy: false,
    );

    expect(state.hasDetectedPrinter, isFalse);
    expect(state.selectedPrinterLabel, 'No printer detected');
  });
}
