import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/app_repository.dart';
import 'features/shell/home_shell.dart';
import 'state/app_state.dart';
import 'state/settings_controller.dart';
import 'state/trips_controller.dart';

class SabaiApp extends StatelessWidget {
  const SabaiApp({super.key, required this.config, required this.repository, required this.prefs});

  final AppConfig config;
  final AppRepository repository;
  final SharedPreferences prefs;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>(create: (_) => AppState(repository)..boot()),
        ChangeNotifierProvider<SettingsController>(create: (_) => SettingsController(prefs)),
        // Trips belong to the signed-in user: clear them whenever the user signs out.
        ChangeNotifierProxyProvider<AppState, TripsController>(
          create: (_) => TripsController(repository),
          update: (_, app, trips) {
            final c = trips ?? TripsController(repository);
            if (!app.signedIn) c.reset();
            return c;
          },
        ),
      ],
      child: Consumer<SettingsController>(
        builder: (context, settings, _) => MaterialApp(
          title: 'Sabai',
          debugShowCheckedModeBanner: false,
          theme: buildSabaiTheme(),
          darkTheme: buildSabaiTheme(Brightness.dark),
          themeMode: settings.themeMode,
          home: HomeShell(config: config),
        ),
      ),
    );
  }
}
