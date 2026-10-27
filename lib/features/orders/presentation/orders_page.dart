import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/uuid.dart';
import '../data/custom_order.dart';
import '../data/orders_repository.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  late final OrdersRepository _repository;
  late Future<List<CustomOrder>> _orders;
  final _currency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  @override
  void initState() {
    super.initState();
    _repository = OrdersRepository(Supabase.instance.client);
    _reload();
  }

  void _reload() => _orders = _repository.fetchOrders();

  Future<void> _refresh() async {
    setState(_reload);
    await _orders;
  }

  Future<void> _createOrder() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _OrderFormDialog(repository: _repository),
    );
    if (created == true && mounted) setState(_reload);
  }

  Future<void> _recordPayment(CustomOrder order) async {
    final recorded = await showDialog<bool>(
      context: context,
      builder: (_) => _PaymentDialog(order: order, repository: _repository),
    );
    if (recorded == true && mounted) {
      setState(_reload);
    }
  }

  Future<void> _changeStatus(CustomOrder order, String status) async {
    try {
      await _repository.updateOrder(id: order.id, status: status);
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo actualizar el pedido: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: 'Volver al resumen', onPressed: () => context.go('/'), icon: const Icon(Icons.arrow_back)),
        title: const Text('Pedidos personalizados'),
        actions: [IconButton(tooltip: 'Nuevo pedido', onPressed: _createOrder, icon: const Icon(Icons.add))],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<CustomOrder>>(
          future: _orders,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _MessageList(
                icon: Icons.cloud_off_outlined,
                title: 'No se pudieron cargar los pedidos',
                detail: '${snapshot.error}',
                action: TextButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
              );
            }
            final orders = snapshot.data ?? const <CustomOrder>[];
            if (orders.isEmpty) {
              return _MessageList(icon: Icons.design_services_outlined, title: 'Aún no hay pedidos', detail: 'Los pedidos personalizados que registres aparecerán aquí.');
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _OrderCard(
                order: orders[index],
                currency: _currency,
                onPayment: () => _recordPayment(orders[index]),
                onStatus: (status) => _changeStatus(orders[index], status),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createOrder,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo pedido'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      backgroundColor: theme.scaffoldBackgroundColor,
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.currency, required this.onPayment, required this.onStatus});

  final CustomOrder order;
  final NumberFormat currency;
  final VoidCallback onPayment;
  final ValueChanged<String> onStatus;

  static const _statuses = ['PENDING', 'IN_PROGRESS', 'READY', 'DELIVERED', 'CANCELLED'];
  static const _statusNames = {
    'PENDING': 'Pendiente',
    'IN_PROGRESS': 'En proceso',
    'READY': 'Listo',
    'DELIVERED': 'Entregado',
    'CANCELLED': 'Cancelado',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = order.dueDate == null ? 'Sin fecha de entrega' : 'Entrega: ${DateFormat('d MMM yyyy', 'es_MX').format(order.dueDate!)}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(order.customerName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              if ((order.customerContact ?? '').isNotEmpty) Text(order.customerContact!, style: theme.textTheme.bodySmall),
            ])),
            PopupMenuButton<String>(
              tooltip: 'Cambiar estado',
              onSelected: onStatus,
              itemBuilder: (context) => _statuses.map((status) => PopupMenuItem(value: status, child: Text(_statusNames[status]!))).toList(),
              child: Chip(label: Text(_statusNames[order.status] ?? order.status)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(order.description),
          const SizedBox(height: 8),
          Text(dateLabel, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const Divider(height: 24),
          Wrap(spacing: 18, runSpacing: 8, children: [
            _Amount(label: 'Acordado', value: currency.format(order.agreedPrice)),
            _Amount(label: 'Pagado', value: currency.format(order.paidAmount)),
            _Amount(label: 'Saldo', value: currency.format(order.balance), emphasize: true),
          ]),
          if (order.payments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Abonos registrados: ${order.payments.length}', style: theme.textTheme.bodySmall),
          ],
          if (order.balance > 0 && order.status != 'CANCELLED') ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(onPressed: onPayment, icon: const Icon(Icons.add_card), label: const Text('Registrar abono')),
            ),
          ],
        ]),
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({required this.label, required this.value, this.emphasize = false});
  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500)),
      ]);
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.icon, required this.title, required this.detail, this.action});
  final IconData icon;
  final String title;
  final String detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) => ListView(children: [
        const SizedBox(height: 100),
        Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Center(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
        Padding(padding: const EdgeInsets.all(20), child: Text(detail, textAlign: TextAlign.center)),
        if (action != null) Center(child: action!),
      ]);
}

class _OrderFormDialog extends StatefulWidget {
  const _OrderFormDialog({required this.repository});
  final OrdersRepository repository;

  @override
  State<_OrderFormDialog> createState() => _OrderFormDialogState();
}

class _OrderFormDialogState extends State<_OrderFormDialog> {
  final _key = GlobalKey<FormState>();
  final _customer = TextEditingController();
  final _contact = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  DateTime? _dueDate;
  bool _saving = false;
  bool _attempted = false;
  late final String _requestId = createUuidV4();

  @override
  void dispose() {
    _customer.dispose();
    _contact.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? today,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 10),
      locale: const Locale('es', 'MX'),
    );
    if (date != null) setState(() => _dueDate = date);
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _attempted = true);
    setState(() => _saving = true);
    try {
      await widget.repository.createOrder(
        customerName: _customer.text.trim(),
        customerContact: _contact.text.trim().isEmpty ? null : _contact.text.trim(),
        description: _description.text.trim(),
        agreedPrice: double.parse(_price.text.trim().replaceAll(',', '.')),
        deposit: 0,
        dueDate: _dueDate,
        requestId: _requestId,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo crear el pedido: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Nuevo pedido personalizado'),
        content: SizedBox(
          width: 430,
          child: Form(
            key: _key,
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(controller: _customer, readOnly: _attempted, decoration: const InputDecoration(labelText: 'Nombre de cliente'), validator: (v) => v == null || v.trim().isEmpty ? 'Escribe el nombre del cliente' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _contact, readOnly: _attempted, decoration: const InputDecoration(labelText: 'Contacto (opcional)'), keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              TextFormField(controller: _description, readOnly: _attempted, decoration: const InputDecoration(labelText: 'Descripción del pedido'), maxLines: 3, validator: (v) => v == null || v.trim().isEmpty ? 'Describe el pedido' : null),
              const SizedBox(height: 12),
              TextFormField(
                controller: _price,
                readOnly: _attempted,
                decoration: const InputDecoration(labelText: 'Precio acordado'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final amount = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
                  return amount == null || amount <= 0 ? 'Escribe un precio mayor a cero' : null;
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(_dueDate == null ? 'Agregar fecha de entrega' : DateFormat('d MMMM yyyy', 'es_MX').format(_dueDate!)),
                trailing: _dueDate == null ? null : IconButton(onPressed: () => setState(() => _dueDate = null), icon: const Icon(Icons.close)),
                onTap: _attempted ? null : _pickDate,
              ),
              const SizedBox(height: 4),
              Text('Registra el anticipo o los abonos después de crear el pedido; se guardarán en el historial de pagos.', style: Theme.of(context).textTheme.bodySmall),
            ])),
          ),
        ),
        actions: [
          TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_attempted ? 'Reintentar' : 'Guardar pedido')),
        ],
      );
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({required this.order, required this.repository});
  final CustomOrder order;
  final OrdersRepository repository;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _key = GlobalKey<FormState>();
  final _amount = TextEditingController();
  String _method = 'EFECTIVO';
  bool _saving = false;
  bool _attempted = false;
  late final String _requestId = createUuidV4();

  @override
  void dispose() { _amount.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _attempted = true);
    setState(() => _saving = true);
    try {
      await widget.repository.recordPayment(
        orderId: widget.order.id,
        amount: double.parse(_amount.text.trim().replaceAll(',', '.')),
        paymentMethod: _method,
        requestId: _requestId,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo registrar el abono: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Registrar abono'),
        content: Form(
          key: _key,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Align(alignment: Alignment.centerLeft, child: Text('Saldo pendiente: ${NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(widget.order.balance)}')),
            const SizedBox(height: 14),
            TextFormField(
              controller: _amount,
              readOnly: _attempted,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Cantidad recibida'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                final amount = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
                if (amount == null || amount <= 0) return 'Escribe una cantidad válida';
                if (amount > widget.order.balance) return 'No puede superar el saldo';
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'Método de pago'),
              items: const [
                DropdownMenuItem(value: 'EFECTIVO', child: Text('Efectivo')),
                DropdownMenuItem(value: 'TRANSFERENCIA', child: Text('Transferencia')),
                DropdownMenuItem(value: 'TARJETA', child: Text('Tarjeta')),
                DropdownMenuItem(value: 'OTRO', child: Text('Otro')),
              ],
              onChanged: _saving || _attempted ? null : (value) { if (value != null) setState(() => _method = value); },
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_attempted ? 'Reintentar' : 'Registrar')),
        ],
      );
}
