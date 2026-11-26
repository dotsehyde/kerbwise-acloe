import 'package:flutter/foundation.dart';

import '../core/utils/gbp.dart';
import '../models/delivery.dart';
import '../services/courier_api.dart';

class DeliveryDetailController extends ChangeNotifier {
  DeliveryDetailController({
    required this._api,
    required this._id,
    required this._onChange,
  });

  final CourierApi _api;
  final int _id;
  final ValueChanged<Delivery> _onChange;

  DeliveryDetails? _details;
  bool _isLoading = false;
  bool _isUnavailable = false;
  bool _isSubmitting = false;
  String? _cashError;
  String? _submitError;
  bool _disposed = false;

  DeliveryDetails? get details => _details;
  bool get isLoading => _isLoading;
  bool get isUnavailable => _isUnavailable;
  bool get isSubmitting => _isSubmitting;
  String? get cashError => _cashError;
  String? get submitError => _submitError;

  Future<void> loadDelivery() async {
    if (_isLoading || _disposed) return;
    _isLoading = true;
    notifyListeners();

    DeliveryDetails? details;
    var unavailable = false;
    try {
      details = await _api.fetchDelivery(_id);
    } on CourierApiException catch (error) {
      unavailable = error.statusCode == 404;
    } catch (_) {
      // A connection or response error can be retried from the detail page.
    }
    if (_disposed) return;

    _details = details;
    _isUnavailable = unavailable;
    _isLoading = false;
    notifyListeners();

    if (details != null) _onChange(details.delivery);
  }

  void clearCashError() {
    if (_disposed || _cashError == null) return;
    _cashError = null;
    notifyListeners();
  }

  Future<void> markDelivered(String cashInput) async {
    final details = _details;
    if (_disposed ||
        _isSubmitting ||
        details == null ||
        details.delivery.isDelivered) {
      return;
    }

    final cashPence = details.delivery.cashOnDelivery
        ? parseCashPence(cashInput)
        : 0;
    if (cashPence == null || cashPence != details.cashDue) {
      _cashError = _cashMismatchMessage(details.cashDue);
      _submitError = null;
      notifyListeners();
      return;
    }

    _isSubmitting = true;
    _cashError = null;
    _submitError = null;
    notifyListeners();

    Delivery? delivered;
    try {
      await _api.complete(_id, cashPence: cashPence);
      if (_disposed) return;
      delivered = details.delivery.asDelivered();
      _details = details.copyWith(delivery: delivered);
    } on CourierApiException catch (error) {
      if (_disposed) return;
      final expected = error.expectedCashPence;
      if (expected != null && details.delivery.cashOnDelivery) {
        _details = details.copyWith(cashDue: expected);
        _cashError = _cashMismatchMessage(expected);
      } else {
        _submitError = switch (error.statusCode) {
          404 => 'This delivery is no longer available.',
          409 => 'This delivery has changed. Go back and reopen it.',
          429 => 'Too many requests. Wait a moment and try again.',
          _ => 'Couldn’t save this delivery. Try again.',
        };
      }
    } catch (_) {
      if (_disposed) return;
      _submitError =
          'Couldn’t confirm delivery. Check your signal and try again.';
    } finally {
      if (!_disposed) {
        _isSubmitting = false;
        notifyListeners();
      }
    }

    if (delivered != null) _onChange(delivered);
  }

  String _cashMismatchMessage(int due) =>
      'Enter ${formatGbp(due)} to match the cash due.';

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
