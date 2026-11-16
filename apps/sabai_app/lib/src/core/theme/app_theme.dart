import 'package:flutter/material.dart';

const Color sabaiSeed = Color(0xFF10403D);

ThemeData buildSabaiTheme([Brightness brightness = Brightness.light]) {
  final scheme = ColorScheme.fromSeed(seedColor: sabaiSeed, brightness: brightness);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      centerTitle: false,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );
}
