import 'package:supabase_flutter/supabase_flutter.dart';

import 'product.dart';

class ProductsRepository {
  ProductsRepository(this._client);

  final SupabaseClient _client;

  Future<String?> _businessIdForCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) throw AuthException('Inicia sesión para consultar productos.');

    final membership = await _client
        .from('business_members')
        .select('business_id')
        .eq('user_id', user.id)
        .limit(1)
        .maybeSingle();
    return membership?['business_id'] as String?;
  }

  Future<List<Product>> fetchProducts() async {
    final businessId = await _businessIdForCurrentUser();
    if (businessId == null) return const [];

    final rows = await _client
        .from('products')
        .select('id,name,description,category,price,stock,image_url,is_published,is_custom_orderable')
        .eq('business_id', businessId)
        .order('name');

    return rows.map((row) => Product.fromJson(row)).toList(growable: false);
  }

  Future<void> createProduct({
    required String name,
    required String description,
    required String category,
    required double price,
    required int stock,
    required String? imageUrl,
    required bool isPublished,
    required bool isCustomOrderable,
  }) async {
    final businessId = await _businessIdForCurrentUser();
    if (businessId == null) throw StateError('Tu usuario no tiene un negocio asignado.');
    await _client.from('products').insert({
      'business_id': businessId,
      'name': name,
      'description': description,
      'category': category,
      'price': price,
      'stock': stock,
      'image_url': imageUrl,
      'is_published': isPublished,
      'is_custom_orderable': isCustomOrderable,
    });
  }

  Future<void> updateProduct({
    required String id,
    required String name,
    required String description,
    required String category,
    required double price,
    required int stock,
    required String? imageUrl,
    required bool isPublished,
    required bool isCustomOrderable,
  }) async {
    await _client.from('products').update({
      'name': name,
      'description': description,
      'category': category,
      'price': price,
      'stock': stock,
      'image_url': imageUrl,
      'is_published': isPublished,
      'is_custom_orderable': isCustomOrderable,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deleteProduct(String id) async {
    await _client.from('products').delete().eq('id', id);
  }
}
