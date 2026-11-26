import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/home_controller.dart';
import '../core/shared/screen_message.dart';
import '../core/theme/courier_theme.dart';
import '../core/utils/gbp.dart';
import '../core/utils/london_time.dart';
import '../models/completion_record.dart';
import '../models/delivery.dart';
import '../services/completion_queue.dart';
import '../services/courier_api.dart';
import 'delivery_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api, required this.queue});

  final CourierApi api;
  final CompletionQueue queue;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController _controller;
  bool _openingDelivery = false;

  @override
  void initState() {
    super.initState();
    _controller = HomeController(widget.api)..loadDeliveries();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openDelivery(int id, {Delivery? summary}) async {
    if (_openingDelivery) return;
    _openingDelivery = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => DeliveryDetailScreen(
            api: widget.api,
            queue: widget.queue,
            id: id,
            summary: summary,
            onChange: _controller.updateDelivery,
          ),
        ),
      );
    } finally {
      _openingDelivery = false;
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_controller, widget.queue]),
    builder: (_, _) => _buildScreen(),
  );

  Widget _buildScreen() => Scaffold(
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
          onPressed: _controller.isLoading ? null : _refresh,
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          _buildQueueSummary(),
          Expanded(child: _buildBody()),
        ],
      ),
    ),
  );

  void _refresh() {
    unawaited(widget.queue.sync());
    unawaited(_controller.loadDeliveries());
  }

  Widget _buildQueueSummary() {
    final pending = widget.queue.records
        .where((record) => !record.needsReview)
        .length;
    final review = widget.queue.records.length - pending;
    final labels = [
      if (pending > 0) '$pending waiting to sync',
      if (review > 0) '$review need review',
      if (widget.queue.storageError) 'Saved handovers could not be opened',
    ];
    if (labels.isEmpty) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
        child: Text(
          labels.join(' · '),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildOrphanRecord(CompletionRecord record) => ListTile(
    title: Text('Delivery #${record.id}'),
    subtitle: Text(record.needsReview ? 'Needs review' : 'Waiting to sync'),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => _openDelivery(record.id),
  );

  Widget _buildBody() {
    final deliveries = _controller.deliveries;
    final deliveryIds = deliveries?.map((delivery) => delivery.id).toSet();
    final orphans = widget.queue.records
        .where((record) => deliveryIds?.contains(record.id) != true)
        .toList();
    if (deliveries == null || deliveries.isEmpty) {
      final status = deliveries == null
          ? _controller.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Loading deliveries',
                    ),
                  )
                : ScreenMessage(
                    icon: Icons.cloud_off_outlined,
                    title: 'Couldn’t load deliveries',
                    description: 'Check your connection and try again.',
                    retry: _refresh,
                  )
          : ScreenMessage(
              icon: Icons.inventory_2_outlined,
              title: 'No deliveries today',
              retry: _refresh,
            );
      if (orphans.isEmpty) return status;
      return Column(
        children: [
          Expanded(child: status),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: orphans.length,
              itemBuilder: (_, index) => _buildOrphanRecord(orphans[index]),
            ),
          ),
        ],
      );
    }

    final routeDate = _controller.routeDate;
    final day = routeDate == null ? null : londonDay(routeDate);
    final today = <Delivery>[];
    final earlier = <Delivery>[];
    final upcoming = <Delivery>[];
    final unscheduled = <Delivery>[];
    for (final delivery in deliveries) {
      final due = delivery.scheduledAt;
      if (day == null) {
        today.add(delivery);
      } else if (due == null) {
        unscheduled.add(delivery);
      } else {
        final dueDay = londonDay(due);
        if (dueDay < day) {
          earlier.add(delivery);
        } else if (dueDay > day) {
          upcoming.add(delivery);
        } else {
          today.add(delivery);
        }
      }
    }
    final deliveredCount = today.where(_isDelivered).length;
    final rows = <Object>[
      if (_controller.refreshFailed)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('Couldn’t refresh. Showing the last loaded deliveries.'),
        ),
      _RouteSummary(delivered: deliveredCount, total: today.length),
      ...today,
      if (earlier.isNotEmpty) ...['Earlier deliveries', ...earlier],
      if (upcoming.isNotEmpty) ...['Upcoming deliveries', ...upcoming],
      if (unscheduled.isNotEmpty) ...[
        'Deliveries without a due time',
        ...unscheduled,
      ],
      for (final record in orphans) _buildOrphanRecord(record),
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: switch (row) {
            final Delivery delivery => _DeliveryTile(
              delivery: delivery,
              delivered: _isDelivered(delivery),
              completion: widget.queue.recordFor(delivery.id),
              showDate: day != null && !today.contains(delivery),
              onTap: () => _openDelivery(delivery.id, summary: delivery),
            ),
            final String heading => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Semantics(
                header: true,
                child: Text(
                  heading,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            _ => row as Widget,
          },
        );
      },
    );
  }

  bool _isDelivered(Delivery delivery) =>
      widget.queue.recordFor(delivery.id) == null &&
      (delivery.isDelivered || widget.queue.isConfirmed(delivery.id));
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
            value: total == 0 ? 0 : delivered / total,
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
  const _DeliveryTile({
    required this.delivery,
    required this.delivered,
    required this.completion,
    required this.showDate,
    required this.onTap,
  });

  final Delivery delivery;
  final bool delivered;
  final CompletionRecord? completion;
  final bool showDate;
  final VoidCallback onTap;

  String get _timeLabel {
    final time = delivery.scheduledAt;
    if (time == null) return 'Time unavailable';
    return showDate
        ? '${londonDate(time)} · ${londonTime(time)}'
        : londonTime(time);
  }

  String get _statusLabel {
    if (completion case final CompletionRecord record) {
      return record.needsReview ? 'Needs review' : 'Waiting to sync';
    }
    if (delivered) return 'Delivered';
    if (!delivery.canComplete) return delivery.status.label;
    return switch ((delivery.cashOnDelivery, delivery.orderTotal)) {
      (true, final int amount) => '${formatGbp(amount)} cash',
      (false, _) => 'Paid online',
      _ => 'Payment unavailable',
    };
  }

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
                color: delivered ? softGreen : canvas,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                delivered ? Icons.check : Icons.inventory_2_outlined,
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
                        _timeLabel,
                        style: const TextStyle(
                          color: mutedInk,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _statusLabel,
                        style: TextStyle(
                          color: delivered ? forest : ink,
                          fontWeight: FontWeight.w700,
                        ),
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
