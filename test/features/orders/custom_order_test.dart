import 'package:dos_con_hilo_admin/features/orders/data/custom_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CustomOrder balance', () {
    test('counts initial deposit and later payments separately', () {
      final order = CustomOrder(
        id: 'order-id',
        customerName: 'Cliente',
        description: 'Tejido personalizado',
        agreedPrice: 1000,
        deposit: 200,
        status: 'IN_PROGRESS',
        payments: const [
          OrderPayment(amount: 150, paidAt: null, paymentMethod: 'EFECTIVO'),
          OrderPayment(amount: 100, paidAt: null, paymentMethod: 'TRANSFERENCIA'),
        ],
      );

      expect(order.paidAmount, 450);
      expect(order.balance, 550);
    });

    test('does not report a negative balance for fully paid orders', () {
      final order = CustomOrder(
        id: 'order-id',
        customerName: 'Cliente',
        description: 'Tejido personalizado',
        agreedPrice: 300,
        deposit: 200,
        status: 'DELIVERED',
        payments: const [OrderPayment(amount: 100, paidAt: null, paymentMethod: 'EFECTIVO')],
      );

      expect(order.balance, 0);
    });
  });
}
