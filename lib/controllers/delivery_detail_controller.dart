import 'package:flutter/foundation.dart';

import '../core/utils/gbp.dart';
import '../models/completion_record.dart';
import '../models/delivery.dart';
import '../services/completion_queue.dart';
import '../services/courier_api.dart';

class DeliveryDetailController extends ChangeNotifier {
  DeliveryDetailController({
    required this._api,
    required this._queue,
    required this._id,
    required this._onChange,
    required this._summary,
  }) {
    _queue.addListener(_queueChanged);
  }

  final CourierApi _api;
  final CompletionQueue _queue;
  final int _id;
  final ValueChanged<Delivery> _onChange;
  final Delivery? _summary;

  DeliveryDetails? _details;
  bool _isLoading = false;
  bool _isUnavailable = false;
  bool _isCached = false;
  bool _isSubmitting = false;
  bool _reportedConfirmation = false;
  String? _cashError;
  String? _dismissedCashErrorKey;
  String? _submitError;
  bool _disposed = false;

  DeliveryDetails? get details {
    final deliveryDetails = _details;
    if (deliveryDetails == null) return null;
    if (_queue.isConfirmed(_id)) {
      return deliveryDetails.copyWith(
        delivery: deliveryDetails.delivery.asDelivered(),
      );
    }
    final expected = _correctionAmount;
    return expected == null
        ? deliveryDetails
        : deliveryDetails.copyWith(cashDue: expected);
  }

  DateTime? get serverNow => _api.serverNow;
  CompletionRecord? get completion => _queue.recordFor(_id);
  bool get isConfirmed => _queue.isConfirmed(_id);
  bool get isLoading => _isLoading;
  bool get isUnavailable => _isUnavailable;
  bool get isCached => _isCached;
  bool get isSubmitting => _isSubmitting;
  String? get submitError => _submitError;

  int? get _correctionAmount => _details?.delivery.cashOnDelivery == true
      ? completion?.expectedCashPence
      : null;

  String? get cashError {
    if (_cashError != null) return _cashError;
    final expected = _correctionAmount;
    return expected != null && completion?.key != _dismissedCashErrorKey
        ? _cashMismatchMessage(expected)
        : null;
  }

  bool get canMarkDelivered {
    final current = details;
    return current != null &&
        current.delivery.canComplete &&
        current.hasVerifiedPayment &&
        (completion == null || _correctionAmount != null);
  }

  Future<void> loadDelivery() async {
    if (_isLoading || _disposed) return;
    _isLoading = true;
    notifyListeners();

    DeliveryDetails? details;
    var unavailable = false;
    var useCache = false;
    try {
      details = await _api.fetchDelivery(_id);
    } on CourierApiException catch (error) {
      unavailable = error.statusCode == 404;
      useCache = error.statusCode >= 500 || error.statusCode == 429;
    } catch (_) {
      useCache = true;
    }
    if (_disposed) return;

    _details = details ?? (useCache ? _offlineDetails() : null);
    _isCached = details == null && _details != null;
    _isUnavailable = unavailable;
    _isLoading = false;
    if (details != null) _onChange(details.delivery);
    _queueChanged();
  }

  DeliveryDetails? _offlineDetails() {
    final cached = _api.cachedDetails(_id);
    final summary = _summary;
    if (summary == null) return cached;
    if (cached == null) return DeliveryDetails.fromSummary(summary);
    if (cached.delivery.cashOnDelivery != summary.cashOnDelivery ||
        cached.delivery.orderTotal != summary.orderTotal ||
        cached.delivery.canComplete != summary.canComplete) {
      return DeliveryDetails(delivery: summary, cashDue: null, notes: '');
    }
    return cached;
  }

  void clearCashError() {
    if (cashError == null) return;
    _cashError = null;
    _dismissedCashErrorKey = completion?.key;
    notifyListeners();
  }

  Future<void> markDelivered(String cashInput) async {
    if (_disposed || _isSubmitting || !canMarkDelivered) return;
    final current = details!;
    final cashPence = current.delivery.cashOnDelivery == true
        ? parseCashPence(cashInput)
        : 0;
    if (cashPence == null || cashPence != current.cashDue) {
      _cashError = _cashMismatchMessage(current.cashDue!);
      _submitError = null;
      notifyListeners();
      return;
    }

    _isSubmitting = true;
    _cashError = null;
    _submitError = null;
    notifyListeners();

    try {
      await _queue.enqueue(_id, cashPence);
    } catch (_) {
      _submitError =
          'Couldn’t save this handover on your phone. Try again before leaving.';
    } finally {
      if (!_disposed) {
        _isSubmitting = false;
        notifyListeners();
      }
    }
  }

  void _queueChanged() {
    if (_disposed) return;
    if (details case final DeliveryDetails confirmed
        when !_reportedConfirmation && isConfirmed) {
      _reportedConfirmation = true;
      _onChange(confirmed.delivery);
    }
    notifyListeners();
  }

  String _cashMismatchMessage(int due) =>
      'Enter ${formatGbp(due)} to match the cash due.';

  @override
  void dispose() {
    _disposed = true;
    _queue.removeListener(_queueChanged);
    super.dispose();
  }
}
