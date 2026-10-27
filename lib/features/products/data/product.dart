class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.isPublished,
    required this.isCustomOrderable,
    this.description,
    this.category,
    this.imageUrl,
  });

  final String id;
  final String name;
  final double price;
  final int stock;
  final bool isPublished;
  final bool isCustomOrderable;
  final String? description;
  final String? category;
  final String? imageUrl;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        stock: json['stock'] as int,
        isPublished: json['is_published'] as bool? ?? false,
        isCustomOrderable: json['is_custom_orderable'] as bool? ?? false,
        description: json['description'] as String?,
        category: json['category'] as String?,
        imageUrl: json['image_url'] as String?,
      );
}
