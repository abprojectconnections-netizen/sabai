import 'package:flutter/material.dart';

import 'database/local_database.dart';
import 'features/demo/controllers/demo_controller.dart';
import 'features/demo/views/portal_dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDatabase.initialize();
  runApp(const TravelApp());
}

class TravelApp extends StatelessWidget {
  const TravelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Travel UI',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A1628),
        cardColor: const Color(0xFF162035),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF00C9A7),
          secondary: const Color(0xFF00A88C),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFE8F0FE)),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFE8F0FE)),
          bodyMedium: TextStyle(color: Color(0xFFE8F0FE)),
          bodySmall: TextStyle(color: Color(0xFFB0C4DE)),
        ),
      ),
      home: const TravelHomePage(),
    );
  }
}

class TravelHomePage extends StatefulWidget {
  const TravelHomePage({super.key});

  @override
  State<TravelHomePage> createState() => _TravelHomePageState();
}

class _TravelHomePageState extends State<TravelHomePage> {
  int _selectedIndex = 0;
  final DemoController _demoController = DemoController();

  static const List<Widget> _screens = [
    HomeScreen(),
    FlightsScreen(),
    ExploreScreen(),
    CalendarScreen(),
    AssistScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _openPortal(DemoPortal portal) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PortalDashboard(portal: portal, controller: _demoController),
      ),
    );
  }

  void _showDemoSwitcher() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF162035),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.white24, borderRadius: BorderRadius.circular(4)))),
                const SizedBox(height: 18),
                const Text('Travel Super App demo',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Switch between the four product domains.',
                    style: TextStyle(color: Color(0xFFB0C4DE))),
                const SizedBox(height: 16),
                _PortalSelector(
                    title: 'User application',
                    subtitle: 'Discovery, booking, trips & travel tools',
                    icon: Icons.explore_outlined,
                    color: const Color(0xFF00C9A7),
                    onTap: () => Navigator.pop(sheetContext)),
                _PortalSelector(
                    title: 'Partner portal',
                    subtitle: 'Inventory, revenue & promotions',
                    icon: Icons.storefront_outlined,
                    color: const Color(0xFF8B5CF6),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _openPortal(DemoPortal.partner);
                    }),
                _PortalSelector(
                    title: 'Staff backoffice',
                    subtitle: 'Support, approvals & operations',
                    icon: Icons.support_agent_outlined,
                    color: const Color(0xFFF59E0B),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _openPortal(DemoPortal.staff);
                    }),
                _PortalSelector(
                    title: 'Administration',
                    subtitle: 'Executive KPIs & system controls',
                    icon: Icons.admin_panel_settings_outlined,
                    color: const Color(0xFF38BDF8),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _openPortal(DemoPortal.admin);
                    }),
              ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _screens[_selectedIndex]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showDemoSwitcher,
        backgroundColor: const Color(0xFF00C9A7),
        foregroundColor: const Color(0xFF0A1628),
        icon: const Icon(Icons.grid_view_rounded),
        label: const Text('Demo', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF101F3A),
        selectedItemColor: const Color(0xFF00C9A7),
        unselectedItemColor: const Color(0xFF8BA0BC),
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.flight_outlined), label: 'Flights'),
          BottomNavigationBarItem(icon: Icon(Icons.search_outlined), label: 'Explore'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), label: 'Planner'),
          BottomNavigationBarItem(icon: Icon(Icons.support_outlined), label: 'Assist'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class _PortalSelector extends StatelessWidget {
  const _PortalSelector(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.color,
      required this.onTap});
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        leading:
            CircleAvatar(backgroundColor: color.withOpacity(.16), child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFFB0C4DE))),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFFB0C4DE)),
      );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: _StatusBar(),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              const _HomeHeader(),
              const SizedBox(height: 8),
              const _SearchBox(),
              const _FilterChips(),
              const _SectionHeader(title: 'Trending Destinations', actionText: 'See all →'),
              const _TrendingDestinations(),
              const _SectionHeader(title: 'Your Upcoming Trips', actionText: 'Manage →'),
              const _TripCard(
                emoji: '🏯',
                title: 'Kyoto Explorer',
                subtitle: 'May 12 – May 20, 2025 · 8 days',
                progress: 0.65,
                status: '65% planned · 3 activities left',
                gradient: LinearGradient(colors: [Color(0xFF0F4C6D), Color(0xFF0A2840)]),
              ),
              const _TripCard(
                emoji: '🌴',
                title: 'Bali Escape',
                subtitle: 'Jul 3 – Jul 10, 2025 · 7 days',
                progress: 0.20,
                status: '20% planned · Just started',
                gradient: LinearGradient(colors: [Color(0xFF1A3A20), Color(0xFF0D2D15)]),
              ),
              const SizedBox(height: 12),
              const _AdBanner(
                label: 'AD',
                title: 'Get 30% off travel insurance',
                subtitle: 'Protect your trip with AXA Travel Guard',
                buttonText: 'Learn more',
                gradient: LinearGradient(colors: [Color(0xFF1A0A2E), Color(0xFF2D1563)]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class FlightsScreen extends StatelessWidget {
  const FlightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: _ScreenHeader(
              title: 'Search Flights', subtitle: 'Compare prices across all airlines'),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _RouteSelector(),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C9A7),
              foregroundColor: const Color(0xFF0A1628),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Search Flights',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _SectionHeader(title: 'Best Results', actionText: 'Filter ≡'),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _FlightResultCard(
            icon: '✈️',
            airline: 'Thai Airways',
            details: 'Economy · Direct',
            price: '฿8,420',
            depart: '07:30',
            departAirport: 'BKK',
            arrive: '14:00',
            arriveAirport: 'NRT',
            duration: '5h 30m',
            stopInfo: 'Non-stop',
            badge: 'Best Value',
          ),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _FlightResultCard(
            icon: '🇯🇵',
            airline: 'Japan Airlines',
            details: 'Economy · 1 Stop',
            price: '฿7,190',
            depart: '09:15',
            departAirport: 'BKK',
            arrive: '19:00',
            arriveAirport: 'NRT',
            duration: '8h 45m',
            stopInfo: '1 stop · KUL',
          ),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _FlightResultCard(
            icon: '🌏',
            airline: 'AirAsia X',
            details: 'Economy · Direct',
            price: '฿5,880',
            depart: '22:45',
            departAirport: 'BKK',
            arrive: '06:35',
            arriveAirport: 'NRT',
            duration: '5h 50m',
            stopInfo: 'Non-stop',
          ),
        ),
      ],
    );
  }
}

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: _ScreenHeader(title: 'Explore', subtitle: 'Attractions · Hotels · Restaurants'),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _CategoryGrid(),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _SectionHeader(title: 'Top Attractions', actionText: 'Map view'),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _AttractionCard(
            emoji: '⛩️',
            name: 'Fushimi Inari Shrine',
            location: 'Kyoto, Japan',
            rating: '★★★★★',
            reviews: '4.9 (2,341)',
            tag: 'History · Free entry',
          ),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _AttractionCard(
            emoji: '🏔️',
            name: 'Mount Fuji Day Trip',
            location: 'Yamanashi, Japan',
            rating: '★★★★★',
            reviews: '4.8 (1,092)',
            tag: 'Adventure · From ฿1,200',
          ),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _MapPlaceholder(),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _SectionHeader(title: 'Recommended Hotels', actionText: 'See all'),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _HotelCard(
            emoji: '🏨',
            name: 'The Ritz-Carlton Kyoto',
            stars: '★★★★★',
            reviews: '4.9 · 856 reviews',
            price: '฿12,400',
          ),
        ),
      ],
    );
  }
}

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: _ScreenHeader(title: 'Trip Timeline', subtitle: 'Kyoto Explorer · May 2025'),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _CalendarBlock(),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _TimelineItem(
            day: 'Day 1',
            date: 'Monday, May 12, 2025',
            events: [
              _TimelineEvent(
                  time: '07:30',
                  color: Color(0xFFFF6B6B),
                  title: 'Flight TG622 · BKK → NRT',
                  subtitle: 'Thai Airways · Economy · Gate B12'),
              _TimelineEvent(
                  time: '14:00',
                  color: Color(0xFFFFB347),
                  title: 'Arrive NRT · Transfer to Kyoto',
                  subtitle: 'Shinkansen · ~2h 30m · ¥13,870'),
              _TimelineEvent(
                  time: '18:00',
                  color: Color(0xFF00C9A7),
                  title: 'Hotel Check-in · Ritz-Carlton Kyoto',
                  subtitle: 'Confirmation #RC-28741 · Room 812'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _TimelineItem(
            day: 'Day 2',
            date: 'Tuesday, May 13, 2025',
            events: [
              _TimelineEvent(
                  time: '08:00',
                  color: Color(0xFF00C9A7),
                  title: 'Fushimi Inari Morning Visit',
                  subtitle: 'Free entry · Bring camera · 3h estimated'),
              _TimelineEvent(
                  time: '13:00',
                  color: Color(0xFF4ECDC4),
                  title: 'Lunch · Nishiki Market',
                  subtitle: 'Local street food · Budget ฿400'),
            ],
          ),
        ),
      ],
    );
  }
}

class AssistScreen extends StatelessWidget {
  const AssistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: _ScreenHeader(
              title: 'Travel Assistant', subtitle: 'Everything you need, offline-ready'),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _WeatherStrip(),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _CurrencyCard(),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _AssistGrid(),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _AdBanner(
            label: 'AFFILIATE',
            title: 'Klook: Skip the line tickets',
            subtitle: 'Save up to 25% on Fushimi Inari tours',
            buttonText: 'Shop on Klook',
            gradient: LinearGradient(colors: [Color(0xFF1A0A2E), Color(0xFF2D1563)]),
          ),
        ),
      ],
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        const _ProfileHero(),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _MenuItem(
            emoji: '🎫',
            title: 'Boarding Passes',
            subtitle: '3 upcoming flights',
            backgroundColor: Color(0x1A00C9A7),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _MenuItem(
            emoji: '⭐',
            title: 'Saved Places',
            subtitle: '28 saved attractions',
            backgroundColor: Color(0x1AFFC948),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _MenuItem(
            emoji: '📤',
            title: 'Share Itinerary',
            subtitle: 'Send to friends or export PDF',
            backgroundColor: Color(0x1A4ECDC4),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _MenuItem(
            emoji: '🛂',
            title: 'Travel Documents',
            subtitle: 'Passport · Thai · Expires 2028',
            backgroundColor: Color(0x1FFF6B6B),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _MenuItem(
            emoji: '⚙️',
            title: 'Settings & Preferences',
            subtitle: 'Language, currency, notifications',
            backgroundColor: Color(0x1A8BA0BC),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _MenuItem(
            emoji: '👤',
            title: 'Guest Mode',
            subtitle: 'Browse without signing in',
            backgroundColor: Color(0x1A00C9A7),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0x1FFF6B6B),
              foregroundColor: const Color(0xFFFF6B6B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              side: const BorderSide(color: Color(0x29FF6B6B)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [
        Text('9:41 AM', style: TextStyle(color: Color(0xFF8BA0BC), fontSize: 11)),
        Text('▌▌▌ WiFi ⚡ 87%', style: TextStyle(color: Color(0xFF8BA0BC), fontSize: 11)),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF172847), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text('Good morning, traveler ✈️',
                style: TextStyle(color: Color(0xFF8BA0BC), fontSize: 13)),
            SizedBox(height: 2),
            Text('Where to next?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          ]),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF1E2E47),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: Colors.white12),
            ),
            child: const Icon(Icons.notifications_none, size: 18, color: Color(0xFFB0C4DE)),
          ),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2E47),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: const [
          Icon(Icons.search, color: Color(0xFF8BA0BC), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text('Search destinations, hotels, flights...',
                style: TextStyle(color: Color(0xFF8BA0BC), fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips();

  @override
  Widget build(BuildContext context) {
    final labels = ['All', 'Nature 🌿', 'History 🏛️', 'Adventure 🧗', 'Lifestyle ☕', 'Budget'];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final active = index == 0;
          return Chip(
            label: Text(labels[index],
                style: TextStyle(
                    color: active ? const Color(0xFF0A1628) : const Color(0xFFB0C4DE),
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            backgroundColor: active ? const Color(0xFF00C9A7) : const Color(0xFF1E2E47),
            shape: StadiumBorder(
                side: BorderSide(color: active ? const Color(0xFF00C9A7) : Colors.white12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionText;
  const _SectionHeader({required this.title, required this.actionText});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          Text(actionText, style: const TextStyle(color: Color(0xFF00C9A7), fontSize: 12)),
        ],
      ),
    );
  }
}

class _TrendingDestinations extends StatefulWidget {
  const _TrendingDestinations();

  @override
  State<_TrendingDestinations> createState() => _TrendingDestinationsState();
}

class _TrendingDestinationsState extends State<_TrendingDestinations> {
  late final Future<List<Destination>> _destinationsFuture;

  @override
  void initState() {
    super.initState();
    _destinationsFuture = LocalDatabase.instance.then((db) => db.getDestinations());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Destination>>(
      future: _destinationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final cards = snapshot.data ?? [];

        if (cards.isEmpty) {
          return const SizedBox(
            height: 200,
            child: Center(
                child: Text('No trending destinations found',
                    style: TextStyle(color: Colors.white70))),
          );
        }

        return SizedBox(
          height: 200,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final card = cards[index];
              return Container(
                width: 170,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: const Color(0xFF0A1628),
                    border: Border.all(color: Colors.white12)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      Container(
                          decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  colors: [Color(card.gradientStart), Color(card.gradientEnd)]))),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Align(
                              alignment: Alignment.center,
                              child: Container(
                                width: double.infinity,
                                height: 120,
                                decoration: const BoxDecoration(
                                    borderRadius: BorderRadius.all(Radius.circular(16))),
                                child: Center(
                                    child: Text(card.emoji, style: const TextStyle(fontSize: 60))),
                              ),
                            ),
                            const Spacer(),
                            if (card.label.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: const Color(0xE000C9A7),
                                    borderRadius: BorderRadius.circular(20)),
                                child: Text(card.label,
                                    style: const TextStyle(
                                        color: Color(0xFF0A1628),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600)),
                              ),
                            const SizedBox(height: 6),
                            Text(card.title,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('★ ${card.meta}',
                                style: const TextStyle(fontSize: 11, color: Color(0x99FFFFFF))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _DestCardData {
  final String emoji;
  final String label;
  final String title;
  final String meta;
  final Gradient gradient;
  const _DestCardData(
      {required this.emoji,
      required this.label,
      required this.title,
      required this.meta,
      required this.gradient});
}

class _TripCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final double progress;
  final String status;
  final Gradient gradient;
  const _TripCard(
      {required this.emoji,
      required this.title,
      required this.subtitle,
      required this.progress,
      required this.status,
      required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF162035),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: gradient),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 32))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF8BA0BC))),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                      value: progress,
                      color: const Color(0xFF00C9A7),
                      backgroundColor: const Color(0xFF0A1628),
                      minHeight: 4),
                ),
                const SizedBox(height: 6),
                Text(status, style: const TextStyle(fontSize: 11, color: Color(0xFF00C9A7))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdBanner extends StatelessWidget {
  final String label;
  final String title;
  final String subtitle;
  final String buttonText;
  final Gradient gradient;
  const _AdBanner(
      {required this.label,
      required this.title,
      required this.subtitle,
      required this.buttonText,
      required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x26FF3396)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Color(0x66FFFFFF), fontSize: 9, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 12)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0x26FFFFFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x40FFFFFF)),
            ),
            child: Text(buttonText,
                style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _ScreenHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Color(0xFF8BA0BC), fontSize: 13)),
      ],
    );
  }
}

class _RouteSelector extends StatelessWidget {
  const _RouteSelector();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF162035),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _RouteField(label: 'FROM', code: 'BKK', city: 'Bangkok, Thailand')),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(color: Color(0xFF00C9A7), shape: BoxShape.circle),
                child: const Icon(Icons.swap_vert, color: Color(0xFF0A1628), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: _RouteField(label: 'TO', code: 'NRT', city: 'Tokyo, Japan')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: const [
              Expanded(child: _DateField(label: 'DEPART', value: '12 May 2025')),
              SizedBox(width: 8),
              Expanded(child: _DateField(label: 'RETURN', value: '20 May 2025')),
              SizedBox(width: 8),
              SizedBox(width: 70, child: _DateField(label: 'PAX', value: '2 Adults')),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteField extends StatelessWidget {
  final String label;
  final String code;
  final String city;
  const _RouteField({required this.label, required this.code, required this.city});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration:
          BoxDecoration(color: const Color(0xFF1E2E47), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Color(0xFF8BA0BC), fontSize: 10)),
        const SizedBox(height: 4),
        Text(code, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(city, style: const TextStyle(color: Color(0xFFB0C4DE), fontSize: 11)),
      ]),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  const _DateField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration:
          BoxDecoration(color: const Color(0xFF1E2E47), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Color(0xFF8BA0BC), fontSize: 10)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _FlightResultCard extends StatelessWidget {
  final String icon;
  final String airline;
  final String details;
  final String price;
  final String depart;
  final String departAirport;
  final String arrive;
  final String arriveAirport;
  final String duration;
  final String stopInfo;
  final String? badge;
  const _FlightResultCard(
      {required this.icon,
      required this.airline,
      required this.details,
      required this.price,
      required this.depart,
      required this.departAirport,
      required this.arrive,
      required this.arriveAirport,
      required this.duration,
      required this.stopInfo,
      this.badge});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: const Color(0xFF162035),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12)),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: const Color(0xFF1E2E47), borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(airline, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                Text(details, style: const TextStyle(fontSize: 11, color: Color(0xFF8BA0BC))),
              ]),
            ),
            if (badge != null)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: const Color(0x1A00C9A7), borderRadius: BorderRadius.circular(20)),
                child: Text(badge!,
                    style: const TextStyle(
                        color: Color(0xFF00C9A7), fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            Text(price,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF00C9A7))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _FlightTimeBlock(time: depart, airport: departAirport),
            Expanded(
                child: Column(children: [
              Container(height: 1, color: const Color(0x26FFFFFF)),
              const SizedBox(height: 8),
              Text(duration, style: const TextStyle(fontSize: 11, color: Color(0xFF8BA0BC))),
              const SizedBox(height: 4),
              Text(stopInfo, style: const TextStyle(fontSize: 10, color: Color(0xFFFF6B6B))),
            ])),
            _FlightTimeBlock(time: arrive, airport: arriveAirport),
          ]),
        ),
      ]),
    );
  }
}

class _FlightTimeBlock extends StatelessWidget {
  final String time;
  final String airport;
  const _FlightTimeBlock({required this.time, required this.airport});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(time, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(airport, style: const TextStyle(fontSize: 11, color: Color(0xFF8BA0BC))),
    ]);
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid();

  @override
  Widget build(BuildContext context) {
    final items = [
      _CategoryData(
          emoji: '🌿',
          title: 'Nature',
          subtitle: '142 places',
          colors: [Color(0xFF1A3A2A), Color(0xFF0F6E56)]),
      _CategoryData(
          emoji: '🏛️',
          title: 'History',
          subtitle: '89 places',
          colors: [Color(0xFF2A1A0A), Color(0xFF854F0B)]),
      _CategoryData(
          emoji: '☕',
          title: 'Lifestyle',
          subtitle: '211 places',
          colors: [Color(0xFF1A1A3A), Color(0xFF534AB7)]),
      _CategoryData(
          emoji: '🧗',
          title: 'Adventure',
          subtitle: '63 places',
          colors: [Color(0xFF3A1A1A), Color(0xFF993C1D)]),
    ];
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.05),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(colors: item.colors)),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.emoji, style: const TextStyle(fontSize: 28)),
            const Spacer(),
            Text(item.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(item.subtitle, style: const TextStyle(fontSize: 11, color: Color(0x99FFFFFF))),
          ]),
        );
      },
    );
  }
}

class _CategoryData {
  final String emoji;
  final String title;
  final String subtitle;
  final List<Color> colors;
  const _CategoryData(
      {required this.emoji, required this.title, required this.subtitle, required this.colors});
}

class _AttractionCard extends StatelessWidget {
  final String emoji;
  final String name;
  final String location;
  final String rating;
  final String reviews;
  final String tag;
  const _AttractionCard(
      {required this.emoji,
      required this.name,
      required this.location,
      required this.rating,
      required this.reviews,
      required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFF162035),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12)),
      child: Row(children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
              color: const Color(0xFF1E2E47), borderRadius: BorderRadius.circular(20)),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 36))),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.location_on_outlined, size: 11, color: Color(0xFF8BA0BC)),
              const SizedBox(width: 4),
              Text(location, style: const TextStyle(fontSize: 11, color: Color(0xFF8BA0BC)))
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Text(rating, style: const TextStyle(fontSize: 11, color: Color(0xFFF7C948))),
              const SizedBox(width: 6),
              Text(reviews, style: const TextStyle(fontSize: 11, color: Color(0xFF8BA0BC)))
            ]),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: const Color(0x1A00C9A7), borderRadius: BorderRadius.circular(20)),
              child: Text(tag, style: const TextStyle(color: Color(0xFF00C9A7), fontSize: 10)),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
          color: const Color(0xFF1E2E47),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12)),
      child: Stack(children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _GridPainter(),
          ),
        ),
        const Positioned(top: 40, left: 130, child: Text('📍', style: TextStyle(fontSize: 24))),
        const Positioned(top: 70, left: 180, child: Text('📍', style: TextStyle(fontSize: 24))),
        Positioned(
          bottom: 12,
          left: 16,
          right: 16,
          child: Row(children: const [
            Icon(Icons.location_pin, color: Color(0xFF00C9A7), size: 20),
            SizedBox(width: 8),
            Expanded(
                child: Text('Interactive Map · 14 places nearby',
                    style: TextStyle(fontSize: 13, color: Color(0xFF8BA0BC)))),
          ]),
        ),
      ]),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 0.5;
    for (double x = 0; x <= size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HotelCard extends StatelessWidget {
  final String emoji;
  final String name;
  final String stars;
  final String reviews;
  final String price;
  const _HotelCard(
      {required this.emoji,
      required this.name,
      required this.stars,
      required this.reviews,
      required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: const Color(0xFF162035),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12)),
      child: Column(children: [
        Container(
          height: 110,
          decoration: BoxDecoration(
              color: const Color(0xFF1E2E47),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 48))),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(children: [
              Text(stars, style: const TextStyle(fontSize: 11, color: Color(0xFFF7C948))),
              const SizedBox(width: 8),
              Text(reviews, style: const TextStyle(fontSize: 11, color: Color(0xFF8BA0BC)))
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                Text(price,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF00C9A7))),
                const SizedBox(width: 4),
                const Text('/ night', style: TextStyle(fontSize: 11, color: Color(0xFF8BA0BC)))
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                    color: const Color(0xFF00C9A7), borderRadius: BorderRadius.circular(16)),
                child: const Text('Book Now',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0A1628))),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _CalendarBlock extends StatelessWidget {
  const _CalendarBlock();

  @override
  Widget build(BuildContext context) {
    final days = [
      '',
      '',
      '',
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      '10',
      '11',
      '12',
      '13',
      '14',
      '15',
      '16',
      '17',
      '18',
      '19',
      '20',
      '21',
      '22',
      '23',
      '24',
      '25',
      '26',
      '27',
      '28',
      '29',
      '30',
      '31',
      '',
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('May 2025', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 7,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.1,
        children: [
          ...['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'].map((label) => Center(
              child: Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF8BA0BC))))),
          ...days.map((day) {
            final isEmpty = day.isEmpty;
            final isSelected = day == '12' || day == '20';
            final isToday = day == '23';
            final isRange = ['13', '14', '15', '16', '17', '18', '19'].contains(day);
            final hasEvent = ['13', '14', '15', '16', '17', '18', '19'].contains(day);
            Color? bg;
            Color textColor = const Color(0xFFB0C4DE);
            if (isSelected) {
              bg = const Color(0xFF00C9A7);
              textColor = const Color(0xFF0A1628);
            } else if (isToday) {
              bg = const Color(0xFF1E2E47);
              textColor = Colors.white;
            } else if (isRange) {
              bg = const Color(0x2600C9A7);
              textColor = const Color(0xFF00C9A7);
            }
            return Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(day.isEmpty ? '' : day,
                    style: TextStyle(
                        fontSize: 13,
                        color: textColor,
                        fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.normal)),
              ),
            );
          }),
        ],
      ),
      const SizedBox(height: 12),
      Row(children: [
        _LegendDot(color: const Color(0xFFFF6B6B), label: 'Flight'),
        const SizedBox(width: 16),
        _LegendDot(color: const Color(0xFFFFB347), label: 'Hotel check-in'),
        const SizedBox(width: 16),
        _LegendDot(color: const Color(0xFF00C9A7), label: 'Activity'),
      ]),
    ]);
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF8BA0BC))),
    ]);
  }
}

class _TimelineItem extends StatelessWidget {
  final String day;
  final String date;
  final List<_TimelineEvent> events;
  const _TimelineItem({required this.day, required this.date, required this.events});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
              color: const Color(0xFF00C9A7), borderRadius: BorderRadius.circular(20)),
          child: Text(day,
              style: const TextStyle(
                  color: Color(0xFF0A1628), fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        Text(date, style: const TextStyle(color: Color(0xFF8BA0BC), fontSize: 12)),
      ]),
      const SizedBox(height: 12),
      ...events.map((event) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                  width: 40,
                  child: Text(event.time,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF8BA0BC)))),
              Column(children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: event.color, shape: BoxShape.circle)),
                Container(width: 1, height: 60, color: const Color(0x26FFFFFF)),
              ]),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xFF162035),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(event.title,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(event.subtitle,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF8BA0BC))),
                  ]),
                ),
              ),
            ]),
          )),
    ]);
  }
}

class _TimelineEvent {
  final String time;
  final Color color;
  final String title;
  final String subtitle;
  const _TimelineEvent(
      {required this.time, required this.color, required this.title, required this.subtitle});
}

class _WeatherStrip extends StatelessWidget {
  const _WeatherStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFF1A2840),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text('Kyoto, Japan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text('Partly cloudy · Humidity 68%',
                style: TextStyle(fontSize: 12, color: Color(0xFF8BA0BC))),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: const [
            Text('⛅', style: TextStyle(fontSize: 40)),
            SizedBox(height: 4),
            Text('24°C', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
          ]),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: const Color(0x26FF6B6B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x40FF6B6B))),
          child: const Text('⚠️ Rain expected May 15–16. Pack an umbrella!',
              style: TextStyle(fontSize: 12, color: Color(0xFFFF6B6B))),
        ),
      ]),
    );
  }
}

class _CurrencyCard extends StatelessWidget {
  const _CurrencyCard();

  @override
  Widget build(BuildContext context) {
    final rates = [
      _CurrencyData(flag: '🇯🇵', name: 'Japanese Yen', code: 'JPY', rate: '4.24 ¥'),
      _CurrencyData(flag: '🇺🇸', name: 'US Dollar', code: 'USD', rate: '0.028 \$'),
      _CurrencyData(flag: '🇪🇺', name: 'Euro', code: 'EUR', rate: '0.026 €'),
      _CurrencyData(flag: '🇸🇬', name: 'Singapore Dollar', code: 'SGD', rate: '0.038 S\$'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFF1E2E47),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Currency Rates · 1 THB =',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        ...rates.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  Text(item.flag, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.name, style: const TextStyle(fontSize: 13)),
                    Text(item.code, style: const TextStyle(fontSize: 11, color: Color(0xFF8BA0BC)))
                  ]),
                ]),
                Text(item.rate,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF00C9A7))),
              ]),
            )),
      ]),
    );
  }
}

class _CurrencyData {
  final String flag;
  final String name;
  final String code;
  final String rate;
  const _CurrencyData(
      {required this.flag, required this.name, required this.code, required this.rate});
}

class _AssistGrid extends StatelessWidget {
  const _AssistGrid();

  @override
  Widget build(BuildContext context) {
    final items = [
      _AssistData(
          icon: '🗺️',
          title: 'Offline Maps',
          subtitle: 'Downloaded for Kyoto region',
          badge: '532 MB saved'),
      _AssistData(
          icon: '🛂', title: 'Documents', subtitle: 'Passport, Visa, Insurance', badge: '3 stored'),
      _AssistData(
          icon: '📡', title: 'Travel SIM', subtitle: 'eSIM for Japan · 10GB', badge: 'Active'),
      _AssistData(
          icon: '🆘',
          title: 'Emergency',
          subtitle: 'Local contacts & hotlines',
          badge: 'Offline ready'),
    ];
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.05),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: const Color(0xFF162035),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 10),
            Text(item.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(item.subtitle,
                style: const TextStyle(fontSize: 11, color: Color(0xFF8BA0BC), height: 1.4)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: const Color(0x1A00C9A7), borderRadius: BorderRadius.circular(20)),
              child:
                  Text(item.badge, style: const TextStyle(color: Color(0xFF00C9A7), fontSize: 10)),
            ),
          ]),
        );
      },
    );
  }
}

class _AssistData {
  final String icon;
  final String title;
  final String subtitle;
  final String badge;
  const _AssistData(
      {required this.icon, required this.title, required this.subtitle, required this.badge});
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
      decoration:
          BoxDecoration(color: const Color(0xFF162035), borderRadius: BorderRadius.circular(24)),
      child: Column(children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF00C9A7), Color(0xFF00A88C)]),
              borderRadius: BorderRadius.circular(100)),
          child: const Center(
              child: Text('KP',
                  style: TextStyle(
                      color: Color(0xFF0A1628), fontSize: 24, fontWeight: FontWeight.w700))),
        ),
        const SizedBox(height: 12),
        const Text('Krissada Panya', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        const Text('krissada.p@email.com',
            style: TextStyle(fontSize: 12, color: Color(0xFF8BA0BC))),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
              color: const Color(0xFF162035),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12)),
          child: Row(children: const [
            Expanded(child: _ProfileStat(value: '14', label: 'Trips')),
            Expanded(child: _ProfileStat(value: '23', label: 'Countries')),
            Expanded(child: _ProfileStat(value: '142', label: 'Places')),
          ]),
        ),
      ]),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String value;
  final String label;
  const _ProfileStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF8BA0BC))),
      ]),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color backgroundColor;
  const _MenuItem(
      {required this.emoji,
      required this.title,
      required this.subtitle,
      required this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFF162035),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12)),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration:
              BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(16)),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF8BA0BC))),
          ]),
        ),
        const Icon(Icons.chevron_right, color: Color(0xFF8BA0BC), size: 18),
      ]),
    );
  }
}
