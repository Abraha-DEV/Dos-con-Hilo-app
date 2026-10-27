import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/reports_repository.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late Future<SalesReport> _report;
  final _currency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  @override
  void initState() { super.initState(); _load(); }
  void _load() => _report = ReportsRepository(Supabase.instance.client).fetchCurrentMonth();
  Future<void> _refresh() async { setState(_load); await _report; }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(leading: IconButton(onPressed: () => context.go('/'), icon: const Icon(Icons.arrow_back)), title: const Text('Reportes')),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<SalesReport>(
            future: _report,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) {
                return ListView(children: [
                const SizedBox(height: 100),
                const Icon(Icons.cloud_off_outlined, size: 42),
                const SizedBox(height: 12),
                const Center(child: Text('No se pudo cargar el reporte')),
                Padding(padding: const EdgeInsets.all(20), child: Text('${snapshot.error}', textAlign: TextAlign.center)),
                Center(child: TextButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Reintentar'))),
                ]);
              }
              final report = snapshot.data!;
              return ListView(padding: const EdgeInsets.all(20), children: [
                Text(DateFormat('MMMM yyyy', 'es_MX').format(DateTime.now()), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Ventas completadas', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Text(_currency.format(report.total), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                  Text('${report.salesCount} ventas este mes'),
                ]))),
                const SizedBox(height: 24),
                Text('Productos más vendidos', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (report.bestSellers.isEmpty)
                  const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('Todavía no hay ventas completadas este mes.')))
                else
                  ...report.bestSellers.asMap().entries.map((entry) => Card(child: ListTile(
                        leading: CircleAvatar(child: Text('${entry.key + 1}')),
                        title: Text(entry.value.name),
                        subtitle: Text('${entry.value.quantity} unidades · ${_currency.format(entry.value.revenue)}'),
                      ))),
              ]);
            },
          ),
        ),
      );
}
