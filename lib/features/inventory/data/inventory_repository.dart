import 'package:supabase_flutter/supabase_flutter.dart';

import '../../products/data/product.dart';
import '../../products/data/products_repository.dart';
import 'inventory_movement.dart';

class InventoryRepository {
  InventoryRepository(this._client);
  final SupabaseClient _client;

  Future<String> currentBusinessId() async {
    final user = _client.auth.currentUser;
    if (user == null) throw AuthException('Inicia sesión para consultar inventario.');
    final row = await _client.from('business_members').select('business_id').eq('user_id', user.id).limit(1).maybeSingle();
    final id = row?['business_id'] as String?;
    if (id == null) throw StateError('Tu usuario no tiene un negocio asignado.');
    return id;
  }

  Future<List<Product>> fetchProducts() => ProductsRepository(_client).fetchProducts();

  Future<List<InventoryMovement>> fetchMovements() async {
    final rows = await _client
        .from('inventory_movements')
        .select('id,quantity,movement_type,reason,created_at,products(name)')
        .order('created_at', ascending: false)
        .limit(100);
    return rows.map((row) => InventoryMovement.fromJson(row)).toList(growable: false);
  }

  Future<void> adjust({
    required String businessId,
    required String productId,
    required int quantityDelta,
    required String movementType,
    required String reason,
    required String requestId,
  }) async {
    await _client.rpc<String>('adjust_inventory', params: {
      'p_business_id': businessId,
      'p_product_id': productId,
      'p_quantity_delta': quantityDelta,
      'p_movement_type': movementType,
      'p_reason': reason,
      'p_request_id': requestId,
    });
  }
}
