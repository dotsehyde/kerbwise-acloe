# Pull request to review: the Delivered button (Flutter)

This is a pull request from Kwesi, a newer engineer on the team, on the courier app. Review it as you would on a client project. The repository is not included; the changed files are below. There is a React Native version of the same change in `courier-pr-rn.md`: review the one in the framework you built with.

---

**Title:** Add the Delivered button

**Description:**

Adds a Delivered button to each delivery. It removes the row straight away so the courier sees it work, then tells the server. It retries up to 5 times because the signal is bad. I also keep the list fresh by reloading every 2 seconds. Tested on my own phone and it works fine. I made the font smaller so everything fits.

**Files changed:** `lib/api.dart`, `lib/deliveries_page.dart`, `test/deliveries_test.dart`

---

## lib/api.dart

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

const baseUrl = 'http://10.0.2.2:4000';
const token = 'courier-demo-token';

class Delivery {
  final int id;
  final String customer;
  final double amount;
  final DateTime scheduledAt;
  final String phone;

  Delivery.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        customer = j['customerName'],
        amount = j['amount'] as double,
        scheduledAt = DateTime.parse(j['scheduledAt']),
        phone = j['phone'];
}

Future<List<Delivery>> fetchDeliveries() async {
  final res = await http.get(
    Uri.parse('$baseUrl/deliveries?limit=50&page=1'),
    headers: {'Authorization': 'Bearer $token'},
  );
  print(res.body);
  final data = jsonDecode(res.body);
  return (data['items'] as List).map((j) => Delivery.fromJson(j)).toList();
}

Future<bool> markDelivered(int id, double cash) async {
  for (var i = 0; i < 5; i++) {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/deliveries/$id/complete'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'cashCollected': cash,
          'deliveredAt': DateTime.now().toIso8601String(),
        }),
      );
      if (res.statusCode == 200) return true;
    } catch (e) {}
  }
  return false;
}
```

## lib/deliveries_page.dart

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'api.dart';

class DeliveriesPage extends StatefulWidget {
  const DeliveriesPage({super.key});

  @override
  State<DeliveriesPage> createState() => _DeliveriesPageState();
}

class _DeliveriesPageState extends State<DeliveriesPage> {
  List<Delivery> deliveries = [];
  Timer? timer;

  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds: 2), (_) => load());
  }

  Future<void> load() async {
    final d = await fetchDeliveries();
    setState(() => deliveries = d);
  }

  Future<void> deliver(Delivery d) async {
    setState(() => deliveries.remove(d));
    final ok = await markDelivered(d.id, d.amount);
    if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: deliveries
            .map((d) => ListTile(
                  title: Text(d.customer, style: const TextStyle(fontSize: 14)),
                  subtitle: Text('£${d.amount} • ${d.phone}'),
                  trailing: ElevatedButton(
                    onPressed: () => deliver(d),
                    child: const Text('Delivered'),
                  ),
                ))
            .toList(),
      ),
    );
  }
}
```

## test/deliveries_test.dart

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:courier/deliveries_page.dart';

void main() {
  testWidgets('shows deliveries', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DeliveriesPage()));
    await Future.delayed(const Duration(seconds: 3));
    expect(find.byType(ListTile), findsWidgets);
  });
}
```
