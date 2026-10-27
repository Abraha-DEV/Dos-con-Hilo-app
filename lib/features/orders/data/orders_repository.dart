import 'package:supabase_flutter/supabase_flutter.dart';

import 'custom_order.dart';

class OrdersRepository {
  OrdersRepository(this._client);

  final SupabaseClient _client;

  Future<String> _businessId() async {
    final user = _client.auth.currentUser;
    if (user == null) throw AuthException('Inicia sesión para consultar pedidos.');
    final row = await _client
        .from('business_members')
        .select('business_id')
        .eq('user_id', user.id)
        .limit(1)
        .maybeSingle();
    final id = row?['business_id'] as String?;
    if (id == null) throw StateError('Tu usuario no tiene un negocio asignado.');
    return id;
  }

  Future<List<CustomOrder>> fetchOrders() async {
    final businessId = await _businessId();
    final rows = await _client
        .from('custom_orders')
        .select('id,customer_name,customer_contact,description,agreed_price,deposit,due_date,status,order_payments(amount,paid_at,payment_method)')
        .eq('business_id', businessId)
        .order('created_at', ascending: false);
    return rows.map((row) => CustomOrder.fromJson(row)).toList(growable: false);
  }

  Future<void> createOrder({
    required String customerName,
    required String? customerContact,
    required String description,
    required double agreedPrice,
    required double deposit,
    required DateTime? dueDate,
    required String requestId,
  }) async {
    final businessId = await _businessId();
    final values = {
      'business_id': businessId,
      'customer_name': customerName,
      'customer_contact': customerContact,
      'description': description,
      'agreed_price': agreedPrice,
      'deposit': deposit,
      'due_date': dueDate == null ? null : _dateOnly(dueDate),
      'status': 'PENDING',
      'request_id': requestId,
    };
    try {
      await _client.from('custom_orders').insert(values);
    } catch (_) {
      final existing = await _client
          .from('custom_orders')
          .select('id')
          .eq('business_id', businessId)
          .eq('request_id', requestId)
          .maybeSingle();
      if (existing == null) rethrow;
    }
  }

  Future<void> updateOrder({required String id, required String status}) async {
    await _client.from('custom_orders').update({'status': status}).eq('id', id);
  }

  Future<void> recordPayment({
    required String orderId,
    required double amount,
    required String paymentMethod,
    required String requestId,
  }) async {
    await _client.rpc<String>('record_order_payment', params: {
      'p_order_id': orderId,
      'p_amount': amount,
      'p_payment_method': paymentMethod,
      'p_request_id': requestId,
    });
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
