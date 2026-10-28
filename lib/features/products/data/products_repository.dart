import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'product.dart';

class ProductsRepository {
  ProductsRepository(this._client);

  final SupabaseClient _client;
  static const _productImagesBucket = 'product-images';

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

  Future<String> uploadProductImage({
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final businessId = await _businessIdForCurrentUser();
    if (businessId == null) throw StateError('Tu usuario no tiene un negocio asignado.');
    final extension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';
    final safeExtension = RegExp(r'^[a-z0-9]{1,8}$').hasMatch(extension) ? extension : 'jpg';
    final path = '$businessId/${DateTime.now().microsecondsSinceEpoch}.$safeExtension';
    await _client.storage.from(_productImagesBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, cacheControl: '3600', upsert: false),
        );
    return _client.storage.from(_productImagesBucket).getPublicUrl(path);
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
