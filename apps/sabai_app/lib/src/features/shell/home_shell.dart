import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../state/app_state.dart';
import '../auth/login_screen.dart';
import '../booking/my_bookings_screen.dart';
import '../catalog/catalog_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../trips/trips_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.config});

  final AppConfig config;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pages = <Widget>[
      const CatalogScreen(),
      const TripsScreen(),
      state.signedIn ? const MyBookingsScreen() : const SignInPrompt(),
      const ProfileScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sabai'),
        actions: [
          if (state.signedIn) const NotificationBell(),
          if (widget.config.appEnv != AppEnv.production)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Chip(label: Text(widget.config.apiMode.name.toUpperCase())),
            ),
        ],
      ),
      body: state.booting
          ? const Center(child: CircularProgressIndicator())
          : pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'ค้นหา'),
          NavigationDestination(icon: Icon(Icons.luggage_outlined), label: 'ทริป'),
          NavigationDestination(icon: Icon(Icons.confirmation_number_outlined), label: 'การจอง'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'โปรไฟล์'),
        ],
      ),
    );
  }
}
