import 'package:flutter/foundation.dart';

import '../models/delivery.dart';
import '../services/courier_api.dart';

class HomeController extends ChangeNotifier {
  HomeController(this._api);

  final CourierApi _api;
  List<Delivery>? _deliveries;
  DateTime? _routeDate;
  bool _refreshFailed = false;
  bool _isLoading = false;
  bool _disposed = false;

  List<Delivery>? get deliveries => _deliveries;
  DateTime? get routeDate => _routeDate;
  bool get refreshFailed => _refreshFailed;
  bool get isLoading => _isLoading;

  Future<void> loadDeliveries() async {
    if (_isLoading || _disposed) return;
    _isLoading = true;
    notifyListeners();

    List<Delivery>? deliveries;
    try {
      deliveries = List.unmodifiable(await _api.fetchDeliveries());
    } on CourierApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        _deliveries = null;
        _routeDate = null;
      }
    } catch (_) {
      // Keep the last complete list if any page of the refresh fails.
    }
    if (_disposed) return;

    _refreshFailed = deliveries == null;
    if (deliveries != null) {
      _deliveries = deliveries;
      _routeDate = _api.serverNow;
    }
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
