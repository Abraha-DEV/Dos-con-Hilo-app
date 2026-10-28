import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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
    final saved = kIsWeb
        ? await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => _ProductFormDialog(
                product: product,
                repository: _repository,
                fullPage: true,
              ),
            ),
          )
        : await showDialog<bool>(
            context: context,
            builder: (_) => _ProductFormDialog(
              product: product,
              repository: _repository,
              fullPage: false,
            ),
          );
    if (saved == true && mounted) setState(_load);
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text(
          '¿Quieres eliminar “${product.name}”? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.deleteProduct(product.id);
      if (mounted) setState(_load);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $error')));
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
        leading: IconButton(
          tooltip: 'Volver al resumen',
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Productos'),
        actions: [
          IconButton(
            tooltip: 'Agregar producto',
            onPressed: () => _editProduct(),
            icon: const Icon(Icons.add),
          ),
        ],
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
              return ListView(
                children: [
                  const SizedBox(height: 100),
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 42,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'No se pudieron cargar los productos',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Center(
                    child: TextButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ),
                ],
              );
            }
            final products = snapshot.data ?? const <Product>[];
            if (products.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.inventory_2_outlined, size: 48),
                  SizedBox(height: 12),
                  Center(
                    child: Text('Todavía no hay productos para este negocio.'),
                  ),
                ],
              );
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
  const _ProductTile({
    required this.product,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
  });

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
                ? ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.local_mall_outlined),
                  )
                : Image.network(
                    product.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
          ),
        ),
        title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${product.category ?? 'General'} · Existencia: ${product.stock}\n${product.isPublished ? 'Publicado' : 'Borrador'}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currency.format(product.price),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar')),
                PopupMenuItem(value: 'delete', child: Text('Eliminar')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({
    required this.product,
    required this.repository,
    required this.fullPage,
  });

  final Product? product;
  final ProductsRepository repository;
  final bool fullPage;

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
  final _imagePicker = ImagePicker();
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _existingImageUrl;
  bool _removeImage = false;
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
    _price = TextEditingController(
      text: product?.price.toStringAsFixed(2) ?? '',
    );
    _stock = TextEditingController(text: product?.stock.toString() ?? '0');
    _existingImageUrl = product?.imageUrl;
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
    super.dispose();
  }

  Future<void> _chooseImage(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1800,
        imageQuality: 86,
      );
      if (image != null && mounted) {
        await _setSelectedImage(image);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir la imagen: $error')),
        );
      }
    }
  }

  Future<void> _setSelectedImage(XFile image) async {
    try {
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedImage = image;
        _selectedImageBytes = bytes;
        _removeImage = false;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo leer la fotografía: $error')),
        );
      }
    }
  }

  Future<void> _chooseWebImage() async {
    try {
      final image = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Imágenes', webWildCards: ['image/*']),
        ],
      );
      if (image != null && mounted) await _setSelectedImage(image);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo seleccionar la imagen: $error')),
        );
      }
    }
  }

  Future<void> _showImageSources() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar una foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _chooseImage(source);
  }

  String _imageContentType(String fileName) {
    switch (fileName.split('.').last.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      String? imageUrl = _removeImage ? null : _existingImageUrl;
      if (_selectedImage case final image?) {
        imageUrl = await widget.repository.uploadProductImage(
          fileName: image.name,
          bytes: _selectedImageBytes!,
          contentType: _imageContentType(image.name),
        );
      }
      final values = {
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'category': _category.text.trim().isEmpty
            ? 'General'
            : _category.text.trim(),
        'price': double.parse(_price.text.trim().replaceAll(',', '.')),
        'stock': int.parse(_stock.text.trim()),
        'imageUrl': imageUrl,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar el producto: $error')),
        );
      }
    }
  }

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? 'Escribe $label' : null;

  @override
  Widget build(BuildContext context) {
    final editing = widget.product != null;
    final form = Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (value) => _required(value, 'un nombre'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Descripción'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _category,
              decoration: const InputDecoration(labelText: 'Categoría'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    decoration: const InputDecoration(labelText: 'Precio'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      final parsed = double.tryParse(
                        (value ?? '').trim().replaceAll(',', '.'),
                      );
                      return parsed == null || parsed < 0
                          ? 'Precio inválido'
                          : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _stock,
                    decoration: const InputDecoration(labelText: 'Existencia'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final parsed = int.tryParse((value ?? '').trim());
                      return parsed == null || parsed < 0
                          ? 'Cantidad inválida'
                          : null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Fotografía del producto',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 84,
                    height: 84,
                    child: _selectedImage != null
                        ? Image.memory(_selectedImageBytes!, fit: BoxFit.cover)
                        : (!_removeImage &&
                                  _existingImageUrl != null &&
                                  _existingImageUrl!.isNotEmpty
                              ? Image.network(
                                  _existingImageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.broken_image_outlined),
                                )
                              : const ColoredBox(
                                  color: Color(0xFFF2EEE8),
                                  child: Icon(Icons.image_outlined),
                                )),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (kIsWeb) ...[
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _chooseWebImage,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Elegir archivo'),
                        ),
                      ] else if (defaultTargetPlatform ==
                          TargetPlatform.linux) ...[
                        OutlinedButton.icon(
                          onPressed: _saving
                              ? null
                              : () => _chooseImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Elegir archivo'),
                        ),
                      ] else
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _showImageSources,
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: const Text('Elegir o tomar foto'),
                        ),
                      if (_selectedImage != null ||
                          (_existingImageUrl?.isNotEmpty ?? false))
                        TextButton.icon(
                          onPressed: _saving
                              ? null
                              : () => setState(() {
                                  _selectedImage = null;
                                  _selectedImageBytes = null;
                                  _removeImage = true;
                                }),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Quitar foto'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Publicado en el catálogo'),
              value: _published,
              onChanged: (value) => setState(() => _published = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Acepta pedido personalizado'),
              value: _customOrderable,
              onChanged: (value) => setState(() => _customOrderable = value),
            ),
          ],
        ),
      ),
    );
    final actions = [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Guardar'),
      ),
    ];

    if (widget.fullPage) {
      return Scaffold(
        appBar: AppBar(
          title: Text(editing ? 'Editar producto' : 'Nuevo producto'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Card(
                child: Padding(padding: const EdgeInsets.all(24), child: form),
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions,
            ),
          ),
        ),
      );
    }

    return AlertDialog(
      title: Text(editing ? 'Editar producto' : 'Nuevo producto'),
      content: SizedBox(width: 440, child: form),
      actions: actions,
    );
  }
}
