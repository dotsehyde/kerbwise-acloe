import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kerbwise_courier/models/completion_record.dart';
import 'package:kerbwise_courier/services/completion_queue.dart';
import 'package:kerbwise_courier/services/completion_store.dart';
import 'package:kerbwise_courier/services/courier_api.dart';

void main() {
  test(
    'Restored handover replays the exact amount and key after a lost response',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'courier-outbox-',
      );
      addTearDown(() => directory.delete(recursive: true));
      FileCompletionStore store() =>
          FileCompletionStore(() async => directory, scope: 'test');
      final posts = <http.Request>[];

      CourierApi api() => CourierApi(
        baseUrl: Uri.parse('http://courier.test'),
        client: MockClient((request) async {
          if (request.method == 'GET') {
            return _response({
              'id': 33,
              'customerName': 'Test customer',
              'address': {'line1': 'Test address', 'area': 'London'},
              'items': 1,
              'amount': '110.00',
              'currency': 'GBP',
              'paymentMode': 'cash',
              'status': 'assigned',
              'cashDue': 110,
            });
          }
          posts.add(request);
          if (posts.length == 1) throw http.ClientException('Response lost');
          return _response({'id': 33, 'status': 'delivered'});
        }),
      );

      final firstApi = api();
      final first = CompletionQueue(firstApi, store())..setActive(false);
      await firstApi.fetchDelivery(33);
      await first.enqueue(33, 11000);
      final key = first.recordFor(33)!.key;

      first.setActive(true);
      await first.sync();
      expect(first.recordFor(33)!.key, key);
      first.dispose();
      firstApi.close();

      final secondApi = api();
      final second = CompletionQueue(secondApi, store());
      addTearDown(second.dispose);
      addTearDown(secondApi.close);
      await second.initialize();
      expect(second.recordFor(33)!.cashPence, 11000);
      expect(second.recordFor(33)!.key, key);

      await second.sync();
      expect(posts, hasLength(2));
      expect(posts.map((post) => post.headers['idempotency-key']), [key, key]);
      expect(posts.map((post) => post.body), [
        '{"cashCollected":110.0}',
        '{"cashCollected":110.0}',
      ]);
      expect(second.isConfirmed(33), isTrue);
      expect(await store().readAll(), isEmpty);
    },
  );

  test('Honors Retry-After and stops retrying a terminal conflict', () async {
    final directory = await Directory.systemTemp.createTemp('courier-outbox-');
    addTearDown(() => directory.delete(recursive: true));
    final store = FileCompletionStore(() async => directory, scope: 'test');
    var posts = 0;
    final api = CourierApi(
      baseUrl: Uri.parse('http://courier.test'),
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return _response({'items': [], 'next': null});
        }
        posts++;
        if (request.url.path.contains('/9/')) {
          return _response({'code': 'conflict'}, status: 409);
        }
        return _response(
          {'code': 'rate_limited'},
          status: 429,
          retryAfter: '60',
        );
      }),
    );
    final queue = CompletionQueue(api, store)..setActive(false);
    addTearDown(queue.dispose);
    addTearDown(api.close);
    await api.fetchDeliveries();
    await queue.enqueue(9, 1230);
    await queue.enqueue(11, 0);
    queue.setActive(true);

    await queue.sync();
    expect(posts, 2);
    expect(queue.recordFor(9)!.needsReview, isTrue);
    expect(queue.recordFor(11)!.needsReview, isFalse);
    await queue.sync();
    expect(posts, 2);
    expect(
      (await store.readAll()).singleWhere((record) => record.id == 9).cashPence,
      1230,
    );
  });

  test('A failed local write sends no completion request', () async {
    var requests = 0;
    final api = CourierApi(
      baseUrl: Uri.parse('http://courier.test'),
      client: MockClient((request) async {
        requests++;
        return _response({'items': [], 'next': null});
      }),
    );
    final queue = CompletionQueue(api, _FailingCompletionStore());
    addTearDown(queue.dispose);
    addTearDown(api.close);
    await api.fetchDeliveries();
    requests = 0;

    await expectLater(
      queue.enqueue(9, 1230),
      throwsA(isA<FileSystemException>()),
    );
    await queue.sync();
    expect(queue.records, isEmpty);
    expect(requests, 0);
  });

  test('A restore outside the key retention window requires review', () async {
    final directory = await Directory.systemTemp.createTemp('courier-outbox-');
    addTearDown(() => directory.delete(recursive: true));
    final store = FileCompletionStore(() async => directory, scope: 'test');
    await store.write(
      CompletionRecord(
        id: 9,
        cashPence: 1230,
        key: 'old-key',
        queuedAt: DateTime.utc(2026, 7, 2, 10),
      ),
    );
    var posts = 0;
    final api = CourierApi(
      baseUrl: Uri.parse('http://courier.test'),
      client: MockClient((request) async {
        if (request.method == 'POST') posts++;
        return _response({'items': [], 'next': null});
      }),
    );
    final queue = CompletionQueue(api, store);
    addTearDown(queue.dispose);
    addTearDown(api.close);
    await api.fetchDeliveries();

    await queue.sync();
    expect(posts, 0);
    expect(queue.recordFor(9)!.needsReview, isTrue);
    expect((await store.readAll()).single.key, 'old-key');
  });
}

class _FailingCompletionStore implements CompletionStore {
  @override
  Future<List<CompletionRecord>> readAll() async => [];

  @override
  Future<void> remove(int id) async {}

  @override
  Future<void> write(CompletionRecord record) async {
    throw const FileSystemException('Disk full');
  }
}

http.Response _response(
  Map<String, Object?> body, {
  int status = 200,
  String? retryAfter,
}) => http.Response(
  jsonEncode(body),
  status,
  headers: {
    'date': 'Fri, 03 Jul 2026 10:00:00 GMT',
    'retry-after': ?retryAfter,
  },
);
