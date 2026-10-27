import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/uuid.dart';
import '../../products/data/product.dart';
import '../data/inventory_movement.dart';
import '../data/inventory_repository.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> with SingleTickerProviderStateMixin {
  late final InventoryRepository _repository;
  late final TabController _tabs;
  late Future<List<Product>> _products;
  late Future<List<InventoryMovement>> _movements;

  @override
  void initState() {
    super.initState();
    _repository = InventoryRepository(Supabase.instance.client);
    _tabs = TabController(length: 2, vsync: this);
    _reload();
  }

  void _reload() {
    _products = _repository.fetchProducts();
    _movements = _repository.fetchMovements();
  }

  Future<void> _refresh() async { setState(_reload); await Future.wait([_products, _movements]); }

  Future<void> _adjust(Product product) async {
    final changed = await showDialog<bool>(context: context, builder: (_) => _InventoryAdjustmentDialog(product: product, repository: _repository));
    if (changed == true && mounted) setState(_reload);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(tooltip: 'Volver al resumen', onPressed: () => context.go('/'), icon: const Icon(Icons.arrow_back)),
          title: const Text('Inventario'),
          bottom: TabBar(controller: _tabs, tabs: const [Tab(text: 'Existencias'), Tab(text: 'Movimientos')]),
        ),
        body: TabBarView(controller: _tabs, children: [
          RefreshIndicator(onRefresh: _refresh, child: FutureBuilder<List<Product>>(
            future: _products,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return _InventoryMessage(title: 'No se pudo cargar el inventario', detail: '${snapshot.error}', onRetry: _refresh);
              final products = snapshot.data ?? const <Product>[];
              if (products.isEmpty) return const _InventoryMessage(title: 'No hay productos', detail: 'Crea un producto para empezar a llevar existencias.');
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) => Card(child: ListTile(
                  leading: CircleAvatar(child: Text('${products[index].stock}')),
                  title: Text(products[index].name),
                  subtitle: Text('Existencia actual: ${products[index].stock}'),
                  trailing: IconButton(tooltip: 'Registrar entrada o ajuste', onPressed: () => _adjust(products[index]), icon: const Icon(Icons.tune)),
                )),
              );
            },
          )),
          RefreshIndicator(onRefresh: _refresh, child: FutureBuilder<List<InventoryMovement>>(
            future: _movements,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return _InventoryMessage(title: 'No se pudo cargar el historial', detail: '${snapshot.error}', onRetry: _refresh);
              final movements = snapshot.data ?? const <InventoryMovement>[];
              if (movements.isEmpty) return const _InventoryMessage(title: 'Sin movimientos', detail: 'Las entradas, ventas y ajustes aparecerán aquí.');
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: movements.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final movement = movements[index];
                  final plus = movement.quantity > 0;
                  final date = movement.createdAt == null ? '' : DateFormat('d MMM yyyy, HH:mm', 'es_MX').format(movement.createdAt!.toLocal());
                  return Card(child: ListTile(
                    leading: Icon(plus ? Icons.add_circle_outline : Icons.remove_circle_outline, color: plus ? Colors.green : Theme.of(context).colorScheme.error),
                    title: Text(movement.productName ?? 'Producto'),
                    subtitle: Text('${_movementLabel(movement.type)}${(movement.reason ?? '').isEmpty ? '' : ' · ${movement.reason}'}\n$date'),
                    isThreeLine: true,
                    trailing: Text('${plus ? '+' : ''}${movement.quantity}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ));
                },
              );
            },
          )),
        ]),
      );

  String _movementLabel(String type) => switch (type) {
        'RESTOCK' => 'Entrada',
        'SALE' => 'Venta',
        'CUSTOM_ORDER' => 'Pedido personalizado',
        _ => 'Ajuste',
      };
}

class _InventoryMessage extends StatelessWidget {
  const _InventoryMessage({required this.title, required this.detail, this.onRetry});
  final String title;
  final String detail;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) => ListView(children: [
        const SizedBox(height: 100),
        const Icon(Icons.inventory_2_outlined, size: 44),
        const SizedBox(height: 12),
        Center(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
        Padding(padding: const EdgeInsets.all(20), child: Text(detail, textAlign: TextAlign.center)),
        if (onRetry != null) Center(child: TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Reintentar'))),
      ]);
}

class _InventoryAdjustmentDialog extends StatefulWidget {
  const _InventoryAdjustmentDialog({required this.product, required this.repository});
  final Product product;
  final InventoryRepository repository;

  @override
  State<_InventoryAdjustmentDialog> createState() => _InventoryAdjustmentDialogState();
}

class _InventoryAdjustmentDialogState extends State<_InventoryAdjustmentDialog> {
  final _key = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _reason = TextEditingController();
  String _type = 'RESTOCK';
  bool _saving = false;
  bool _attempted = false;
  late final String _requestId = createUuidV4();

  @override
  void dispose() { _quantity.dispose(); _reason.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _attempted = true);
    setState(() => _saving = true);
    try {
      final entered = int.parse(_quantity.text.trim());
      final delta = entered;
      final businessId = await widget.repository.currentBusinessId();
      await widget.repository.adjust(
        businessId: businessId,
        productId: widget.product.id,
        quantityDelta: delta,
        movementType: _type,
        reason: _reason.text.trim(),
        requestId: _requestId,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo actualizar la existencia: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Existencia · ${widget.product.name}'),
        content: Form(key: _key, child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Existencia actual: ${widget.product.stock}'),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Tipo de movimiento'),
            items: const [DropdownMenuItem(value: 'RESTOCK', child: Text('Entrada de inventario')), DropdownMenuItem(value: 'ADJUSTMENT', child: Text('Ajuste (+ o −)'))],
            onChanged: _saving || _attempted ? null : (value) { if (value != null) setState(() => _type = value); },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _quantity,
            readOnly: _attempted,
            decoration: InputDecoration(labelText: _type == 'RESTOCK' ? 'Cantidad recibida' : 'Cambio (usa − para restar)'),
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            validator: (value) {
              final parsed = int.tryParse((value ?? '').trim());
              if (parsed == null || parsed == 0) return 'Escribe una cantidad distinta de cero';
              if (_type == 'RESTOCK' && parsed < 0) return 'La entrada debe ser positiva';
              if (widget.product.stock + parsed < 0) return 'La existencia no puede quedar negativa';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _reason, readOnly: _attempted, decoration: const InputDecoration(labelText: 'Motivo del movimiento'), validator: (value) => value == null || value.trim().isEmpty ? 'Escribe un motivo para el historial' : null),
        ])),
        actions: [
          TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_attempted ? 'Reintentar' : 'Guardar movimiento')),
        ],
      );
}
