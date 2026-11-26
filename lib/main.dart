import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'core/theme/courier_theme.dart';
import 'pages/home_screen.dart';
import 'services/completion_queue.dart';
import 'services/completion_store.dart';
import 'services/courier_api.dart';

void main() => runApp(const CourierApp());

class CourierApp extends StatefulWidget {
  const CourierApp({super.key});

  @override
  State<CourierApp> createState() => _CourierAppState();
}

class _CourierAppState extends State<CourierApp> with WidgetsBindingObserver {
  static const _baseUrl = String.fromEnvironment(
    'COURIER_API_URL',
    defaultValue: 'http://10.0.2.2:4000',
  );

  late final _api = CourierApi(
    baseUrl: Uri.parse(_baseUrl),
    client: http.Client(),
  );
  late final _queue = CompletionQueue(
    _api,
    FileCompletionStore(getApplicationSupportDirectory, scope: _baseUrl),
  );
  late final Timer _syncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _queue.sync(),
    );
    unawaited(_queue.sync());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    _queue.setActive(active);
    if (active) unawaited(_queue.sync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer.cancel();
    _queue.dispose();
    _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Kerbwise Courier',
    debugShowCheckedModeBanner: false,
    theme: courierTheme(),
    home: HomeScreen(api: _api, queue: _queue),
  );
}
