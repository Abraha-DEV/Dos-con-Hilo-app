class InventoryMovement {
  const InventoryMovement({required this.id, required this.quantity, required this.type, required this.createdAt, this.reason, this.productName});
  final String id;
  final int quantity;
  final String type;
  final DateTime? createdAt;
  final String? reason;
  final String? productName;

  factory InventoryMovement.fromJson(Map<String, dynamic> json) {
    final product = json['products'] as Map<String, dynamic>?;
    return InventoryMovement(
      id: json['id'] as String,
      quantity: json['quantity'] as int,
      type: json['movement_type'] as String,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      reason: json['reason'] as String?,
      productName: product?['name'] as String?,
    );
  }
}
