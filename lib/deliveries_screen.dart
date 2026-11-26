import 'package:flutter/material.dart';

import 'courier_api.dart';
import 'courier_theme.dart';
import 'delivery.dart';
import 'delivery_screen.dart';

class DeliveriesScreen extends StatefulWidget {
  const DeliveriesScreen({super.key, required this.api});

  final CourierApi api;

  @override
  State<DeliveriesScreen> createState() => _DeliveriesScreenState();
}

class _DeliveriesScreenState extends State<DeliveriesScreen> {
  List<Delivery>? _deliveries;
  bool _loading = true;
  bool _openingDelivery = false;

  @override
  void initState() {
    super.initState();
    _fetchDeliveries();
  }

  Future<void> _fetchDeliveries() async {
    List<Delivery>? deliveries;
    try {
      deliveries = await widget.api.fetchDeliveries();
    } catch (_) {
      // A failed page leaves the route incomplete. Offer a full retry.
    }
    if (!mounted) return;
    setState(() {
      _deliveries = deliveries;
      _loading = false;
    });
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() => _loading = true);
    await _fetchDeliveries();
  }

  Future<void> _openDelivery(Delivery delivery) async {
    if (_openingDelivery) return;
    _openingDelivery = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => DeliveryScreen(
            api: widget.api,
            id: delivery.id,
            onChange: (updated) {
              if (!mounted) return;
              setState(() {
                _deliveries = [
                  for (final item in _deliveries!)
                    item.id == updated.id ? updated : item,
                ];
              });
            },
          ),
        ),
      );
    } finally {
      _openingDelivery = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: lime,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.pedal_bike_rounded, size: 23),
          ),
          const SizedBox(width: 10),
          const Flexible(
            child: Text(
              'kerbwise',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.9,
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh deliveries',
          onPressed: _loading ? null : _refresh,
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: SafeArea(top: false, child: _buildBody(context)),
  );

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Loading deliveries'),
      );
    }

    final deliveries = _deliveries;
    if (deliveries == null) {
      return ScreenMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Couldn’t load deliveries',
        description: 'Check your connection and try again.',
        retry: _refresh,
      );
    }

    if (deliveries.isEmpty) {
      return ScreenMessage(
        icon: Icons.inventory_2_outlined,
        title: 'No deliveries today',
        retry: _refresh,
      );
    }

    final deliveredCount = deliveries
        .where((delivery) => delivery.isDelivered)
        .length;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: deliveries.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _RouteSummary(
              delivered: deliveredCount,
              total: deliveries.length,
            ),
          );
        }
        final delivery = deliveries[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _DeliveryTile(
            delivery: delivery,
            onTap: () => _openDelivery(delivery),
          ),
        );
      },
    );
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.delivered, required this.total});

  final int delivered;
  final int total;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 21, 20, 22),
    decoration: BoxDecoration(
      color: forest,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: const Text(
            'Today’s deliveries',
            style: TextStyle(
              fontSize: 30,
              height: 1.1,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '$delivered of $total delivered',
          style: const TextStyle(
            fontSize: 15,
            color: lime,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ExcludeSemantics(
          child: LinearProgressIndicator(
            value: delivered / total,
            minHeight: 6,
            color: lime,
            backgroundColor: const Color(0xFF577360),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ],
    ),
  );
}

class _DeliveryTile extends StatelessWidget {
  const _DeliveryTile({required this.delivery, required this.onTap});

  final Delivery delivery;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: line),
      borderRadius: BorderRadius.circular(16),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: delivery.isDelivered ? softGreen : canvas,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                delivery.isDelivered ? Icons.check : Icons.inventory_2_outlined,
                color: forest,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    delivery.customerName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${delivery.street}, ${delivery.area}',
                    style: const TextStyle(color: mutedInk),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 2,
                    children: [
                      Text(
                        londonTime(delivery.scheduledAt),
                        style: const TextStyle(
                          color: mutedInk,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (delivery.isDelivered)
                        const Text(
                          'Delivered',
                          style: TextStyle(
                            color: forest,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else if (delivery.cashOnDelivery)
                        Text(
                          '${formatGbp(delivery.orderTotal)} cash',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        )
                      else
                        const Text(
                          'Paid online',
                          style: TextStyle(color: mutedInk),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: mutedInk, size: 22),
          ],
        ),
      ),
    ),
  );
}
