import 'package:flutter/material.dart';

const ink = Color(0xFF1B261F);
const mutedInk = Color(0xFF495B50);
const forest = Color(0xFF244936);
const lime = Color(0xFFDDF476);
const canvas = Color(0xFFF6F7F0);
const line = Color(0xFFDDE5D9);
const softGreen = Color(0xFFE7F0E4);

ThemeData courierTheme() {
  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: forest,
      brightness: Brightness.light,
    ).copyWith(primary: forest, surface: Colors.white, onSurface: ink),
    scaffoldBackgroundColor: canvas,
    dividerColor: line,
    appBarTheme: const AppBarTheme(
      backgroundColor: canvas,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        side: const BorderSide(color: forest),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
  );
  return theme.copyWith(
    textTheme: theme.textTheme.apply(bodyColor: ink, displayColor: ink),
  );
}
