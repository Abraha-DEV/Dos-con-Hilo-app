import 'package:go_router/go_router.dart';

import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/auth/presentation/auth_gate.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/products/presentation/products_page.dart';
import '../../features/orders/presentation/orders_page.dart';
import '../../features/sales/presentation/sales_page.dart';
import '../../features/inventory/presentation/inventory_page.dart';
import '../../features/reports/presentation/reports_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    ShellRoute(
      builder: (context, state, child) => AuthGate(child: child),
      routes: [
        GoRoute(path: '/', builder: (context, state) => const DashboardPage()),
        GoRoute(path: '/products', builder: (context, state) => const ProductsPage()),
        GoRoute(path: '/orders', builder: (context, state) => const OrdersPage()),
        GoRoute(path: '/sales', builder: (context, state) => const SalesPage()),
        GoRoute(path: '/inventory', builder: (context, state) => const InventoryPage()),
        GoRoute(path: '/reports', builder: (context, state) => const ReportsPage()),
      ],
    ),
  ],
);
