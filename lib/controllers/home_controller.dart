import 'package:flutter/foundation.dart';

import '../models/delivery.dart';
import '../services/courier_api.dart';

class HomeController extends ChangeNotifier {
  HomeController(this._api);

  final CourierApi _api;
  List<Delivery>? _deliveries;
  bool _isLoading = false;
  bool _disposed = false;

  List<Delivery>? get deliveries => _deliveries;
  bool get isLoading => _isLoading;

  Future<void> loadDeliveries() async {
    if (_isLoading || _disposed) return;
    _isLoading = true;
    notifyListeners();

    List<Delivery>? deliveries;
    try {
      deliveries = List.unmodifiable(await _api.fetchDeliveries());
    } catch (_) {
      // A failed page leaves the route incomplete. Offer a full retry.
    }
    if (_disposed) return;

    _deliveries = deliveries;
    _isLoading = false;
    notifyListeners();
  }

  void updateDelivery(Delivery updated) {
    final deliveries = _deliveries;
    if (_disposed || deliveries == null) return;

    _deliveries = List.unmodifiable(
      deliveries.map((item) => item.id == updated.id ? updated : item),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
