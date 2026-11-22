import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/app_config.dart';
import 'core/util/external_links.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/app_repository.dart';
import 'features/shell/home_shell.dart';
import 'state/admin_controller.dart';
import 'state/app_state.dart';
import 'state/community_controller.dart';
import 'state/coupons_controller.dart';
import 'state/moderation_controller.dart';
import 'state/notifications_controller.dart';
import 'state/reviews_controller.dart';
import 'state/settings_controller.dart';
import 'state/trips_controller.dart';

class SabaiApp extends StatelessWidget {
  const SabaiApp({
    super.key,
    required this.config,
    required this.repository,
    required this.prefs,
    this.urlOpener = openExternally,
  });

  final AppConfig config;
  final AppRepository repository;
  final SharedPreferences prefs;

  /// Opens external links (Google Maps). Tests pass a fake.
  final UrlOpener urlOpener;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<UrlOpener>.value(value: urlOpener),
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
        ChangeNotifierProxyProvider<AppState, NotificationsController>(
          create: (_) => NotificationsController(repository),
          update: (_, app, c) {
            final n = c ?? NotificationsController(repository);
            if (!app.signedIn) n.reset();
            return n;
          },
        ),
        ChangeNotifierProxyProvider<AppState, ReviewsController>(
          create: (_) => ReviewsController(repository),
          update: (_, app, c) {
            final r = c ?? ReviewsController(repository);
            if (!app.signedIn) r.reset();
            return r;
          },
        ),
        ChangeNotifierProxyProvider<AppState, CommunityController>(
          create: (_) => CommunityController(repository),
          update: (_, app, c) {
            final x = c ?? CommunityController(repository);
            if (!app.signedIn) x.reset();
            return x;
          },
        ),
        ChangeNotifierProxyProvider<AppState, CouponsController>(
          create: (_) => CouponsController(repository),
          update: (_, app, c) {
            final x = c ?? CouponsController(repository);
            if (!app.signedIn) x.reset();
            return x;
          },
        ),
        ChangeNotifierProxyProvider<AppState, AdminController>(
          create: (_) => AdminController(repository),
          update: (_, app, c) {
            final x = c ?? AdminController(repository);
            if (!app.signedIn) x.reset();
            return x;
          },
        ),
        ChangeNotifierProxyProvider<AppState, ModerationController>(
          create: (_) => ModerationController(repository),
          update: (_, app, c) {
            final x = c ?? ModerationController(repository);
            if (!app.signedIn) x.reset();
            return x;
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
