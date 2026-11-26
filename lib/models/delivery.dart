import '../core/utils/gbp.dart';
import '../core/utils/london_time.dart';

enum DeliveryStatus {
  assigned('Assigned'),
  out('Out for delivery'),
  delivered('Delivered'),
  failed('Failed'),
  unknown('Status unavailable');

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
    this.phone,
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
      cashOnDelivery: switch ((json['currency'], json['paymentMode'])) {
        ('GBP', 'cash') => true,
        ('GBP', 'paid') => false,
        _ => null,
      },
      orderTotal: poundsToPence(json['amount']),
      status: switch (json['status']) {
        'assigned' => DeliveryStatus.assigned,
        'out' => DeliveryStatus.out,
        'delivered' => DeliveryStatus.delivered,
        'failed' => DeliveryStatus.failed,
        _ => DeliveryStatus.unknown,
      },
      scheduledAt: parseDeliveryTime(json['scheduledAt']),
      phone: _phoneFromJson(json['phone']),
    );
  }

  final int id;
  final String customerName;
  final String street;
  final String area;
  final String? landmark;
  final int itemCount;
  final bool? cashOnDelivery;
  final int? orderTotal;
  final DeliveryStatus status;
  final DateTime? scheduledAt;
  final String? phone;

  bool get isDelivered => status == DeliveryStatus.delivered;
  bool get canComplete =>
      status == DeliveryStatus.assigned || status == DeliveryStatus.out;

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
    phone: phone,
  );
}

class DeliveryDetails {
  const DeliveryDetails({
    required this.delivery,
    required this.cashDue,
    required this.notes,
  });

  factory DeliveryDetails.fromJson(Map<String, dynamic> json) =>
      DeliveryDetails(
        delivery: Delivery.fromJson(json),
        cashDue: poundsToPence(json['cashDue']),
        notes: (json['notes'] as String?)?.trim() ?? '',
      );

  final Delivery delivery;
  factory DeliveryDetails.fromSummary(Delivery delivery) => DeliveryDetails(
    delivery: delivery,
    cashDue: switch (delivery.cashOnDelivery) {
      true => delivery.orderTotal,
      false => 0,
      null => null,
    },
    notes: '',
  );

  final int? cashDue;
  final String notes;

  bool get hasVerifiedPayment => switch (delivery.cashOnDelivery) {
    true => cashDue != null,
    false => cashDue == 0,
    null => false,
  };

  DeliveryDetails copyWith({Delivery? delivery, int? cashDue}) =>
      DeliveryDetails(
        delivery: delivery ?? this.delivery,
        cashDue: cashDue ?? this.cashDue,
        notes: notes,
      );
}

String? _phoneFromJson(Object? value) => value is String ? value.trim() : null;
