import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../data/dashboard_repository.dart';
import '../data/dashboard_summary.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<DashboardSummary>? _summary;

  @override
  void initState() {
    super.initState();
    _summary = AppConfig.isConfigured
        ? DashboardRepository(Supabase.instance.client).fetchSummary()
        : null;
  }

  Future<void> _refresh() async {
    setState(() {
      _summary = DashboardRepository(Supabase.instance.client).fetchSummary();
    });
    await _summary;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return Scaffold(
          body: Row(
            children: [
              if (wide) _Sidebar(onSelected: (index) {
                if (index == 1) context.go('/products');
                if (index == 2) context.go('/inventory');
                if (index == 3) context.go('/sales');
                if (index == 4) context.go('/orders');
                if (index == 5) context.go('/reports');
              }),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      title: const Text('Dos con Hilo'),
                      actions: [
                        IconButton(
                          tooltip: 'Cerrar sesión',
                          onPressed: () => Supabase.instance.client.auth.signOut(),
                          icon: const Icon(Icons.logout),
                        ),
                        IconButton(
                          tooltip: 'Reportes',
                          onPressed: () => context.go('/reports'),
                          icon: const Icon(Icons.bar_chart_outlined),
                        ),
                        IconButton(
                          tooltip: 'Notificaciones',
                          onPressed: () {},
                          icon: const Icon(Icons.notifications_none),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(wide ? 32 : 20, 20, wide ? 32 : 20, 32),
                      sliver: SliverList.list(
                        children: [
                          const _WelcomeHeader(),
                          const SizedBox(height: 24),
                          if (_summary == null)
                            const _MetricGrid()
                          else
                            FutureBuilder<DashboardSummary>(
                              future: _summary,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
                                }
                                if (snapshot.hasError) {
                                  return _DashboardError(message: '${snapshot.error}', onRetry: _refresh);
                                }
                                return _MetricGrid(summary: snapshot.data);
                              },
                            ),
                          const SizedBox(height: 24),
                          const _SectionTitle(title: 'Atención para hoy'),
                          const SizedBox(height: 12),
                          _summary == null ? const _EmptyPanel() : _AttentionPanel(summary: _summary),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: wide ? null : _MobileNavigation(onSelected: (index) {
            if (index == 1) context.go('/products');
        if (index == 2) context.go('/inventory');
        if (index == 3) context.go('/sales');
        if (index == 4) context.go('/orders');
          }),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.onSelected});
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      extended: true,
      selectedIndex: 0,
      onDestinationSelected: onSelected,
      destinations: const [
        NavigationRailDestination(icon: Icon(Icons.space_dashboard_outlined), label: Text('Resumen')),
        NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), label: Text('Productos')),
        NavigationRailDestination(icon: Icon(Icons.swap_vert), label: Text('Inventario')),
        NavigationRailDestination(icon: Icon(Icons.point_of_sale_outlined), label: Text('Ventas')),
        NavigationRailDestination(icon: Icon(Icons.design_services_outlined), label: Text('Pedidos')),
        NavigationRailDestination(icon: Icon(Icons.bar_chart_outlined), label: Text('Reportes')),
      ],
    );
  }
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({required this.onSelected});
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: 0,
      onDestinationSelected: onSelected,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), label: 'Resumen'),
        NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Productos'),
        NavigationDestination(icon: Icon(Icons.swap_vert), label: 'Inventario'),
        NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), label: 'Ventas'),
        NavigationDestination(icon: Icon(Icons.design_services_outlined), label: 'Pedidos'),
      ],
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tu taller, en orden', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Resumen de actividad', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({this.summary});
  final DashboardSummary? summary;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _Metric(label: 'Ventas de hoy', value: NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(summary?.salesToday ?? 0), note: summary == null ? 'Datos de demostración' : 'Ventas completadas', icon: Icons.payments_outlined),
      _Metric(label: 'Ventas del mes', value: NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(summary?.salesMonth ?? 0), note: summary == null ? 'Datos de demostración' : 'Ventas completadas', icon: Icons.calendar_month_outlined),
      _Metric(label: 'Pedidos pendientes', value: '${summary?.pendingOrders ?? 0}', note: summary == null ? 'Datos de demostración' : 'Pendientes de entrega', icon: Icons.local_shipping_outlined),
      _Metric(label: 'Poco inventario', value: '${summary?.lowStockProducts ?? 0}', note: summary == null ? 'Datos de demostración' : 'Existencia de 3 o menos', icon: Icons.inventory_outlined),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth > 1000 ? 4 : constraints.maxWidth > 580 ? 2 : 1;
      return GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: columns == 1 ? 2.8 : 1.65,
        children: metrics,
      );
    });
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.note, required this.icon});

  final String label;
  final String value;
  final String note;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, color: theme.colorScheme.primary), const Spacer(), Text(label, style: theme.textTheme.labelLarge)]),
          const Spacer(),
          Text(value, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
          Text(note, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700));
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Column(children: [
          Icon(Icons.check_circle_outline, size: 36, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text('Todo tranquilo por aquí', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Los pedidos y avisos de inventario aparecerán aquí.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        ]),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Card(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const Icon(Icons.cloud_off_outlined),
          const SizedBox(height: 8),
          const Text('No se pudo cargar el resumen'),
          Text(message, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
          TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
        ]),
      ));
}

class _AttentionPanel extends StatelessWidget {
  const _AttentionPanel({required this.summary});
  final Future<DashboardSummary>? summary;

  @override
  Widget build(BuildContext context) => FutureBuilder<DashboardSummary>(
        future: summary,
        builder: (context, snapshot) {
          final value = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())));
          }
          if (snapshot.hasError) return const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No se pudieron cargar los avisos.')));
          if (value == null) return const _EmptyPanel();
          if (value.pendingOrders == 0 && value.lowStockProducts == 0) return const _EmptyPanel();
          return Card(child: Column(children: [
            if (value.pendingOrders > 0) ListTile(leading: const Icon(Icons.local_shipping_outlined), title: Text('${value.pendingOrders} pedidos pendientes'), onTap: () => GoRouter.of(context).go('/orders')),
            if (value.lowStockProducts > 0) ListTile(leading: const Icon(Icons.inventory_outlined), title: Text('${value.lowStockProducts} productos con existencia baja'), onTap: () => GoRouter.of(context).go('/inventory')),
          ]));
        },
      );
}
