import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/utils/gbp.dart';
import '../models/delivery.dart';

class CourierApi {
  CourierApi({required this._baseUrl, required this._client});

  final Uri _baseUrl;
  final http.Client _client;
  final _details = <int, DeliveryDetails>{};
  final _elapsedSinceResponse = Stopwatch();
  DateTime? _lastServerTime;

  DateTime? get serverNow =>
      _lastServerTime?.add(_elapsedSinceResponse.elapsed);

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
    final deliveries = <int, Delivery>{};
    final seenCursors = <String>{};
    String? after;

    do {
      final response = await _request(
        'GET',
        '/deliveries',
        query: {'limit': '25', 'after': ?after},
      );
      final page = _readResponse(response);
      for (final item in page['items'] as List) {
        final delivery = Delivery.fromJson(item as Map<String, dynamic>);
        deliveries[delivery.id] = delivery;
      }
      final cursor = page['next'];
      after = switch (cursor) {
        null => null,
        int() || String() => cursor.toString(),
        _ => throw const FormatException('Invalid delivery page cursor.'),
      };
      if (after != null && !seenCursors.add(after)) {
        throw const FormatException('Delivery page cursor repeated.');
      }
    } while (after != null);

    return deliveries.values.toList();
  }

  DeliveryDetails? cachedDetails(int id) => _details[id];

  Future<DeliveryDetails> fetchDelivery(int id) async {
    final response = await _request('GET', '/deliveries/$id');
    if (response.statusCode == 404) _details.remove(id);
    final details = DeliveryDetails.fromJson(_readResponse(response));
    if (details.delivery.id != id) {
      throw const FormatException('Delivery detail ID did not match.');
    }
    _details[id] = details;
    return details;
  }

  Future<void> complete(
    int id, {
    required int cashPence,
    required String idempotencyKey,
  }) async {
    final response = await _request(
      'POST',
      '/deliveries/$id/complete',
      idempotencyKey: idempotencyKey,
      body: jsonEncode({'cashCollected': cashPence / 100}),
    );
    final completion = _readResponse(response);
    if (completion['id'] != id || completion['status'] != 'delivered') {
      throw const FormatException('Delivery completion was not confirmed.');
    }
    final cached = _details[id];
    if (cached != null) {
      _details[id] = cached.copyWith(delivery: cached.delivery.asDelivered());
    }
  }

  Future<http.Response> _request(
    String method,
    String path, {
    Map<String, String>? query,
    String? idempotencyKey,
    String? body,
  }) async {
    final abort = Completer<void>();
    final request = http.AbortableRequest(
      method,
      _uri(path, query),
      abortTrigger: abort.future,
    )..headers.addAll(_headers);
    if (idempotencyKey != null) {
      request.headers['Idempotency-Key'] = idempotencyKey;
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = body;
    }

    final response = await _client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(
          _timeout,
          onTimeout: () {
            abort.complete();
            throw TimeoutException('Courier API did not respond.', _timeout);
          },
        );
    final date = _parseHttpDate(response.headers['date']);
    if (date != null) {
      _lastServerTime = date;
      _elapsedSinceResponse
        ..reset()
        ..start();
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      _details.clear();
    }
    return response;
  }

  Map<String, dynamic> _readResponse(http.Response response) {
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    }
    int? expectedCashPence;
    if (response.statusCode == 422) {
      try {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body case {
          'code': 'cash_mismatch',
          'expected': final Object expected,
        }) {
          expectedCashPence = poundsToPence(expected);
        }
      } on FormatException {
        // Preserve the rejection even if the API omitted a usable explanation.
      }
    }
    throw CourierApiException(
      response.statusCode,
      expectedCashPence: expectedCashPence,
      retryAfter: _retryAfter(response.headers['retry-after']),
    );
  }

  Duration? _retryAfter(String? value) {
    if (value == null) return null;
    final seconds = int.tryParse(value);
    if (seconds != null && seconds >= 0) return Duration(seconds: seconds);
    final retryAt = _parseHttpDate(value);
    final now = serverNow;
    return retryAt == null || now == null ? null : retryAt.difference(now);
  }

  DateTime? _parseHttpDate(String? value) {
    if (value == null) return null;
    try {
      return HttpDate.parse(value);
    } on HttpException {
      return null;
    }
  }

  void close() => _client.close();
}

class CourierApiException implements Exception {
  const CourierApiException(
    this.statusCode, {
    this.expectedCashPence,
    this.retryAfter,
  });

  final int statusCode;
  final int? expectedCashPence;
  final Duration? retryAfter;
}
