class OrderPayment {
  const OrderPayment({required this.amount, required this.paidAt, required this.paymentMethod});

  final double amount;
  final DateTime? paidAt;
  final String paymentMethod;

  factory OrderPayment.fromJson(Map<String, dynamic> json) => OrderPayment(
        amount: (json['amount'] as num).toDouble(),
        paidAt: DateTime.tryParse(json['paid_at'] as String? ?? ''),
        paymentMethod: json['payment_method'] as String? ?? 'OTRO',
      );
}

class CustomOrder {
  const CustomOrder({
    required this.id,
    required this.customerName,
    required this.description,
    required this.agreedPrice,
    required this.deposit,
    required this.status,
    required this.payments,
    this.customerContact,
    this.dueDate,
  });

  final String id;
  final String customerName;
  final String description;
  final String? customerContact;
  final double agreedPrice;
  final double deposit;
  final String status;
  final DateTime? dueDate;
  final List<OrderPayment> payments;

  double get paidAmount => deposit + payments.fold<double>(0, (sum, payment) => sum + payment.amount);
  double get balance => (agreedPrice - paidAmount).clamp(0, double.infinity).toDouble();

  factory CustomOrder.fromJson(Map<String, dynamic> json) {
    final rawPayments = json['order_payments'] as List<dynamic>? ?? const [];
    return CustomOrder(
      id: json['id'] as String,
      customerName: json['customer_name'] as String,
      description: json['description'] as String,
      customerContact: json['customer_contact'] as String?,
      agreedPrice: (json['agreed_price'] as num).toDouble(),
      deposit: (json['deposit'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'PENDING',
      dueDate: DateTime.tryParse(json['due_date'] as String? ?? ''),
      payments: rawPayments
          .map((payment) => OrderPayment.fromJson(payment as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}
