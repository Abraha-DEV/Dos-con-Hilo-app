import 'package:supabase_flutter/supabase_flutter.dart';

import '../../products/data/product.dart';
import '../../products/data/products_repository.dart';
import 'sale.dart';

class SalesRepository {
  SalesRepository(this._client);

  final SupabaseClient _client;

  Future<String> _businessId() async {
    final user = _client.auth.currentUser;
    if (user == null) throw AuthException('Inicia sesión para consultar ventas.');
    final row = await _client.from('business_members').select('business_id').eq('user_id', user.id).limit(1).maybeSingle();
    final id = row?['business_id'] as String?;
    if (id == null) throw StateError('Tu usuario no tiene un negocio asignado.');
    return id;
  }

  Future<List<Product>> fetchSellableProducts() => ProductsRepository(_client).fetchProducts();

  Future<List<Sale>> fetchSales() async {
    final businessId = await _businessId();
    final rows = await _client
        .from('sales')
        .select('id,sale_channel,payment_method,total,status,created_at,sale_items(quantity,unit_price,products(name))')
        .eq('business_id', businessId)
        .order('created_at', ascending: false);
    return rows.map((row) => Sale.fromJson(row)).toList(growable: false);
  }

  Future<String> confirmSale({
    required String channel,
    required String paymentMethod,
    required Map<String, int> quantities,
    required String idempotencyKey,
  }) async {
    final businessId = await _businessId();
    final response = await _client.rpc<String>('confirm_sale', params: {
      'p_business_id': businessId,
      'p_idempotency_key': idempotencyKey,
      'p_sale_channel': channel,
      'p_payment_method': paymentMethod,
      'p_items': quantities.entries.map((entry) => {'product_id': entry.key, 'quantity': entry.value}).toList(),
    });
    return response;
  }

  Future<void> cancelSale(String saleId) async {
    await _client.rpc<void>('cancel_sale', params: {'p_sale_id': saleId});
  }

}
