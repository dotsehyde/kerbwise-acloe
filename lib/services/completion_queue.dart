import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/completion_record.dart';
import 'completion_store.dart';
import 'courier_api.dart';

class CompletionQueue extends ChangeNotifier {
  CompletionQueue(this._api, this._store);

  final CourierApi _api;
  final CompletionStore _store;
  final _records = <int, CompletionRecord>{};
  final _confirmed = <int>{};
  final _saving = <int>{};
  final _random = Random.secure();
  final _cooldown = Stopwatch();
  var _retryAfter = Duration.zero;
  late final _initialLoad = _restore();
  bool _storageError = false;
  bool _syncing = false;
  bool _active = true;
  bool _disposed = false;

  bool get storageError => _storageError;
  Iterable<CompletionRecord> get records => _records.values;
  CompletionRecord? recordFor(int id) => _records[id];
  bool isConfirmed(int id) => _confirmed.contains(id);

  Future<void> initialize() => _initialLoad;

  Future<void> _restore() async {
    try {
      for (final record in await _store.readAll()) {
        _records[record.id] = record;
      }
    } catch (_) {
      _storageError = true;
    }
    _notify();
  }

  Future<void> enqueue(int id, int cashPence) async {
    await initialize();
    if (_storageError) {
      throw StateError('The saved handovers could not be read.');
    }
    if (_disposed || isConfirmed(id) || !_saving.add(id)) return;
    try {
      final previous = _records[id];
      if (previous != null && previous.expectedCashPence != cashPence) return;

      final record = CompletionRecord(
        id: id,
        cashPence: cashPence,
        key: List.generate(
          16,
          (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join(),
        queuedAt: _api.serverNow,
      );
      await _store.write(record);
      _records[id] = record;
      _notify();
    } finally {
      _saving.remove(id);
    }
    unawaited(sync());
  }

  void setActive(bool active) => _active = active;

  Future<void> sync() async {
    if (_disposed || !_active || _syncing || _cooldown.elapsed < _retryAfter) {
      return;
    }
    _syncing = true;
    try {
      await initialize();
      if (_storageError) return;
      for (final record in records.toList()) {
        if (!_active || _disposed) break;
        if (record.needsReview) continue;
        if (!await _send(record)) break;
      }
    } finally {
      _syncing = false;
    }
  }

  Future<bool> _send(CompletionRecord record) async {
    try {
      final queuedAt = record.queuedAt;
      if (queuedAt == null) {
        await _flag(
          record,
          'Handover time is unavailable. Ask the office to verify it.',
        );
        return true;
      }

      if (_api.serverNow == null) await _api.fetchDelivery(record.id);
      final now = _api.serverNow;
      if (now == null) return false;
      // Stay inside the API's 24-hour key window, with room for clock skew.
      final age = now.difference(queuedAt);
      if (age >= const Duration(hours: 23) ||
          age < const Duration(minutes: -5)) {
        await _flag(
          record,
          'This handover needs the office to verify it before retrying.',
        );
        return true;
      }
      if (!_active || _disposed) return false;

      await _api.complete(
        record.id,
        cashPence: record.cashPence,
        idempotencyKey: record.key,
      );
      await _store.remove(record.id);
      _records.remove(record.id);
      _confirmed.add(record.id);
      _notify();
      return true;
    } on CourierApiException catch (error) {
      return _handleRejection(record, error);
    } catch (_) {
      // Keep the original body and key when the outcome is unknown.
      return false;
    }
  }

  Future<bool> _handleRejection(
    CompletionRecord record,
    CourierApiException error,
  ) async {
    if (error.statusCode == 429 ||
        error.retryAfter != null && error.statusCode == 503) {
      _retryAfter = error.retryAfter ?? const Duration(seconds: 30);
      if (_retryAfter < Duration.zero) _retryAfter = Duration.zero;
      _cooldown
        ..reset()
        ..start();
      return false;
    }
    if (error.statusCode >= 500) return true;

    final expected = error.expectedCashPence;
    final correctable =
        error.statusCode == 422 &&
        expected != null &&
        expected != record.cashPence;
    final reason = switch (error.statusCode) {
      404 => 'The server could not find this delivery. Contact the office.',
      409 =>
        'The server reported a conflict. Ask the office to verify this handover.',
      401 || 403 =>
        'The server refused access. Ask the office to verify this handover.',
      422 when correctable =>
        'The cash due changed. Check the amount actually received.',
      _ => 'The server rejected this handover. Ask the office to check it.',
    };
    try {
      await _flag(
        record,
        reason,
        expectedCashPence: correctable ? expected : null,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _flag(
    CompletionRecord record,
    String reason, {
    int? expectedCashPence,
  }) async {
    final reviewed = record.forReview(
      reason,
      expectedCashPence: expectedCashPence,
    );
    await _store.write(reviewed);
    _records[record.id] = reviewed;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
