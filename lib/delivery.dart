import 'package:timezone/data/latest_10y.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

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
}

int poundsToPence(num pounds) => (pounds * 100).round();

String formatGbp(int pence) =>
    '£${pence ~/ 100}.${(pence % 100).toString().padLeft(2, '0')}';

final _cashPattern = RegExp(r'^([0-9]{1,9})(?:[.,]([0-9]{1,2}))?$');

int? parseCashPence(String input) {
  final match = _cashPattern.firstMatch(input.trim());
  if (match == null) return null;
  final pounds = int.parse(match[1]!);
  final pence = int.parse((match[2] ?? '').padRight(2, '0'));
  return pounds * 100 + pence;
}

final _london = (() {
  tz_data.initializeTimeZones();
  return tz.getLocation('Europe/London');
})();

String londonTime(DateTime time) {
  final london = tz.TZDateTime.from(time, _london);
  return '${london.hour.toString().padLeft(2, '0')}:'
      '${london.minute.toString().padLeft(2, '0')}';
}
