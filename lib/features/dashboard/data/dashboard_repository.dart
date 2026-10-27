import 'package:supabase_flutter/supabase_flutter.dart';

import 'dashboard_summary.dart';

class DashboardRepository {
  DashboardRepository(this._client);
  final SupabaseClient _client;

  Future<DashboardSummary> fetchSummary() async {
    final user = _client.auth.currentUser;
    if (user == null) throw AuthException('Inicia sesión para consultar el resumen.');
    final membership = await _client.from('business_members').select('business_id').eq('user_id', user.id).limit(1).maybeSingle();
    final businessId = membership?['business_id'] as String?;
    if (businessId == null) throw StateError('Tu usuario no tiene un negocio asignado.');

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month).toUtc().toIso8601String();
    final results = await Future.wait([
      _client.from('sales').select('total,status,created_at').eq('business_id', businessId).gte('created_at', monthStart),
      _client.from('products').select('stock').eq('business_id', businessId),
      _client.from('custom_orders').select('status').eq('business_id', businessId),
    ]);

    final salesRows = results[0] as List<dynamic>;
    final productsRows = results[1] as List<dynamic>;
    final ordersRows = results[2] as List<dynamic>;
    var todayTotal = 0.0;
    var monthTotal = 0.0;
    for (final raw in salesRows) {
      final row = raw as Map<String, dynamic>;
      if (row['status'] != 'COMPLETED') continue;
      final total = (row['total'] as num).toDouble();
      monthTotal += total;
      final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '');
      if (createdAt != null && !createdAt.toLocal().isBefore(DateTime(now.year, now.month, now.day))) {
        todayTotal += total;
      }
    }
    final lowStock = productsRows.where((raw) => ((raw as Map<String, dynamic>)['stock'] as int) <= 3).length;
    final pending = ordersRows.where((raw) => !const ['DELIVERED', 'CANCELLED'].contains((raw as Map<String, dynamic>)['status'])).length;
    return DashboardSummary(salesToday: todayTotal, salesMonth: monthTotal, lowStockProducts: lowStock, pendingOrders: pending);
  }
}
