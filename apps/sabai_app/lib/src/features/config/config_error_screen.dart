import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Shown instead of the app when the build configuration is invalid.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.problems});

  final List<String> problems;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildSabaiTheme(),
      home: Scaffold(
        appBar: AppBar(title: const Text('การตั้งค่าไม่ถูกต้อง')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('แอปไม่เริ่มทำงานเพื่อความปลอดภัย แก้ค่า --dart-define แล้วรันใหม่'),
            const SizedBox(height: 12),
            for (final p in problems) Text('• $p'),
          ],
        ),
      ),
    );
  }
}
