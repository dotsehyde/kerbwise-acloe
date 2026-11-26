import 'package:flutter/material.dart';

import '../controllers/delivery_detail_controller.dart';
import '../core/shared/screen_message.dart';
import '../core/theme/courier_theme.dart';
import '../core/utils/gbp.dart';
import '../core/utils/london_time.dart';
import '../models/delivery.dart';
import '../services/completion_queue.dart';
import '../services/courier_api.dart';
import '../services/customer_dialer.dart';

class DeliveryDetailScreen extends StatefulWidget {
  const DeliveryDetailScreen({
    super.key,
    required this.api,
    required this.queue,
    required this.id,
    required this.onChange,
    this.summary,
  });

  final CourierApi api;
  final CompletionQueue queue;
  final int id;
  final ValueChanged<Delivery> onChange;
  final Delivery? summary;

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  late final DeliveryDetailController _controller;
  final _cash = TextEditingController();
  final _cashFocus = FocusNode();
  final _cashField = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = DeliveryDetailController(
      api: widget.api,
      queue: widget.queue,
      id: widget.id,
      onChange: widget.onChange,
      summary: widget.summary,
    )..loadDelivery();
  }

  @override
  void dispose() {
    _controller.dispose();
    _cash.dispose();
    _cashFocus.dispose();
    super.dispose();
  }

  Future<void> _markDelivered() async {
    if (_controller.isSubmitting) return;

    final attempt = _controller.markDelivered(_cash.text);
    if (_controller.isSubmitting) _cashFocus.unfocus();
    await attempt;

    if (!mounted || _controller.cashError == null) return;
    _cashFocus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_cashField.currentContext case final BuildContext field) {
        Scrollable.ensureVisible(
          field,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }

  Future<void> _callCustomer(String phone) async {
    final opened = await openCustomerDialer(phone);
    if (opened || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Couldn’t open the phone dialer.')),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (_, _) => PopScope(
      canPop: !_controller.isSubmitting,
      child: Scaffold(
        appBar: AppBar(title: Text('Delivery #${widget.id}')),
        body: SafeArea(top: false, child: _buildBody()),
      ),
    ),
  );

  Widget _buildBody() {
    if (_controller.isLoading) {
      return const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Loading delivery'),
      );
    }

    final details = _controller.details;
    if (details != null) return _buildDelivery(details);
    if (_controller.completion != null || _controller.isConfirmed) {
      return ScreenMessage(
        icon: Icons.inventory_2_outlined,
        title: _controller.isConfirmed
            ? 'Delivery completed'
            : 'Saved handover',
        description: _completionMessage(),
      );
    }
    if (_controller.isUnavailable) {
      return const ScreenMessage(
        icon: Icons.inventory_2_outlined,
        title: 'Delivery unavailable',
        description: 'Go back and refresh your deliveries.',
      );
    }
    return ScreenMessage(
      icon: Icons.cloud_off_outlined,
      title: 'Couldn’t load delivery',
      description: 'Check your connection and try again.',
      retry: _controller.loadDelivery,
    );
  }

  Widget _buildDelivery(DeliveryDetails details) {
    final delivery = details.delivery;
    final completion = _controller.completion;
    final statusLabel = completion == null
        ? delivery.status.label
        : completion.needsReview
        ? 'Needs review'
        : 'Waiting to sync';
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_controller.isCached)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text('Showing the last available details.'),
                  ),
                _DetailPanel(
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: delivery.isDelivered && completion == null
                              ? softGreen
                              : lime,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          child: Text(
                            statusLabel,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Semantics(
                      header: true,
                      child: Text(
                        delivery.customerName,
                        style: const TextStyle(
                          fontSize: 28,
                          height: 1.1,
                          letterSpacing: -0.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _IconText(
                      icon: Icons.location_on_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            delivery.street,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            delivery.area,
                            style: const TextStyle(color: mutedInk),
                          ),
                          if (delivery.landmark case final String landmark)
                            Text(
                              landmark,
                              style: const TextStyle(color: mutedInk),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (delivery.phone case final String phone
                        when phone.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => _callCustomer(phone),
                        icon: const Icon(Icons.phone_outlined),
                        label: const Text('Call customer'),
                      )
                    else
                      const Text('Customer phone number unavailable'),
                  ],
                ),
                const SizedBox(height: 10),
                _DetailPanel(
                  children: [
                    _IconText(
                      icon: Icons.schedule_outlined,
                      child: Text(
                        _dueLabel(delivery.scheduledAt),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _IconText(
                      icon: Icons.inventory_2_outlined,
                      child: Text(
                        delivery.itemCount == 1
                            ? '1 parcel item'
                            : '${delivery.itemCount} parcel items',
                      ),
                    ),
                    if (details.notes.isNotEmpty) ...[
                      const Divider(height: 24),
                      Text(
                        details.notes,
                        style: const TextStyle(color: mutedInk),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                _DetailPanel(
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        switch (delivery.cashOnDelivery) {
                          true =>
                            delivery.isDelivered
                                ? 'Cash amount'
                                : 'Cash to collect',
                          false => 'Paid online',
                          null => 'Payment details unavailable',
                        },
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (details.cashDue case final int cashDue
                        when delivery.cashOnDelivery == true) ...[
                      Text(
                        formatGbp(cashDue),
                        style: const TextStyle(
                          fontSize: 24,
                          color: forest,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (_controller.canMarkDelivered) ...[
                        const SizedBox(height: 12),
                        TextField(
                          key: _cashField,
                          controller: _cash,
                          focusNode: _cashFocus,
                          enabled: !_controller.isSubmitting,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => _controller.clearCashError(),
                          decoration: InputDecoration(
                            labelText: 'Cash received',
                            prefixText: '£ ',
                            border: const OutlineInputBorder(),
                            errorText: _controller.cashError,
                            errorMaxLines: 4,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: line)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          width: double.infinity,
          child: _buildCompletion(details),
        ),
      ],
    );
  }

  String _dueLabel(DateTime? time) {
    if (time == null) return 'Due time unavailable';
    final now = _controller.serverNow;
    final date = now != null && londonDay(now) != londonDay(time)
        ? '${londonDate(time)}, '
        : '';
    return 'Due $date${londonTime(time)} London time';
  }

  String? _completionMessage() {
    final completion = _controller.completion;
    if (completion == null) return null;
    if (!completion.needsReview) {
      return 'Saved on this phone. Waiting to sync.';
    }

    final cash = formatGbp(completion.cashPence);
    return '${completion.reviewReason} Recorded cash $cash.';
  }

  Widget _buildCompletion(DeliveryDetails details) {
    final delivery = details.delivery;
    final message =
        _controller.submitError ??
        _completionMessage() ??
        (delivery.isDelivered
            ? 'Delivery completed'
            : !delivery.canComplete
            ? 'Contact the office about this delivery.'
            : !details.hasVerifiedPayment
            ? 'Payment could not be verified. Contact the office.'
            : null);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (message != null)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:
                      _controller.completion?.needsReview == true ||
                          _controller.submitError != null
                      ? Theme.of(context).colorScheme.error
                      : forest,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        if (_controller.canMarkDelivered)
          FilledButton.icon(
            onPressed: _controller.isSubmitting ? null : _markDelivered,
            icon: _controller.isSubmitting
                ? const SizedBox.square(
                    dimension: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(
              _controller.isSubmitting ? 'Saving…' : 'Mark delivered',
            ),
          ),
      ],
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class _IconText extends StatelessWidget {
  const _IconText({required this.icon, required this.child});

  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20, color: forest),
      const SizedBox(width: 9),
      Expanded(child: child),
    ],
  );
}
