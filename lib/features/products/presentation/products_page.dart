import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/product.dart';
import '../data/products_repository.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  late Future<List<Product>> _products;
  final _currency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  late final ProductsRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = ProductsRepository(Supabase.instance.client);
    _load();
  }

  void _load() {
    _products = _repository.fetchProducts();
  }

  Future<void> _editProduct([Product? product]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ProductFormDialog(product: product, repository: _repository),
    );
    if (saved == true && mounted) setState(_load);
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Quieres eliminar “${product.name}”? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.deleteProduct(product.id);
      if (mounted) setState(_load);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo eliminar: $error')),
        );
      }
    }
  }

  Future<void> _refresh() async {
    setState(_load);
    await _products;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: 'Volver al resumen', onPressed: () => context.go('/'), icon: const Icon(Icons.arrow_back)),
        title: const Text('Productos'),
        actions: [IconButton(tooltip: 'Agregar producto', onPressed: () => _editProduct(), icon: const Icon(Icons.add))],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Product>>(
          future: _products,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(children: [
                const SizedBox(height: 100),
                Icon(Icons.cloud_off_outlined, size: 42, color: theme.colorScheme.error),
                const SizedBox(height: 12),
                Center(child: Text('No se pudieron cargar los productos', style: theme.textTheme.titleMedium)),
                Padding(padding: const EdgeInsets.all(20), child: Text('${snapshot.error}', textAlign: TextAlign.center)),
                Center(child: TextButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Reintentar'))),
              ]);
            }
            final products = snapshot.data ?? const <Product>[];
            if (products.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 120),
                Icon(Icons.inventory_2_outlined, size: 48),
                SizedBox(height: 12),
                Center(child: Text('Todavía no hay productos para este negocio.')),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _ProductTile(
                product: products[index],
                currency: _currency,
                onEdit: () => _editProduct(products[index]),
                onDelete: () => _deleteProduct(products[index]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product, required this.currency, required this.onEdit, required this.onDelete});

  final Product product;
  final NumberFormat currency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 58,
            height: 58,
            child: product.imageUrl == null || product.imageUrl!.isEmpty
                ? ColoredBox(color: theme.colorScheme.surfaceContainerHighest, child: const Icon(Icons.local_mall_outlined))
                : Image.network(product.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
          ),
        ),
        title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${product.category ?? 'General'} · Existencia: ${product.stock}\n${product.isPublished ? 'Publicado' : 'Borrador'}'),
        isThreeLine: true,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(currency.format(product.price), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          PopupMenuButton<String>(
            onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Editar')),
              PopupMenuItem(value: 'delete', child: Text('Eliminar')),
            ],
          ),
        ]),
      ),
    );
  }
}

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({required this.product, required this.repository});

  final Product? product;
  final ProductsRepository repository;

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _category;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _imageUrl;
  late bool _published;
  late bool _customOrderable;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name ?? '');
    _description = TextEditingController(text: product?.description ?? '');
    _category = TextEditingController(text: product?.category ?? 'General');
    _price = TextEditingController(text: product?.price.toStringAsFixed(2) ?? '');
    _stock = TextEditingController(text: product?.stock.toString() ?? '0');
    _imageUrl = TextEditingController(text: product?.imageUrl ?? '');
    _published = product?.isPublished ?? true;
    _customOrderable = product?.isCustomOrderable ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _category.dispose();
    _price.dispose();
    _stock.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final values = {
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'category': _category.text.trim().isEmpty ? 'General' : _category.text.trim(),
        'price': double.parse(_price.text.trim().replaceAll(',', '.')),
        'stock': int.parse(_stock.text.trim()),
        'imageUrl': _imageUrl.text.trim().isEmpty ? null : _imageUrl.text.trim(),
        'isPublished': _published,
        'isCustomOrderable': _customOrderable,
      };
      if (widget.product == null) {
        await widget.repository.createProduct(
          name: values['name']! as String,
          description: values['description']! as String,
          category: values['category']! as String,
          price: values['price']! as double,
          stock: values['stock']! as int,
          imageUrl: values['imageUrl'] as String?,
          isPublished: values['isPublished']! as bool,
          isCustomOrderable: values['isCustomOrderable']! as bool,
        );
      } else {
        await widget.repository.updateProduct(
          id: widget.product!.id,
          name: values['name']! as String,
          description: values['description']! as String,
          category: values['category']! as String,
          price: values['price']! as double,
          stock: values['stock']! as int,
          imageUrl: values['imageUrl'] as String?,
          isPublished: values['isPublished']! as bool,
          isCustomOrderable: values['isCustomOrderable']! as bool,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar el producto: $error')));
      }
    }
  }

  String? _required(String? value, String label) => value == null || value.trim().isEmpty ? 'Escribe $label' : null;

  @override
  Widget build(BuildContext context) {
    final editing = widget.product != null;
    return AlertDialog(
      title: Text(editing ? 'Editar producto' : 'Nuevo producto'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre'), validator: (value) => _required(value, 'un nombre')),
              const SizedBox(height: 12),
              TextFormField(controller: _description, decoration: const InputDecoration(labelText: 'Descripción'), maxLines: 2),
              const SizedBox(height: 12),
              TextFormField(controller: _category, decoration: const InputDecoration(labelText: 'Categoría')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(
                  controller: _price,
                  decoration: const InputDecoration(labelText: 'Precio'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    final parsed = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
                    return parsed == null || parsed < 0 ? 'Precio inválido' : null;
                  },
                )),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(
                  controller: _stock,
                  decoration: const InputDecoration(labelText: 'Existencia'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final parsed = int.tryParse((value ?? '').trim());
                    return parsed == null || parsed < 0 ? 'Cantidad inválida' : null;
                  },
                )),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                controller: _imageUrl,
                decoration: const InputDecoration(labelText: 'URL de fotografía'),
                keyboardType: TextInputType.url,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  return Uri.tryParse(value.trim())?.hasAbsolutePath == true && value.trim().startsWith('https://')
                      ? null
                      : 'Usa una URL https válida';
                },
              ),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Publicado en el catálogo'), value: _published, onChanged: (value) => setState(() => _published = value)),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Acepta pedido personalizado'), value: _customOrderable, onChanged: (value) => setState(() => _customOrderable = value)),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Guardar')),
      ],
    );
  }
}
