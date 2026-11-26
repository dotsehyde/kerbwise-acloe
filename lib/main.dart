import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'core/theme/courier_theme.dart';
import 'pages/home_screen.dart';
import 'services/courier_api.dart';

void main() => runApp(const CourierApp());

class CourierApp extends StatefulWidget {
  const CourierApp({super.key});

  @override
  State<CourierApp> createState() => _CourierAppState();
}

class _CourierAppState extends State<CourierApp> {
  static const _baseUrl = String.fromEnvironment(
    'COURIER_API_URL',
    defaultValue: 'http://10.0.2.2:4000',
  );

  late final _api = CourierApi(
    baseUrl: Uri.parse(_baseUrl),
    client: http.Client(),
  );

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Kerbwise Courier',
    debugShowCheckedModeBanner: false,
    theme: courierTheme(),
    home: HomeScreen(api: _api),
  );
}
