import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'delivery.dart';

class CourierApi {
  CourierApi({required this._baseUrl, required this._client});

  final Uri _baseUrl;
  final http.Client _client;
  final _attempts = <int, ({int cashPence, String key})>{};
  static final _random = Random.secure();

  static const _headers = {
    'Authorization': 'Bearer courier-demo-token',
    'Accept': 'application/json',
  };
  static const _timeout = Duration(seconds: 10);

  Uri _uri(String path, [Map<String, String>? query]) => _baseUrl.replace(
    path: '${_baseUrl.path.replaceFirst(RegExp(r'/$'), '')}$path',
    queryParameters: query,
  );

  Future<List<Delivery>> fetchDeliveries() async {
    final deliveries = <Delivery>[];
    final seenCursors = <int>{};
    int? after;

    do {
      final response = await _client
          .get(
            _uri('/deliveries', {
              'limit': '25',
              if (after != null) 'after': '$after',
            }),
            headers: _headers,
          )
          .timeout(_timeout);
      final page = _readResponse(response);
      deliveries.addAll(
        (page['items'] as List).map(
          (item) => Delivery.fromJson(item as Map<String, dynamic>),
        ),
      );
      after = page['next'] as int?;
      if (after != null && !seenCursors.add(after)) {
        throw const FormatException('Delivery page cursor repeated.');
      }
    } while (after != null);

    return deliveries;
  }

  Future<DeliveryDetails> fetchDelivery(int id) async {
    final response = await _client
        .get(_uri('/deliveries/$id'), headers: _headers)
        .timeout(_timeout);
    final details = DeliveryDetails.fromJson(_readResponse(response));
    if (details.delivery.isDelivered) _attempts.remove(id);
    return details;
  }

  Future<void> complete(int id, {required int cashPence}) async {
    final previousAttempt = _attempts[id];
    final key = previousAttempt?.cashPence == cashPence
        ? previousAttempt!.key
        : List.generate(
            16,
            (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
          ).join();
    _attempts[id] = (cashPence: cashPence, key: key);

    final response = await _client
        .post(
          _uri('/deliveries/$id/complete'),
          headers: {
            ..._headers,
            'Content-Type': 'application/json',
            'Idempotency-Key': key,
          },
          body: jsonEncode({'cashCollected': cashPence / 100}),
        )
        .timeout(_timeout);
    final completion = _readResponse(response);
    if (completion['id'] != id || completion['status'] != 'delivered') {
      throw const FormatException('Delivery completion was not confirmed.');
    }
    _attempts.remove(id);
  }

  Map<String, dynamic> _readResponse(http.Response response) {
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    }
    if (response.statusCode == 422) {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body case {'code': 'cash_mismatch', 'expected': final num expected}) {
        throw CourierApiException(
          422,
          expectedCashPence: poundsToPence(expected),
        );
      }
    }
    throw CourierApiException(response.statusCode);
  }

  void close() => _client.close();
}

class CourierApiException implements Exception {
  const CourierApiException(this.statusCode, {this.expectedCashPence});

  final int statusCode;
  final int? expectedCashPence;
}
