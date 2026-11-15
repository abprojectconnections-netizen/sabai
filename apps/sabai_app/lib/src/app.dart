import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/app_repository.dart';
import 'features/shell/home_shell.dart';
import 'state/app_state.dart';

class SabaiApp extends StatelessWidget {
  const SabaiApp({super.key, required this.config, required this.repository});

  final AppConfig config;
  final AppRepository repository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>(
      create: (_) => AppState(repository)..boot(),
      child: MaterialApp(
        title: 'Sabai',
        debugShowCheckedModeBanner: false,
        theme: buildSabaiTheme(),
        home: HomeShell(config: config),
      ),
    );
  }
}
