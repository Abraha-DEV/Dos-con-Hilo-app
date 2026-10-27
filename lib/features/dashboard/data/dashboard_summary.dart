class DashboardSummary {
  const DashboardSummary({required this.salesToday, required this.salesMonth, required this.lowStockProducts, required this.pendingOrders});
  final double salesToday;
  final double salesMonth;
  final int lowStockProducts;
  final int pendingOrders;
}
