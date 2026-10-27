class SaleLine {
  const SaleLine({required this.quantity, required this.unitPrice, this.productName});
  final int quantity;
  final double unitPrice;
  final String? productName;
  double get total => quantity * unitPrice;

  factory SaleLine.fromJson(Map<String, dynamic> json) {
    final product = json['products'] as Map<String, dynamic>?;
    return SaleLine(
      quantity: json['quantity'] as int,
      unitPrice: (json['unit_price'] as num).toDouble(),
      productName: product?['name'] as String?,
    );
  }
}

class Sale {
  const Sale({required this.id, required this.channel, required this.paymentMethod, required this.total, required this.status, required this.createdAt, required this.items});

  final String id;
  final String channel;
  final String paymentMethod;
  final double total;
  final String status;
  final DateTime? createdAt;
  final List<SaleLine> items;

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
        id: json['id'] as String,
        channel: json['sale_channel'] as String,
        paymentMethod: json['payment_method'] as String,
        total: (json['total'] as num).toDouble(),
        status: json['status'] as String? ?? 'COMPLETED',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
        items: (json['sale_items'] as List<dynamic>? ?? const [])
            .map((item) => SaleLine.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
      );
}
