import 'package:supabase_flutter/supabase_flutter.dart';

class ProductSalesTotal {
  const ProductSalesTotal({required this.name, required this.quantity, required this.revenue});
  final String name;
  final int quantity;
  final double revenue;
}

class SalesReport {
  const SalesReport({required this.total, required this.salesCount, required this.bestSellers});
  final double total;
  final int salesCount;
  final List<ProductSalesTotal> bestSellers;
}

class ReportsRepository {
  ReportsRepository(this._client);
  final SupabaseClient _client;

  Future<SalesReport> fetchCurrentMonth() async {
    final user = _client.auth.currentUser;
    if (user == null) throw AuthException('Inicia sesión para consultar reportes.');
    final membership = await _client.from('business_members').select('business_id').eq('user_id', user.id).limit(1).maybeSingle();
    final businessId = membership?['business_id'] as String?;
    if (businessId == null) throw StateError('Tu usuario no tiene un negocio asignado.');

    final now = DateTime.now();
    final start = DateTime(now.year, now.month).toUtc().toIso8601String();
    final rows = await _client
        .from('sales')
        .select('id,total,status,sale_items(quantity,unit_price,products(name))')
        .eq('business_id', businessId)
        .eq('status', 'COMPLETED')
        .gte('created_at', start);
    var total = 0.0;
    final products = <String, ({int quantity, double revenue})>{};
    for (final raw in rows) {
      final sale = raw;
      total += (sale['total'] as num).toDouble();
      final lines = sale['sale_items'] as List<dynamic>? ?? const [];
      for (final rawLine in lines) {
        final line = rawLine as Map<String, dynamic>;
        final product = line['products'] as Map<String, dynamic>?;
        final name = product?['name'] as String? ?? 'Producto';
        final quantity = line['quantity'] as int;
        final revenue = (line['unit_price'] as num).toDouble() * quantity;
        final previous = products[name] ?? (quantity: 0, revenue: 0.0);
        products[name] = (quantity: previous.quantity + quantity, revenue: previous.revenue + revenue);
      }
    }
    final bestSellers = products.entries
        .map((entry) => ProductSalesTotal(name: entry.key, quantity: entry.value.quantity, revenue: entry.value.revenue))
        .toList()
      ..sort((a, b) => b.quantity.compareTo(a.quantity));
    return SalesReport(total: total, salesCount: rows.length, bestSellers: bestSellers.take(5).toList(growable: false));
  }
}
