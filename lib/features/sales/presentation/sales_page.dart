import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/uuid.dart';
import '../../products/data/product.dart';
import '../data/sale.dart';
import '../data/sales_repository.dart';

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  late final SalesRepository _repository;
  late Future<List<Sale>> _sales;
  final _currency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  String? _channelFilter;
  String? _statusFilter;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _repository = SalesRepository(Supabase.instance.client);
    _reload();
  }

  void _reload() => _sales = _repository.fetchSales();

  Future<void> _refresh() async { setState(_reload); await _sales; }

  Future<void> _newSale() async {
    final saved = await showDialog<bool>(context: context, builder: (_) => _NewSaleDialog(repository: _repository));
    if (saved == true && mounted) setState(_reload);
  }

  Future<void> _pickDateRange() async {
    final today = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 10),
      lastDate: DateTime(today.year, today.month, today.day),
      initialDateRange: _dateRange,
      locale: const Locale('es', 'MX'),
    );
    if (range != null && mounted) setState(() => _dateRange = range);
  }

  Future<void> _cancel(Sale sale) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Cancelar venta'),
      content: const Text('La venta se marcará como cancelada y sus existencias se devolverán al inventario.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Volver')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancelar venta')),
      ],
    ));
    if (confirmed != true) return;
    try {
      await _repository.cancelSale(sale.id);
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo cancelar: $error')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(tooltip: 'Volver al resumen', onPressed: () => context.go('/'), icon: const Icon(Icons.arrow_back)),
          title: const Text('Ventas'),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Filtrar canal',
              icon: const Icon(Icons.filter_list),
              initialValue: _channelFilter ?? '',
              onSelected: (value) => setState(() => _channelFilter = value.isEmpty ? null : value),
              itemBuilder: (context) => const [
                PopupMenuItem(value: '', child: Text('Todos los canales')),
                PopupMenuItem(value: 'PRESENCIAL', child: Text('Presencial')),
                PopupMenuItem(value: 'WHATSAPP', child: Text('WhatsApp')),
                PopupMenuItem(value: 'REDES_SOCIALES', child: Text('Redes sociales')),
                PopupMenuItem(value: 'OTRO', child: Text('Otro')),
              ],
            ),
            PopupMenuButton<String>(
              tooltip: 'Filtrar estado',
              icon: const Icon(Icons.check_circle_outline),
              initialValue: _statusFilter ?? '',
              onSelected: (value) => setState(() => _statusFilter = value.isEmpty ? null : value),
              itemBuilder: (context) => const [
                PopupMenuItem(value: '', child: Text('Todos los estados')),
                PopupMenuItem(value: 'COMPLETED', child: Text('Completadas')),
                PopupMenuItem(value: 'CANCELLED', child: Text('Canceladas')),
              ],
            ),
            IconButton(tooltip: 'Filtrar fechas', onPressed: _pickDateRange, icon: const Icon(Icons.date_range_outlined)),
            if (_channelFilter != null || _statusFilter != null || _dateRange != null)
              IconButton(
                tooltip: 'Limpiar filtros',
                onPressed: () => setState(() { _channelFilter = null; _statusFilter = null; _dateRange = null; }),
                icon: const Icon(Icons.filter_alt_off_outlined),
              ),
            IconButton(tooltip: 'Nueva venta', onPressed: _newSale, icon: const Icon(Icons.add)),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<Sale>>(
            future: _sales,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return _SalesMessage(title: 'No se pudieron cargar las ventas', detail: '${snapshot.error}', action: TextButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Reintentar')));
              final sales = (snapshot.data ?? const <Sale>[]).where((sale) {
                if (_channelFilter != null && sale.channel != _channelFilter) return false;
                if (_statusFilter != null && sale.status != _statusFilter) return false;
                if (_dateRange != null) {
                  final created = sale.createdAt?.toLocal();
                  if (created == null) return false;
                  final start = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
                  final endExclusive = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day + 1);
                  if (created.isBefore(start) || !created.isBefore(endExclusive)) return false;
                }
                return true;
              }).toList();
              if (sales.isEmpty) return _SalesMessage(title: 'No hay ventas para mostrar', detail: 'Registra una venta para verla aquí.');
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: sales.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _SaleCard(
                  sale: sales[index],
                  currency: _currency,
                  onCancel: sales[index].status == 'COMPLETED' ? () => _cancel(sales[index]) : null,
                ),
              );
            },
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(onPressed: _newSale, icon: const Icon(Icons.add), label: const Text('Nueva venta')),
      );
}

class _SalesMessage extends StatelessWidget {
  const _SalesMessage({required this.title, required this.detail, this.action});
  final String title;
  final String detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) => ListView(children: [
        const SizedBox(height: 110),
        const Icon(Icons.point_of_sale_outlined, size: 44),
        const SizedBox(height: 12),
        Center(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
        Padding(padding: const EdgeInsets.all(20), child: Text(detail, textAlign: TextAlign.center)),
        if (action != null) Center(child: action!),
      ]);
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({required this.sale, required this.currency, required this.onCancel});
  final Sale sale;
  final NumberFormat currency;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final when = sale.createdAt == null ? '' : DateFormat('d MMM, HH:mm', 'es_MX').format(sale.createdAt!.toLocal());
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(currency.format(sale.total), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
        Chip(label: Text(sale.status == 'CANCELLED' ? 'Cancelada' : 'Completada')),
        if (onCancel != null) PopupMenuButton<String>(
          onSelected: (_) => onCancel!(),
          itemBuilder: (_) => const [PopupMenuItem(value: 'cancel', child: Text('Cancelar venta'))],
        ),
      ]),
      Text('$when · ${_channelLabel(sale.channel)} · ${_paymentLabel(sale.paymentMethod)}', style: theme.textTheme.bodySmall),
      if (sale.items.isNotEmpty) ...[
        const SizedBox(height: 10),
        ...sale.items.map((item) => Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text('${item.quantity} × ${item.productName ?? 'Producto'} · ${currency.format(item.unitPrice)}'),
        )),
      ],
    ])));
  }

  String _channelLabel(String value) => switch (value) {
        'PRESENCIAL' => 'Presencial',
        'WHATSAPP' => 'WhatsApp',
        'REDES_SOCIALES' => 'Redes sociales',
        _ => 'Otro canal',
      };

  String _paymentLabel(String value) => switch (value) {
        'EFECTIVO' => 'Efectivo',
        'TRANSFERENCIA' => 'Transferencia',
        'TARJETA' => 'Tarjeta',
        _ => 'Otro pago',
      };
}

class _NewSaleDialog extends StatefulWidget {
  const _NewSaleDialog({required this.repository});
  final SalesRepository repository;

  @override
  State<_NewSaleDialog> createState() => _NewSaleDialogState();
}

class _NewSaleDialogState extends State<_NewSaleDialog> {
  late final Future<List<Product>> _products = widget.repository.fetchSellableProducts();
  final Map<String, int> _cart = {};
  final _key = GlobalKey<FormState>();
  String? _selectedId;
  String _channel = 'PRESENCIAL';
  String _paymentMethod = 'EFECTIVO';
  bool _saving = false;
  bool _attempted = false;
  late final String _idempotencyKey = createUuidV4();
  final _currency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  Future<void> _submit() async {
    if (_cart.isEmpty || !_key.currentState!.validate()) return;
    setState(() => _attempted = true);
    setState(() => _saving = true);
    try {
      await widget.repository.confirmSale(channel: _channel, paymentMethod: _paymentMethod, quantities: _cart, idempotencyKey: _idempotencyKey);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo confirmar la venta: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Nueva venta'),
        content: SizedBox(
          width: 500,
          child: FutureBuilder<List<Product>>(
            future: _products,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
              if (snapshot.hasError) return SizedBox(height: 120, child: Center(child: Text('No se pudieron cargar productos: ${snapshot.error}')));
              final products = (snapshot.data ?? const <Product>[]).where((product) => product.stock > 0).toList();
              if (products.isEmpty) return const SizedBox(height: 120, child: Center(child: Text('No hay productos con existencia disponible.')));
              final availableIds = products.map((product) => product.id).toSet();
              if (_selectedId != null && !availableIds.contains(_selectedId)) _selectedId = null;
              final selected = products.where((product) => product.id == _selectedId).firstOrNull;
              final total = _cart.entries.fold<double>(0, (sum, entry) {
                final product = products.where((item) => item.id == entry.key).firstOrNull;
                return sum + (product?.price ?? 0) * entry.value;
              });
              return Form(
                key: _key,
                child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Expanded(child: DropdownButtonFormField<String>(
                      initialValue: _selectedId,
                      decoration: const InputDecoration(labelText: 'Producto'),
                      items: products.map((product) => DropdownMenuItem(value: product.id, child: Text('${product.name} · ${_currency.format(product.price)}', overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: _saving || _attempted ? null : (value) => setState(() => _selectedId = value),
                    )),
                    IconButton(
                      tooltip: 'Agregar al carrito',
                      onPressed: _saving || _attempted || selected == null ? null : () => setState(() {
                        final current = _cart[selected.id] ?? 0;
                        if (current < selected.stock) _cart[selected.id] = current + 1;
                      }),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ]),
                  if (_cart.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ..._cart.entries.map((entry) {
                      final product = products.where((item) => item.id == entry.key).firstOrNull;
                      if (product == null) return const SizedBox.shrink();
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(product.name),
                        subtitle: Text('${entry.value} × ${_currency.format(product.price)}'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(onPressed: _saving || _attempted ? null : () => setState(() {
                            if (entry.value <= 1) { _cart.remove(entry.key); } else { _cart[entry.key] = entry.value - 1; }
                          }), icon: const Icon(Icons.remove_circle_outline)),
                          Text('${entry.value}'),
                          IconButton(onPressed: _saving || _attempted || entry.value >= product.stock ? null : () => setState(() => _cart[entry.key] = entry.value + 1), icon: const Icon(Icons.add_circle_outline)),
                        ]),
                      );
                    }),
                    Align(alignment: Alignment.centerRight, child: Text('Total: ${_currency.format(total)}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                  ] else
                    const Padding(padding: EdgeInsets.all(18), child: Text('Agrega productos para comenzar el carrito.')),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _channel,
                    decoration: const InputDecoration(labelText: 'Canal de venta'),
                    items: const [
                      DropdownMenuItem(value: 'PRESENCIAL', child: Text('Presencial')),
                      DropdownMenuItem(value: 'WHATSAPP', child: Text('WhatsApp')),
                      DropdownMenuItem(value: 'REDES_SOCIALES', child: Text('Redes sociales')),
                      DropdownMenuItem(value: 'OTRO', child: Text('Otro')),
                    ],
                    onChanged: _saving || _attempted ? null : (value) { if (value != null) setState(() => _channel = value); },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _paymentMethod,
                    decoration: const InputDecoration(labelText: 'Método de pago'),
                    items: const [
                      DropdownMenuItem(value: 'EFECTIVO', child: Text('Efectivo')),
                      DropdownMenuItem(value: 'TRANSFERENCIA', child: Text('Transferencia')),
                      DropdownMenuItem(value: 'TARJETA', child: Text('Tarjeta')),
                      DropdownMenuItem(value: 'OTRO', child: Text('Otro')),
                    ],
                    onChanged: _saving || _attempted ? null : (value) { if (value != null) setState(() => _paymentMethod = value); },
                  ),
                ])),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: _saving || _cart.isEmpty ? null : _submit, child: _saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_attempted ? 'Reintentar' : 'Confirmar venta')),
        ],
      );
}
