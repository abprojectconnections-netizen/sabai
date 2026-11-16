import 'package:flutter/material.dart';

const Color sabaiSeed = Color(0xFF10403D);

ThemeData buildSabaiTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: sabaiSeed);
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
