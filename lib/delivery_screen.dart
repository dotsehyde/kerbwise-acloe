import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'courier_api.dart';
import 'courier_theme.dart';
import 'delivery.dart';

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({
    super.key,
    required this.api,
    required this.id,
    required this.onChange,
  });

  final CourierApi api;
  final int id;
  final ValueChanged<Delivery> onChange;

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  late Future<DeliveryDetails> _details;
  final _cash = TextEditingController();
  final _cashFocus = FocusNode();
  final _cashField = GlobalKey();
  Delivery? _completed;
  bool _submitting = false;
  int? _updatedCashDue;
  String? _cashError;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _details = _fetchDetails();
  }

  Future<DeliveryDetails> _fetchDetails() async {
    final details = await widget.api.fetchDelivery(widget.id);
    if (mounted) widget.onChange(details.delivery);
    return details;
  }

  @override
  void dispose() {
    _cash.dispose();
    _cashFocus.dispose();
    super.dispose();
  }

  int _cashDue(DeliveryDetails details) => _updatedCashDue ?? details.cashDue;

  void _showCashError(int due, {bool updateCashDue = false}) {
    setState(() {
      if (updateCashDue) _updatedCashDue = due;
      _cashError = 'Enter ${formatGbp(due)} to match the cash due.';
      _submitError = null;
    });
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

  Future<void> _markDelivered(DeliveryDetails details) async {
    if (_submitting || _completed != null || details.delivery.isDelivered) {
      return;
    }

    final cashPence = details.delivery.cashOnDelivery
        ? parseCashPence(_cash.text)
        : 0;
    final due = _cashDue(details);
    if (cashPence == null || cashPence != due) {
      _showCashError(due);
      return;
    }

    _cashFocus.unfocus();
    setState(() {
      _submitting = true;
      _cashError = null;
      _submitError = null;
    });

    try {
      await widget.api.complete(widget.id, cashPence: cashPence);
      if (!mounted) return;
      final delivered = details.delivery.asDelivered();
      setState(() => _completed = delivered);
      widget.onChange(delivered);
    } on CourierApiException catch (error) {
      if (!mounted) return;
      final expected = error.expectedCashPence;
      if (expected != null && details.delivery.cashOnDelivery) {
        _showCashError(expected, updateCashDue: true);
      } else {
        setState(() {
          _submitError = switch (error.statusCode) {
            404 => 'This delivery is no longer available.',
            409 => 'This delivery has changed. Go back and reopen it.',
            429 => 'Too many requests. Wait a moment and try again.',
            _ => 'Couldn’t save this delivery. Try again.',
          };
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitError =
            'Couldn’t confirm delivery. Check your signal and try again.';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _callCustomer(String phone) async {
    try {
      if (await launchUrl(
        Uri(scheme: 'tel', path: phone),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      // An emulator or a device without a dialer may reject the intent.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Couldn’t open the phone dialer.')),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_submitting,
    child: Scaffold(
      appBar: AppBar(title: Text('Delivery #${widget.id}')),
      body: SafeArea(
        top: false,
        child: FutureBuilder<DeliveryDetails>(
          future: _details,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Loading delivery',
                ),
              );
            }
            final details = snapshot.data;
            if (details == null) {
              final error = snapshot.error;
              if (error is CourierApiException && error.statusCode == 404) {
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
                retry: () => setState(() => _details = _fetchDetails()),
              );
            }
            return _buildDelivery(details);
          },
        ),
      ),
    ),
  );

  Widget _buildDelivery(DeliveryDetails details) {
    final delivery = _completed ?? details.delivery;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DetailPanel(
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: delivery.isDelivered ? softGreen : lime,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          child: Text(
                            delivery.status.label,
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
                    OutlinedButton.icon(
                      onPressed: () => _callCustomer(details.phone),
                      icon: const Icon(Icons.phone_outlined),
                      label: const Text('Call customer'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _DetailPanel(
                  children: [
                    _IconText(
                      icon: Icons.schedule_outlined,
                      child: Text(
                        'Due ${londonTime(delivery.scheduledAt)} London time',
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
                        delivery.cashOnDelivery
                            ? (delivery.isDelivered
                                  ? 'Cash amount'
                                  : 'Cash to collect')
                            : 'Paid online',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (delivery.cashOnDelivery) ...[
                      Text(
                        formatGbp(_cashDue(details)),
                        style: const TextStyle(
                          fontSize: 24,
                          color: forest,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (!delivery.isDelivered) ...[
                        const SizedBox(height: 12),
                        TextField(
                          key: _cashField,
                          controller: _cash,
                          focusNode: _cashFocus,
                          enabled: !_submitting,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.done,
                          onChanged: (_) {
                            if (_cashError != null) {
                              setState(() => _cashError = null);
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Cash received',
                            prefixText: '£ ',
                            border: const OutlineInputBorder(),
                            errorText: _cashError,
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
          child: delivery.isDelivered
              ? Semantics(
                  liveRegion: true,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Delivery completed',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: forest,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_submitError case final String error)
                      Semantics(
                        liveRegion: true,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            error,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    FilledButton.icon(
                      onPressed: _submitting
                          ? null
                          : () => _markDelivered(details),
                      icon: _submitting
                          ? const SizedBox.square(
                              dimension: 17,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(_submitting ? 'Saving…' : 'Mark delivered'),
                    ),
                  ],
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
