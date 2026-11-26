import '../core/utils/gbp.dart';

enum DeliveryStatus {
  assigned('Assigned'),
  out('Out for delivery'),
  delivered('Delivered');

  const DeliveryStatus(this.label);

  final String label;
}

class Delivery {
  const Delivery({
    required this.id,
    required this.customerName,
    required this.street,
    required this.area,
    required this.landmark,
    required this.itemCount,
    required this.cashOnDelivery,
    required this.orderTotal,
    required this.status,
    required this.scheduledAt,
  });

  factory Delivery.fromJson(Map<String, dynamic> json) {
    final address = json['address'] as Map<String, dynamic>;
    return Delivery(
      id: json['id'] as int,
      customerName: json['customerName'] as String,
      street: address['line1'] as String,
      area: address['area'] as String,
      landmark: address['landmark'] as String?,
      itemCount: json['items'] as int,
      cashOnDelivery: json['paymentMode'] == 'cash',
      orderTotal: poundsToPence(json['amount'] as num),
      status: DeliveryStatus.values.byName(json['status'] as String),
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
    );
  }

  final int id;
  final String customerName;
  final String street;
  final String area;
  final String? landmark;
  final int itemCount;
  final bool cashOnDelivery;
  final int orderTotal;
  final DeliveryStatus status;
  final DateTime scheduledAt;

  bool get isDelivered => status == DeliveryStatus.delivered;

  Delivery asDelivered() => Delivery(
    id: id,
    customerName: customerName,
    street: street,
    area: area,
    landmark: landmark,
    itemCount: itemCount,
    cashOnDelivery: cashOnDelivery,
    orderTotal: orderTotal,
    status: DeliveryStatus.delivered,
    scheduledAt: scheduledAt,
  );
}

class DeliveryDetails {
  const DeliveryDetails({
    required this.delivery,
    required this.phone,
    required this.cashDue,
    required this.notes,
  });

  factory DeliveryDetails.fromJson(Map<String, dynamic> json) =>
      DeliveryDetails(
        delivery: Delivery.fromJson(json),
        phone: json['phone'] as String,
        cashDue: poundsToPence(json['cashDue'] as num),
        notes: (json['notes'] as String?)?.trim() ?? '',
      );

  final Delivery delivery;
  final String phone;
  final int cashDue;
  final String notes;

  DeliveryDetails copyWith({Delivery? delivery, int? cashDue}) =>
      DeliveryDetails(
        delivery: delivery ?? this.delivery,
        phone: phone,
        cashDue: cashDue ?? this.cashDue,
        notes: notes,
      );
}
