import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kerbwise_courier/core/theme/courier_theme.dart';
import 'package:kerbwise_courier/models/completion_record.dart';
import 'package:kerbwise_courier/models/delivery.dart';
import 'package:kerbwise_courier/pages/delivery_detail_screen.dart';
import 'package:kerbwise_courier/pages/home_screen.dart';
import 'package:kerbwise_courier/services/completion_queue.dart';
import 'package:kerbwise_courier/services/completion_store.dart';
import 'package:kerbwise_courier/services/courier_api.dart';

void main() {
  final markDelivered = find.text('Mark delivered');

  testWidgets('Cash must match before a request can be sent', (tester) async {
    final requests = <http.Request>[];
    await _openDelivery(
      tester,
      cash: true,
      onComplete: (request) async {
        requests.add(request);
        return _completed();
      },
    );

    expect(find.text('£12.30'), findsOneWidget);
    await tester.tap(markDelivered);
    await tester.pumpAndSettle();
    expect(find.text('Enter £12.30 to match the cash due.'), findsOneWidget);

    final field = find.byType(TextField);
    await tester.ensureVisible(field);
    await tester.enterText(field, '12.29');
    await tester.tap(markDelivered);
    await tester.pumpAndSettle();
    expect(find.text('Enter £12.30 to match the cash due.'), findsOneWidget);
    expect(requests, isEmpty);

    await tester.enterText(field, '12.3');
    await tester.tap(markDelivered);
    await tester.pumpAndSettle();
    expect(requests, hasLength(1));
    expect(jsonDecode(requests.single.body), {'cashCollected': 12.3});
    expect(find.text('Delivery completed'), findsOneWidget);
    expect(markDelivered, findsNothing);
  });

  testWidgets('Paid delivery sends zero without asking for cash', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final changes = <Delivery>[];
    await _openDelivery(
      tester,
      cash: false,
      onChange: changes.add,
      onComplete: (request) async {
        requests.add(request);
        return _completed();
      },
    );

    expect(find.byType(TextField), findsNothing);
    await tester.tap(markDelivered);
    await tester.pumpAndSettle();
    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/deliveries/11/complete');
    expect(jsonDecode(requests.single.body), {'cashCollected': 0});
    expect(requests.single.headers['Idempotency-Key'], isNotEmpty);
    expect(changes.last.isDelivered, isTrue);
    expect(find.text('Delivery completed'), findsOneWidget);
  });

  testWidgets('A double tap sends only one completion request', (tester) async {
    final pending = Completer<http.Response>();
    var requests = 0;
    await _openDelivery(
      tester,
      cash: false,
      onComplete: (request) {
        requests++;
        return pending.future;
      },
    );

    await tester.tap(markDelivered);
    await tester.tap(markDelivered);
    await tester.pump();

    expect(requests, 1);
    expect(find.text('Saved on this phone. Waiting to sync.'), findsOneWidget);
    expect(markDelivered, findsNothing);

    pending.complete(_completed());
    await tester.pumpAndSettle();
    expect(find.text('Delivery completed'), findsOneWidget);
    expect(requests, 1);
  });

  testWidgets('A server cash mismatch shows the amount to enter', (
    tester,
  ) async {
    final requests = <http.Request>[];
    await _openDelivery(
      tester,
      cash: true,
      onComplete: (request) async {
        requests.add(request);
        return requests.length == 1
            ? _response({'code': 'cash_mismatch', 'expected': 13.5}, 422)
            : _completed();
      },
    );

    final field = find.byType(TextField);
    await tester.ensureVisible(field);
    await tester.enterText(field, '12.30');
    await tester.tap(markDelivered);
    await tester.pumpAndSettle();

    expect(find.text('£13.50'), findsOneWidget);
    expect(find.text('Enter £13.50 to match the cash due.'), findsOneWidget);
    expect(find.text('Delivery completed'), findsNothing);

    await tester.enterText(field, '13.50');
    await tester.tap(markDelivered);
    await tester.pumpAndSettle();
    expect(requests, hasLength(2));
    expect(
      requests.last.headers['Idempotency-Key'],
      isNot(requests.first.headers['Idempotency-Key']),
    );
    expect(jsonDecode(requests.last.body), {'cashCollected': 13.5});
    expect(find.text('Delivery completed'), findsOneWidget);
  });

  testWidgets('Retry reuses the same completion key after a network failure', (
    tester,
  ) async {
    final keys = <String?>[];
    final queue = await _openDelivery(
      tester,
      cash: false,
      onComplete: (request) async {
        keys.add(request.headers['Idempotency-Key']);
        if (keys.length == 1) throw http.ClientException('Connection lost');
        return _completed();
      },
    );

    await tester.tap(markDelivered);
    await tester.pumpAndSettle();
    expect(find.text('Saved on this phone. Waiting to sync.'), findsOneWidget);
    expect(find.text('Delivery completed'), findsNothing);

    await queue.sync();
    await tester.pumpAndSettle();
    expect(keys, hasLength(2));
    expect(keys.first, isNotEmpty);
    expect(keys.last, keys.first);
    expect(find.text('Delivery completed'), findsOneWidget);
  });

  testWidgets('All 60 deliveries are loaded and completion updates the list', (
    tester,
  ) async {
    final seen = <String?>[];
    final api = _mockApi((request) async {
      expect(request.headers['Authorization'], 'Bearer courier-demo-token');
      if (request.method == 'POST') return _completed(60);
      if (request.url.path == '/deliveries/60') {
        return _response(_delivery(60, cash: false));
      }

      expect(request.url.path, '/deliveries');
      expect(request.url.queryParameters['limit'], '25');
      final cursor = request.url.queryParameters['after'];
      seen.add(cursor);
      final start = int.parse(cursor ?? '0');
      final end = start == 50 ? 60 : start + 25;
      return _response({
        'items': [
          for (var i = start + 1; i <= end; i++) _delivery(i, cash: false),
        ],
        'next': end == 60 ? null : end,
      });
    });

    await tester.pumpWidget(_app(HomeScreen(api: api, queue: _queueFor(api))));
    await tester.pumpAndSettle();

    expect(seen, [null, '25', '50']);
    expect(find.text('0 of 60 delivered'), findsOneWidget);
    final last = find.text('Customer 60');
    await tester.scrollUntilVisible(last, 500, maxScrolls: 20);
    await tester.tap(last);
    await tester.pumpAndSettle();
    expect(find.text('60 Test Street'), findsOneWidget);
    expect(find.text('Call customer'), findsOneWidget);
    expect(find.text('Due 14:05 London time'), findsOneWidget);

    await tester.tap(markDelivered);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(last, findsOneWidget);
    expect(find.text('Delivered'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('1 of 60 delivered'),
      -500,
      maxScrolls: 20,
    );
    expect(find.text('1 of 60 delivered'), findsOneWidget);
  });

  testWidgets('Shows loading, then an error, and an empty state on retry', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    var requests = 0;
    final api = _mockApi((request) async {
      requests++;
      if (requests == 1) return pending.future;
      return _response({'items': [], 'next': null});
    });

    await tester.pumpWidget(_app(HomeScreen(api: api, queue: _queueFor(api))));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(_response({}, 503));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t load deliveries'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('No deliveries today'), findsOneWidget);
  });

  testWidgets('Delivery detail can retry a failed load', (tester) async {
    final pending = Completer<http.Response>();
    final changes = <Delivery>[];
    var requests = 0;
    final api = _mockApi((request) async {
      expect(request.url.path, '/deliveries/11');
      requests++;
      return requests == 1
          ? pending.future
          : _response(_delivery(11, cash: true));
    });

    await tester.pumpWidget(
      _app(
        DeliveryDetailScreen(
          api: api,
          queue: _queueFor(api),
          id: 11,
          onChange: changes.add,
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(_response({}, 503));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t load delivery'), findsOneWidget);
    expect(changes, isEmpty);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(changes.single.id, 11);
    expect(find.text('11 Test Street'), findsOneWidget);
    expect(markDelivered, findsOneWidget);
  });

  testWidgets('Keeps the route usable during an outage with mixed real data', (
    tester,
  ) async {
    var offline = false;
    final api = _mockApi((request) async {
      if (offline) throw http.ClientException('Connection lost');
      expect(request.url.path, '/deliveries');
      if (request.url.queryParameters.containsKey('after')) {
        return _response({
          'items': [
            _delivery(11, cash: true)..addAll({
              'phone': null,
              'amount': '12.30',
              'scheduledAt': '2026-07-03T13:05:00',
            }),
            _delivery(13, cash: true)..addAll({
              'status': 'failed',
              'scheduledAt': '2026-07-04T09:00:00Z',
            }),
          ],
          'next': null,
        });
      }
      return _response({
        'items': [
          _delivery(11, cash: true),
          _delivery(12, cash: false)..['scheduledAt'] = '2026-07-02T13:05:00Z',
        ],
        'next': 'next page',
      });
    });
    await tester.pumpWidget(_app(HomeScreen(api: api, queue: _queueFor(api))));
    await tester.pumpAndSettle();
    expect(find.text('0 of 1 delivered'), findsOneWidget);
    expect(find.text('Customer 11'), findsOneWidget);
    expect(find.text('Earlier deliveries'), findsOneWidget);
    expect(find.text('Upcoming deliveries'), findsOneWidget);

    offline = true;
    await tester.tap(find.byTooltip('Refresh deliveries'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Showing the last loaded deliveries'),
      findsOneWidget,
    );
    await tester.tap(find.text('Customer 11'));
    await tester.pumpAndSettle();
    expect(find.text('Due 13:05 London time'), findsOneWidget);
    expect(find.text('Customer phone number unavailable'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '12.30');
    await tester.tap(markDelivered);
    await tester.pumpAndSettle();
    expect(find.text('Saved on this phone. Waiting to sync.'), findsOneWidget);
  });

  testWidgets('Conflicting cached payment details block offline completion', (
    tester,
  ) async {
    var offline = false;
    final api = _mockApi((request) async {
      if (offline) throw http.ClientException('Connection lost');
      return _response(_delivery(11, cash: true));
    });
    await api.fetchDelivery(11);
    offline = true;

    await tester.pumpWidget(
      _app(
        DeliveryDetailScreen(
          api: api,
          queue: _queueFor(api),
          id: 11,
          summary: Delivery.fromJson(_delivery(11, cash: false)),
          onChange: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('11 Test Street'), findsOneWidget);
    expect(
      find.text('Payment could not be verified. Contact the office.'),
      findsOneWidget,
    );
    expect(markDelivered, findsNothing);
  });
}

Future<CompletionQueue> _openDelivery(
  WidgetTester tester, {
  required bool cash,
  required Future<http.Response> Function(http.Request) onComplete,
  ValueChanged<Delivery>? onChange,
}) async {
  final api = _mockApi((request) async {
    if (request.method == 'POST') return onComplete(request);
    return _response(_delivery(11, cash: cash));
  });
  final queue = _queueFor(api);

  await tester.pumpWidget(
    _app(
      DeliveryDetailScreen(
        api: api,
        queue: queue,
        id: 11,
        onChange: onChange ?? (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
  return queue;
}

CompletionQueue _queueFor(CourierApi api) {
  final queue = CompletionQueue(api, _MemoryCompletionStore());
  addTearDown(queue.dispose);
  return queue;
}

class _MemoryCompletionStore implements CompletionStore {
  final _records = <int, CompletionRecord>{};

  @override
  Future<List<CompletionRecord>> readAll() async => _records.values.toList();

  @override
  Future<void> write(CompletionRecord record) async =>
      _records[record.id] = record;

  @override
  Future<void> remove(int id) async => _records.remove(id);
}

CourierApi _mockApi(Future<http.Response> Function(http.Request) handler) {
  final api = CourierApi(
    baseUrl: Uri.parse('http://courier.test'),
    client: MockClient(handler),
  );
  addTearDown(api.close);
  return api;
}

MaterialApp _app(Widget home) => MaterialApp(theme: courierTheme(), home: home);

Map<String, dynamic> _delivery(int id, {required bool cash}) => {
  'id': id,
  'customerName': 'Customer $id',
  'phone': '+447400000000',
  'address': {'line1': '$id Test Street', 'area': 'Hackney'},
  'items': 1,
  'amount': 12.3,
  'currency': 'GBP',
  'paymentMode': cash ? 'cash' : 'paid',
  'status': 'assigned',
  'scheduledAt': '2026-07-03T13:05:00Z',
  'cashDue': cash ? 12.3 : 0,
  'notes': '',
};

http.Response _completed([int id = 11]) =>
    _response({'id': id, 'status': 'delivered'});

http.Response _response(Map<String, dynamic> body, [int status = 200]) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'date': 'Fri, 03 Jul 2026 10:00:00 GMT',
      },
    );
