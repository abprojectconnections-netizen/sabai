import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../state/app_state.dart';
import '../auth/login_screen.dart';
import '../booking/my_bookings_screen.dart';
import '../catalog/catalog_screen.dart';
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
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sabai'),
        actions: [
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
        ],
      ),
    );
  }
}
