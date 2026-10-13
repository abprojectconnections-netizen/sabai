import 'package:flutter/material.dart';

import 'database/local_database.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/views/auth_screen.dart';
import 'features/demo/controllers/demo_controller.dart';
import 'features/demo/views/portal_dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TravelApp());
}

class TravelApp extends StatelessWidget {
  const TravelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sabai Travel',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFAFAF8),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF10403D),
          primary: const Color(0xFF10403D),
          secondary: const Color(0xFFE3A23C),
          surface: const Color(0xFFFFFFFF),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFAFAF8),
          foregroundColor: Color(0xFF16241F),
          elevation: 0,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: Color(0xFFE4EDEA),
        ),
      ),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  AuthSession? _session;
  bool _isGuest = false;

  @override
  Widget build(BuildContext context) {
    if (_session == null && !_isGuest) {
      return AuthScreen(
        onAuthenticated: (session) => setState(() => _session = session),
        onContinueAsGuest: () => setState(() => _isGuest = true),
      );
    }
    return TravelHomePage(
      displayName: _session?.displayName ?? '',
      email: _session?.email ?? '',
      isGuest: _isGuest,
      onLogout: () => setState(() {
        _session = null;
        _isGuest = false;
      }),
    );
  }
}

class TravelHomePage extends StatefulWidget {
  const TravelHomePage({
    required this.displayName,
    required this.email,
    required this.isGuest,
    required this.onLogout,
    super.key,
  });

  final String displayName;
  final String email;
  final bool isGuest;
  final VoidCallback onLogout;

  @override
  State<TravelHomePage> createState() => _TravelHomePageState();
}

class _TravelHomePageState extends State<TravelHomePage> {
  int _selectedIndex = 0;
  bool _showBookings = false;
  String _searchQuery = '';
  String _category = 'ทั้งหมด';
  String _destination = 'เชียงใหม่';
  int _days = 3;
  int _travelers = 2;
  int _budget = 10000;
  bool _generating = false;
  Map<String, dynamic>? _itinerary;
  final Set<String> _styles = {'ธรรมชาติ', 'อาหารท้องถิ่น'};
  final List<Map<String, dynamic>> _savedTrips = [];
  final List<Map<String, dynamic>> _bookings = [
    {
      'title': 'ล้านนา วิว รีสอร์ท',
      'destination': 'เชียงใหม่',
      'date': '14 ธ.ค. – 16 ธ.ค.',
      'amount': 2980,
      'status': 'จ่ายแล้ว',
      'icon': Icons.hotel_rounded,
      'color': const Color(0xFF10403D),
    },
    {
      'title': 'วัดพระธาตุดอยสุเทพ',
      'destination': 'เชียงใหม่',
      'date': '15 ธ.ค.',
      'amount': 520,
      'status': 'รอตรวจสอบ',
      'icon': Icons.temple_buddhist_rounded,
      'color': const Color(0xFF695083),
    },
  ];
  final DemoController _demoController = DemoController();

  static const List<Map<String, dynamic>> _destinations = [
    {
      'name': 'เชียงใหม่',
      'subtitle': 'ภูเขา ธรรมชาติ วัฒนธรรมล้านนา',
      'icon': Icons.landscape_rounded,
      'colors': [Color(0xFF1C5C57), Color(0xFF89A66B)]
    },
    {
      'name': 'ภูเก็ต',
      'subtitle': 'ทะเลอันดามัน ชายหาดสวย',
      'icon': Icons.beach_access_rounded,
      'colors': [Color(0xFF0B4F6C), Color(0xFF01BAEF)]
    },
    {
      'name': 'กระบี่',
      'subtitle': 'หน้าผาหินปูน เกาะแก่ง',
      'icon': Icons.sailing_rounded,
      'colors': [Color(0xFF123C69), Color(0xFF3E92CC)]
    },
    {
      'name': 'ปาย',
      'subtitle': 'หมอกยามเช้า คาเฟ่ริมเขา',
      'icon': Icons.wb_twilight_rounded,
      'colors': [Color(0xFF7A4B22), Color(0xFFE3A23C)]
    },
    {
      'name': 'กรุงเทพฯ',
      'subtitle': 'สตรีทฟู้ด ช้อปปิ้ง วัฒนธรรม',
      'icon': Icons.location_city_rounded,
      'colors': [Color(0xFF3B2352), Color(0xFFA768C9)]
    },
    {
      'name': 'เกาะสมุย',
      'subtitle': 'เกาะสวรรค์ ทะเลใส',
      'icon': Icons.water_rounded,
      'colors': [Color(0xFF0E6E55), Color(0xFF59C9A5)]
    },
  ];

  static const List<Map<String, dynamic>> _listings = [
    {
      'type': 'ที่พัก',
      'name': 'ล้านนา วิว รีสอร์ท',
      'location': 'นิมมานเหมินท์, เชียงใหม่',
      'rating': '4.8',
      'reviews': '342',
      'price': 1490,
      'icon': Icons.hotel_rounded,
      'color': Color(0xFF1C5C57)
    },
    {
      'type': 'อาหาร',
      'name': 'ข้าวซอยแม่สาย',
      'location': 'เมืองเก่า, เชียงใหม่',
      'rating': '4.6',
      'reviews': '891',
      'price': 120,
      'icon': Icons.restaurant_rounded,
      'color': Color(0xFFB5651D)
    },
    {
      'type': 'สถานที่เที่ยว',
      'name': 'วัดพระธาตุดอยสุเทพ',
      'location': 'ดอยสุเทพ, เชียงใหม่',
      'rating': '4.9',
      'reviews': '5,210',
      'price': 50,
      'icon': Icons.temple_buddhist_rounded,
      'color': Color(0xFF695083)
    },
    {
      'type': 'ที่พัก',
      'name': 'อันดามัน บีช วิลลา',
      'location': 'ป่าตอง, ภูเก็ต',
      'rating': '4.7',
      'reviews': '206',
      'price': 2350,
      'icon': Icons.hotel_rounded,
      'color': Color(0xFF1C5C57)
    },
    {
      'type': 'เที่ยวบิน',
      'name': 'กรุงเทพฯ → เชียงใหม่',
      'location': 'สายการบิน Sabai Air',
      'rating': '4.4',
      'reviews': '1,032',
      'price': 990,
      'icon': Icons.flight_rounded,
      'color': Color(0xFF24678A)
    },
    {
      'type': 'อาหาร',
      'name': 'ครัวทะเลกระบี่',
      'location': 'อ่าวนาง, กระบี่',
      'rating': '4.5',
      'reviews': '410',
      'price': 250,
      'icon': Icons.restaurant_rounded,
      'color': Color(0xFFB5651D)
    },
  ];

  static const List<String> _categories = [
    'ทั้งหมด',
    'ที่พัก',
    'อาหาร',
    'เที่ยวบิน',
    'สถานที่เที่ยว'
  ];
  static const List<String> _styleOptions = [
    'ธรรมชาติ',
    'อาหารท้องถิ่น',
    'วัฒนธรรม',
    'ผจญภัย',
    'ช้อปปิ้ง',
    'พักผ่อนสบายๆ'
  ];

  List<Map<String, dynamic>> get _filteredListings => _listings.where((item) {
        final bool matchesCategory = _category == 'ทั้งหมด' || item['type'] == _category;
        final String query = _searchQuery.trim().toLowerCase();
        final bool matchesQuery = query.isEmpty ||
            (item['name'] as String).toLowerCase().contains(query) ||
            (item['location'] as String).toLowerCase().contains(query);
        return matchesCategory && matchesQuery;
      }).toList();

  void _openPlanner() => setState(() {
        _selectedIndex = 2;
        _itinerary = null;
      });

  void _openBookingHistory() => setState(() {
        _selectedIndex = 3;
        _showBookings = true;
      });

  void _showNotifications() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFFAFAF8),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.notifications_none_rounded, size: 38, color: Color(0xFF10403D)),
              const SizedBox(height: 12),
              const Text('ยังไม่มีการแจ้งเตือนใหม่',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              const Text('เราจะแจ้งให้ทราบเมื่อมีอัปเดตเกี่ยวกับทริปของคุณ',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF5C6A64))),
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _openBookingHistory();
                },
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('ดูประวัติการจอง'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setTripsView(bool showBookings) => setState(() {
        _selectedIndex = 3;
        _showBookings = showBookings;
      });

  void _generateItinerary() {
    setState(() => _generating = true);
    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      final schedule = <List<String>>[
        ['09:00', 'เดินทางถึง$_destination เช็คอินที่พัก'],
        ['12:00', 'ลิ้มลองอาหารท้องถิ่นและเมนูขึ้นชื่อ'],
        [
          '14:00',
          if (_styles.isEmpty)
            'เดินเล่นชมเมืองและแวะคาเฟ่'
          else
            'กิจกรรมตามสไตล์ ${_styles.join(', ')}'
        ],
        ['18:30', 'ชมบรรยากาศยามเย็นและรับประทานอาหาร'],
      ];
      final List<Map<String, Object>> budgetItems = [
        {'label': 'การเดินทาง', 'value': (_budget * .28).round()},
        {'label': 'ที่พัก', 'value': (_budget * .35).round()},
        {'label': 'อาหาร', 'value': (_budget * .20).round()},
        {'label': 'กิจกรรม', 'value': (_budget * .10).round()},
        {'label': 'เดินทางในพื้นที่', 'value': (_budget * .07).round()},
      ];
      setState(() {
        _itinerary = {
          'days': List.generate(
              _days.clamp(1, 7),
              (index) => {
                    'title': 'วันที่ ${index + 1} · $_destination',
                    'items': schedule.map((entry) => {'time': entry[0], 'text': entry[1]}).toList(),
                  }),
          'budget': budgetItems,
        };
        _generating = false;
      });
    });
  }

  void _saveTrip() {
    if (_itinerary == null) return;
    setState(() {
      _savedTrips.insert(0, {
        'destination': _destination,
        'days': _days,
        'travelers': _travelers,
        'budget': _budget,
        'itinerary': _itinerary,
      });
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกทริปแล้ว')));
  }

  void _recordBooking(Map<String, dynamic> booking) {
    setState(() {
      _bookings.insert(0, booking);
      _selectedIndex = 3;
      _showBookings = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('สร้างรายการจองแล้ว • ยังไม่ได้เรียกเก็บเงิน')),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _openPortal(DemoPortal portal) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PortalDashboard(portal: portal, controller: _demoController),
      ),
    );
  }

  void _openListing(Map<String, dynamic> listing) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFAFAF8),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _ListingSheet(
        listing: listing,
        onCompletePayment: _recordBooking,
      ),
    );
  }

  Widget _currentScreen() {
    switch (_selectedIndex) {
      case 0:
        return _HomeMvpScreen(
          destinations: _destinations,
          onSearch: () => setState(() => _selectedIndex = 1),
          onNotificationsTap: _showNotifications,
          onQuickAction: (category) => setState(() {
            _category = category;
            _searchQuery = '';
            _selectedIndex = 1;
          }),
          onPlan: _openPlanner,
          onDestination: (destination) => setState(() {
            _searchQuery = destination;
            _selectedIndex = 1;
          }),
        );
      case 1:
        return _SearchMvpScreen(
          query: _searchQuery,
          category: _category,
          categories: _categories,
          listings: _filteredListings,
          onQuery: (value) => setState(() => _searchQuery = value),
          onCategory: (value) => setState(() => _category = value),
          onSelect: _openListing,
        );
      case 2:
        return _PlannerMvpScreen(
          destination: _destination,
          destinations: _destinations.map((item) => item['name'] as String).toList(),
          days: _days,
          travelers: _travelers,
          budget: _budget,
          styles: _styles,
          styleOptions: _styleOptions,
          generating: _generating,
          itinerary: _itinerary,
          onDestination: (value) => setState(() => _destination = value),
          onDays: (value) => setState(() => _days = value),
          onTravelers: (value) => setState(() => _travelers = value),
          onBudget: (value) => setState(() => _budget = value),
          onToggleStyle: (value) =>
              setState(() => _styles.contains(value) ? _styles.remove(value) : _styles.add(value)),
          onGenerate: _generateItinerary,
          onReset: () => setState(() => _itinerary = null),
          onSave: _saveTrip,
          isSaved: _savedTrips
              .any((trip) => trip['destination'] == _destination && trip['days'] == _days),
        );
      case 3:
        return _TripsMvpScreen(
          trips: _savedTrips,
          bookings: _bookings,
          showBookings: _showBookings,
          onPlan: _openPlanner,
          onViewChanged: _setTripsView,
        );
      default:
        return _ProfileMvpScreen(
          onOpenDemo: _showDemoSwitcher,
          onOpenHistory: _openBookingHistory,
          displayName: widget.displayName,
          email: widget.email,
          isGuest: widget.isGuest,
          onLogout: widget.onLogout,
        );
    }
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
    final navBar = NavigationBar(
      height: 72,
      elevation: 0,
      selectedIndex: _selectedIndex,
      onDestinationSelected: _onItemTapped,
      destinations: const [
        NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'หน้าแรก'),
        NavigationDestination(icon: Icon(Icons.search_rounded), label: 'ค้นหา'),
        NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'AI แพลน'),
        NavigationDestination(
            icon: Icon(Icons.luggage_outlined), selectedIcon: Icon(Icons.luggage), label: 'ทริป'),
        NavigationDestination(
            icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'โปรไฟล์'),
      ],
    );

    return ColoredBox(
      color: const Color(0xFFE7F2EE),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Scaffold(
            backgroundColor: const Color(0xFFFAFAF8),
            body: SafeArea(child: _currentScreen()),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: navBar,
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeMvpScreen extends StatelessWidget {
  const _HomeMvpScreen(
      {required this.destinations,
      required this.onSearch,
      required this.onNotificationsTap,
      required this.onQuickAction,
      required this.onPlan,
      required this.onDestination});
  final List<Map<String, dynamic>> destinations;
  final VoidCallback onSearch;
  final VoidCallback onNotificationsTap;
  final ValueChanged<String> onQuickAction;
  final VoidCallback onPlan;
  final ValueChanged<String> onDestination;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Row(children: [
            const Icon(Icons.location_on_outlined, size: 17, color: Color(0xFF5C6A64)),
            const SizedBox(width: 5),
            const Expanded(
                child: Text('กรุงเทพฯ, ประเทศไทย',
                    style: TextStyle(color: Color(0xFF5C6A64), fontWeight: FontWeight.w600))),
            IconButton(
                onPressed: onNotificationsTap,
                tooltip: 'การแจ้งเตือน',
                icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF16241F)))
          ]),
          const SizedBox(height: 8),
          const Text('สวัสดี, นักเดินทาง',
              style:
                  TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: Color(0xFF16241F))),
          const SizedBox(height: 4),
          const Text('วันนี้อยากไปเที่ยวที่ไหนดี?', style: TextStyle(color: Color(0xFF5C6A64))),
          const SizedBox(height: 18),
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10403D), Color(0xFF1C5C57)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Expanded(
                      child: Text('ทริปสุดคุ้มสำหรับวันหยุดนี้',
                          style: TextStyle(
                              color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800))),
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(999)),
                      child: const Text('3 วัน • 2 คน',
                          style: TextStyle(
                              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                ]),
                const SizedBox(height: 12),
                const Text('เชียงใหม่ • ธรรมชาติ • คาเฟ่ • วัฒนธรรม',
                    style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                const SizedBox(height: 16),
                Row(children: const [
                  _MiniStat(label: 'รีวิว', value: '3.2k'),
                  SizedBox(width: 10),
                  _MiniStat(label: 'จุดเด่น', value: '4.9/5'),
                  SizedBox(width: 10),
                  _MiniStat(label: 'ประหยัด', value: '฿8.9k'),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                        onPressed: onPlan,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                        label: const Text('วางแผนทริปนี้'),
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFE3A23C),
                            foregroundColor: const Color(0xFF3B2A11),
                            padding: const EdgeInsets.symmetric(vertical: 12))))
              ])),
          const SizedBox(height: 22),
          InkWell(
              onTap: onSearch,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE4E1D8))),
                  child: const Row(children: [
                    Icon(Icons.search, color: Color(0xFF5C6A64)),
                    SizedBox(width: 10),
                    Text('ค้นหาที่พัก ร้านอาหาร สถานที่เที่ยว',
                        style: TextStyle(color: Color(0xFF5C6A64), fontSize: 13))
                  ]))),
          const SizedBox(height: 22),
          Row(children: [
            Expanded(
                child: _QuickAction(
                    icon: Icons.flight_rounded,
                    label: 'เที่ยวบิน',
                    onTap: () => onQuickAction('เที่ยวบิน'))),
            Expanded(
                child: _QuickAction(
                    icon: Icons.hotel_rounded,
                    label: 'ที่พัก',
                    onTap: () => onQuickAction('ที่พัก'))),
            Expanded(
                child: _QuickAction(
                    icon: Icons.restaurant_rounded,
                    label: 'อาหาร',
                    onTap: () => onQuickAction('อาหาร'))),
            Expanded(
                child: _QuickAction(
                    icon: Icons.temple_buddhist_rounded,
                    label: 'สถานที่เที่ยว',
                    onTap: () => onQuickAction('สถานที่เที่ยว')))
          ]),
          const SizedBox(height: 22),
          InkWell(
              onTap: onPlan,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient:
                          const LinearGradient(colors: [Color(0xFF10403D), Color(0xFF1C5C57)])),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFFE3A23C)),
                    const SizedBox(height: 12),
                    const Text('ให้ AI จัดทริปให้คุณ',
                        style: TextStyle(
                            color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 5),
                    const Text(
                        'เลือกจุดหมาย งบประมาณ และสไตล์ แล้วรับแผนเที่ยวพร้อมประมาณการค่าใช้จ่าย',
                        style: TextStyle(color: Colors.white70, height: 1.5)),
                    const SizedBox(height: 15),
                    FilledButton.icon(
                        onPressed: onPlan,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                        label: const Text('เริ่มวางแผน'),
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFE3A23C),
                            foregroundColor: const Color(0xFF3B2A11)))
                  ]))),
          const SizedBox(height: 24),
          _SectionTitle(title: 'จุดหมายยอดนิยม', action: 'ดูทั้งหมด', onTap: onSearch),
          const SizedBox(height: 12),
          SizedBox(
              height: 184,
              child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: destinations.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final Map<String, dynamic> item = destinations[index];
                    final colors = item['colors'] as List<Color>;
                    return InkWell(
                        onTap: () => onDestination(item['name'] as String),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                            width: 155,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: colors)),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Icon(item['icon'] as IconData, color: Colors.white70, size: 34),
                                  const Spacer(),
                                  Text(item['name'] as String,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 3),
                                  Text(item['subtitle'] as String,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white70, fontSize: 10.5))
                                ])));
                  })),
          const SizedBox(height: 20),
          Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                  color: const Color(0xFFF6E4C1), borderRadius: BorderRadius.circular(14)),
              child: const Row(children: [
                Icon(Icons.local_activity_outlined, color: Color(0xFF8A5A17)),
                SizedBox(width: 12),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('ลด 20% ทริปแรกของคุณ',
                      style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF4A2E06))),
                  Text('ใช้โค้ด SABAI20 ก่อนสิ้นเดือนนี้',
                      style: TextStyle(fontSize: 12, color: Color(0xFF7A5219)))
                ]))
              ])),
        ],
      );
}

class _SearchMvpScreen extends StatelessWidget {
  const _SearchMvpScreen(
      {required this.query,
      required this.category,
      required this.categories,
      required this.listings,
      required this.onQuery,
      required this.onCategory,
      required this.onSelect});
  final String query;
  final String category;
  final List<String> categories;
  final List<Map<String, dynamic>> listings;
  final ValueChanged<String> onQuery;
  final ValueChanged<String> onCategory;
  final ValueChanged<Map<String, dynamic>> onSelect;

  @override
  Widget build(BuildContext context) => Column(children: [
        const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Align(
                alignment: Alignment.centerLeft,
                child: Text('ค้นหา', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)))),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextFormField(
                initialValue: query,
                onChanged: onQuery,
                decoration: InputDecoration(
                    hintText: 'ค้นหาที่พัก ร้านอาหาร เที่ยวบิน...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE4E1D8))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE4E1D8))),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12)))),
        const SizedBox(height: 12),
        SizedBox(
            height: 44,
            child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final String value = categories[index];
                  return ChoiceChip(
                      label: Text(value),
                      selected: category == value,
                      onSelected: (_) => onCategory(value),
                      selectedColor: const Color(0xFF10403D),
                      labelStyle: TextStyle(
                          color: category == value ? Colors.white : const Color(0xFF16241F),
                          fontWeight: FontWeight.w600));
                })),
        const SizedBox(height: 8),
        Expanded(
            child: listings.isEmpty
                ? const Center(
                    child: Text('ไม่พบรายการที่ตรงกัน', style: TextStyle(color: Color(0xFF5C6A64))))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    itemCount: listings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final Map<String, dynamic> item = listings[index];
                      return InkWell(
                          onTap: () => onSelect(item),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE4E1D8))),
                              child: Row(children: [
                                Container(
                                    width: 62,
                                    height: 62,
                                    decoration: BoxDecoration(
                                        color: (item['color'] as Color).withOpacity(.13),
                                        borderRadius: BorderRadius.circular(13)),
                                    child: Icon(item['icon'] as IconData,
                                        color: item['color'] as Color, size: 28)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                      Text(item['name'] as String,
                                          style: const TextStyle(fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 4),
                                      Text(item['location'] as String,
                                          style: const TextStyle(
                                              color: Color(0xFF5C6A64), fontSize: 12)),
                                      const SizedBox(height: 7),
                                      Row(children: [
                                        const Icon(Icons.star, size: 14, color: Color(0xFFE3A23C)),
                                        Text(' ${item['rating']} (${item['reviews']})',
                                            style: const TextStyle(fontSize: 11)),
                                        const Spacer(),
                                        Text('฿${(item['price'] as int)}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF10403D)))
                                      ])
                                    ]))
                              ])));
                    })),
      ]);
}

class _PlannerMvpScreen extends StatelessWidget {
  const _PlannerMvpScreen(
      {required this.destination,
      required this.destinations,
      required this.days,
      required this.travelers,
      required this.budget,
      required this.styles,
      required this.styleOptions,
      required this.generating,
      required this.itinerary,
      required this.onDestination,
      required this.onDays,
      required this.onTravelers,
      required this.onBudget,
      required this.onToggleStyle,
      required this.onGenerate,
      required this.onReset,
      required this.onSave,
      required this.isSaved});
  final String destination;
  final List<String> destinations;
  final int days;
  final int travelers;
  final int budget;
  final Set<String> styles;
  final List<String> styleOptions;
  final bool generating;
  final Map<String, dynamic>? itinerary;
  final ValueChanged<String> onDestination;
  final ValueChanged<int> onDays;
  final ValueChanged<int> onTravelers;
  final ValueChanged<int> onBudget;
  final ValueChanged<String> onToggleStyle;
  final VoidCallback onGenerate;
  final VoidCallback onReset;
  final VoidCallback onSave;
  final bool isSaved;

  @override
  Widget build(BuildContext context) {
    if (generating) {
      return const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: Color(0xFF10403D)),
        SizedBox(height: 16),
        Text('กำลังจัดทริปให้คุณ...')
      ]));
    }
    if (itinerary != null) {
      return _ItineraryResult(
          destination: destination,
          days: days,
          travelers: travelers,
          itinerary: itinerary!,
          onReset: onReset,
          onSave: onSave,
          isSaved: isSaved);
    }
    return ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 30), children: [
      const Row(children: [
        Icon(Icons.auto_awesome, color: Color(0xFFE3A23C)),
        SizedBox(width: 8),
        Text('ผู้ช่วยวางแผนทริป',
            style: TextStyle(color: Color(0xFF10403D), fontWeight: FontWeight.w700))
      ]),
      const SizedBox(height: 7),
      const Text('ให้ AI จัดทริปในฝันของคุณ',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 5),
      const Text('กำหนดความต้องการ แล้วรับแผนเที่ยวพร้อมงบประมาณ',
          style: TextStyle(color: Color(0xFF5C6A64), fontSize: 12.5)),
      const SizedBox(height: 24),
      const Text('อยากไปที่ไหน?', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      Wrap(
          spacing: 8,
          runSpacing: 8,
          children: destinations
              .map((item) => _SelectChip(
                  label: item, selected: destination == item, onTap: () => onDestination(item)))
              .toList()),
      const SizedBox(height: 22),
      _StepperRow(label: 'กี่วัน?', value: days, min: 1, max: 14, onChanged: onDays),
      const SizedBox(height: 20),
      _StepperRow(
          label: 'จำนวนผู้เดินทาง', value: travelers, min: 1, max: 10, onChanged: onTravelers),
      const SizedBox(height: 22),
      Row(children: [
        const Expanded(
            child: Text('งบประมาณโดยประมาณ', style: TextStyle(fontWeight: FontWeight.w700))),
        Text('฿${budget}',
            style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF10403D)))
      ]),
      Slider(
          value: budget.toDouble(),
          min: 3000,
          max: 50000,
          divisions: 94,
          onChanged: (value) => onBudget((value / 500).round() * 500),
          activeColor: const Color(0xFF10403D)),
      const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('฿3,000', style: TextStyle(fontSize: 11, color: Color(0xFF5C6A64))),
        Text('฿50,000', style: TextStyle(fontSize: 11, color: Color(0xFF5C6A64)))
      ]),
      const SizedBox(height: 20),
      const Text('สไตล์การเที่ยว', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      Wrap(
          spacing: 8,
          runSpacing: 8,
          children: styleOptions
              .map((item) => _SelectChip(
                  label: item, selected: styles.contains(item), onTap: () => onToggleStyle(item)))
              .toList()),
      const SizedBox(height: 26),
      FilledButton.icon(
          onPressed: onGenerate,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('ให้ AI จัดแผนให้'),
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10403D),
              padding: const EdgeInsets.symmetric(vertical: 15))),
    ]);
  }
}

class _ItineraryResult extends StatelessWidget {
  const _ItineraryResult(
      {required this.destination,
      required this.days,
      required this.travelers,
      required this.itinerary,
      required this.onReset,
      required this.onSave,
      required this.isSaved});
  final String destination;
  final int days;
  final int travelers;
  final Map<String, dynamic> itinerary;
  final VoidCallback onReset;
  final VoidCallback onSave;
  final bool isSaved;

  @override
  Widget build(BuildContext context) {
    final daysList = itinerary['days'] as List<Map<String, dynamic>>;
    final budgetList = itinerary['budget'] as List<Map<String, dynamic>>;
    final int total = budgetList.fold<int>(0, (sum, item) => sum + (item['value'] as int));
    return Column(children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(20, 15, 20, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.arrow_back, size: 17),
                label: const Text('วางแผนใหม่'),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF10403D))),
            Text('$destination · $days วัน',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            Text('$travelers ผู้เดินทาง · แผนเที่ยวของคุณ',
                style: const TextStyle(color: Color(0xFF5C6A64), fontSize: 12))
          ])),
      Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), children: [
        for (final day in daysList) _ItineraryDay(day: day),
        const SizedBox(height: 8),
        const Text('ประมาณการค่าใช้จ่าย',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        for (final item in budgetList)
          _BudgetLine(label: item['label'] as String, value: item['value'] as int, total: total),
        const Divider(height: 24),
        Row(children: [
          const Expanded(child: Text('รวมทั้งหมด', style: TextStyle(fontWeight: FontWeight.w800))),
          Text('฿$total',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF10403D)))
        ])
      ])),
      SafeArea(
          top: false,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: OutlinedButton.icon(
                  onPressed: isSaved ? null : onSave,
                  icon: Icon(isSaved ? Icons.check_circle_outline : Icons.bookmark_border),
                  label: Text(isSaved ? 'บันทึกแล้ว' : 'บันทึกทริป'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF10403D),
                      padding: const EdgeInsets.symmetric(vertical: 13)))))
    ]);
  }
}

class _TripsMvpScreen extends StatelessWidget {
  const _TripsMvpScreen({
    required this.trips,
    required this.bookings,
    required this.showBookings,
    required this.onPlan,
    required this.onViewChanged,
  });
  final List<Map<String, dynamic>> trips;
  final List<Map<String, dynamic>> bookings;
  final bool showBookings;
  final VoidCallback onPlan;
  final ValueChanged<bool> onViewChanged;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          const Text('ทริปของฉัน', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: false,
                icon: Icon(Icons.map_outlined),
                label: Text('ทริปที่บันทึก'),
              ),
              ButtonSegment<bool>(
                value: true,
                icon: Icon(Icons.receipt_long_outlined),
                label: Text('การจอง'),
              ),
            ],
            selected: {showBookings},
            onSelectionChanged: (selection) => onViewChanged(selection.first),
          ),
          const SizedBox(height: 16),
          if (!showBookings && trips.isEmpty)
            Container(
                padding: const EdgeInsets.symmetric(vertical: 54, horizontal: 24),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE4E1D8))),
                child: Column(children: [
                  const Icon(Icons.luggage_outlined, size: 42, color: Color(0xFF10403D)),
                  const SizedBox(height: 14),
                  const Text('ยังไม่มีทริปที่บันทึกไว้',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text('เริ่มวางแผนทริปแรกของคุณได้เลย',
                      style: TextStyle(color: Color(0xFF5C6A64))),
                  const SizedBox(height: 18),
                  FilledButton(onPressed: onPlan, child: const Text('เริ่มวางแผน'))
                ]))
          else if (!showBookings)
            ...trips.map((trip) {
              final destination = trip['destination'] as String;
              final days = trip['days'] as int;
              final budget = trip['budget'] as int;
              final travelers = trip['travelers'] as int;
              final progress = ((days / 5).clamp(0.25, 1.0)).toDouble();

              return TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.92, end: 1),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => Transform.scale(
                  scale: value,
                  child: child,
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE4E1D8))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const CircleAvatar(
                          radius: 18,
                          backgroundColor: Color(0xFFE4EDEA),
                          child: Icon(Icons.place_outlined, size: 18, color: Color(0xFF10403D))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(destination, style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text('$days วัน • $travelers คน • ฿$budget',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF5C6A64)))
                      ])),
                      const Icon(Icons.chevron_right, color: Color(0xFF5C6A64))
                    ]),
                    const SizedBox(height: 14),
                    Row(children: [
                      const Expanded(
                          child: Text('ความพร้อมแผนทริป',
                              style: TextStyle(fontSize: 11, color: Color(0xFF5C6A64)))),
                      Text('${(progress * 100).round()}%',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF10403D)))
                    ]),
                    const SizedBox(height: 7),
                    ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: const Color(0xFFE4EDEA),
                            color: const Color(0xFF10403D))),
                  ]),
                ),
              );
            }),
          if (showBookings) ...[
            Row(children: [
              const Expanded(
                child: Text('ประวัติการจอง',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              Text('${bookings.length} รายการ',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF5C6A64))),
            ]),
            const SizedBox(height: 8),
            if (bookings.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE4E1D8)),
                ),
                child: const Column(children: [
                  Icon(Icons.receipt_long_outlined, size: 40, color: Color(0xFF10403D)),
                  SizedBox(height: 12),
                  Text('ยังไม่มีรายการจอง', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 5),
                  Text('รายการจองและการชำระเงินจะแสดงที่นี่',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF5C6A64))),
                ]),
              )
            else
              ...bookings.map((booking) {
                final title = booking['title'] as String;
                final destination = booking['destination'] as String;
                final date = booking['date'] as String;
                final amount = booking['amount'] as int;
                final status = booking['status'] as String;
                final icon = booking['icon'] as IconData;
                final color = booking['color'] as Color;

                return TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.96, end: 1),
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOut,
                  builder: (context, value, child) => Transform.scale(
                    scale: value,
                    child: child,
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE4E1D8)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color.withOpacity(.12),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(icon, color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(destination,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF5C6A64))),
                            const SizedBox(height: 4),
                            Text(date,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF5C6A64))),
                            if (booking['payment_method'] is String) ...[
                              const SizedBox(height: 3),
                              Text('ชำระผ่าน ${booking['payment_method']}',
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF75817B))),
                            ],
                            if (booking['booking_id'] is String) ...[
                              const SizedBox(height: 3),
                              Text('อ้างอิง ${booking['booking_id']}',
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF75817B))),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('฿$amount',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, color: Color(0xFF10403D))),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: status == 'จ่ายแล้ว'
                                  ? const Color(0xFFE4F8EE)
                                  : const Color(0xFFF8F0D6),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: status == 'จ่ายแล้ว'
                                    ? const Color(0xFF1D7A4B)
                                    : const Color(0xFF8A5A17),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ]),
                  ),
                );
              }),
          ],
        ],
      );
}

class _ProfileMvpScreen extends StatelessWidget {
  const _ProfileMvpScreen({
    required this.onOpenDemo,
    required this.onOpenHistory,
    required this.displayName,
    required this.email,
    required this.isGuest,
    required this.onLogout,
  });
  final VoidCallback onOpenDemo;
  final VoidCallback onOpenHistory;
  final String displayName;
  final String email;
  final bool isGuest;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
        const Text('โปรไฟล์', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
        const SizedBox(height: 18),
        Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: const Color(0xFF10403D), borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              CircleAvatar(
                  backgroundColor: const Color(0xFFF6E4C1),
                  child: Text(
                    displayName.isNotEmpty ? displayName.characters.first.toUpperCase() : 'S',
                    style: const TextStyle(color: Color(0xFF10403D), fontWeight: FontWeight.w800),
                  )),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    displayName.isNotEmpty
                        ? displayName
                        : isGuest
                            ? 'นักเดินทาง Sabai'
                            : email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    isGuest ? 'สมาชิกผู้เยี่ยมชม' : email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  )
                ]),
              )
            ])),
        const SizedBox(height: 18),
        Row(children: const [
          Expanded(
              child: _ProfileStatCard(
                  title: 'ทริปที่บันทึก', value: '12', subtitle: 'แผนที่พร้อมเดินทาง')),
          SizedBox(width: 10),
          Expanded(
              child: _ProfileStatCard(title: 'คะแนนสะสม', value: '920', subtitle: 'Sabai Points')),
        ]),
        const SizedBox(height: 18),
        Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: const Color(0xFFEEF7F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDDEBE5))),
            child: Row(children: const [
              Icon(Icons.wallet_rounded, color: Color(0xFF10403D)),
              SizedBox(width: 12),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('กระเป๋า Sabai', style: TextStyle(fontWeight: FontWeight.w800)),
                Text('ยอดคงเหลือ ฿2,450', style: TextStyle(fontSize: 12, color: Color(0xFF5C6A64)))
              ])),
              Icon(Icons.chevron_right, color: Color(0xFF5C6A64))
            ])),
        const SizedBox(height: 18),
        _ProfileMenu(
            icon: Icons.bookmark_border,
            title: 'ทริปที่บันทึกไว้',
            subtitle: 'จัดการแผนการเดินทางของคุณ',
            onTap: onOpenHistory),
        _ProfileMenu(
            icon: Icons.confirmation_number_outlined,
            title: 'การจองของฉัน',
            subtitle: 'รายการจองและการชำระเงิน',
            onTap: onOpenHistory),
        _ProfileMenu(
            icon: Icons.settings_outlined,
            title: 'การตั้งค่า',
            subtitle: 'ภาษา สกุลเงิน และการแจ้งเตือน',
            onTap: () {}),
        const SizedBox(height: 10),
        OutlinedButton.icon(
            onPressed: onOpenDemo,
            icon: const Icon(Icons.grid_view_rounded),
            label: const Text('เปิดพอร์ทัลเดโม'),
            style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF10403D),
                padding: const EdgeInsets.symmetric(vertical: 13))),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onLogout,
          icon: Icon(isGuest ? Icons.exit_to_app_rounded : Icons.logout_rounded),
          label: Text(isGuest ? 'ออกจากโหมดผู้เยี่ยมชม' : 'ออกจากระบบ'),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF8B4234)),
        ),
      ]);
}

class _ListingSheet extends StatelessWidget {
  const _ListingSheet({required this.listing, required this.onCompletePayment});
  final Map<String, dynamic> listing;
  final ValueChanged<Map<String, dynamic>> onCompletePayment;

  @override
  Widget build(BuildContext context) {
    final color = listing['color'] as Color;
    final features = <String>[
      'ที่จอดรถ',
      'Wi‑Fi ฟรี',
      'เช็คอิน 14:00',
      'อาหารเช้า',
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                  color: color.withOpacity(.13), borderRadius: BorderRadius.circular(16)),
              child: Icon(listing['icon'] as IconData, size: 56, color: color),
            ),
            const SizedBox(height: 18),
            Text(listing['type'] as String,
                style: const TextStyle(color: Color(0xFF5C6A64), fontSize: 12)),
            const SizedBox(height: 5),
            Text(listing['name'] as String,
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text(listing['location'] as String, style: const TextStyle(color: Color(0xFF5C6A64))),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.star, color: Color(0xFFE3A23C), size: 17),
              Text(' ${listing['rating']} · ${listing['reviews']} รีวิว'),
              const Spacer(),
              Text('เริ่มต้น ฿${listing['price']}',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF10403D))),
            ]),
            const SizedBox(height: 14),
            const Text('สิ่งอำนวยความสะดวก', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: features
                  .map((feature) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                            color: const Color(0xFFE4EDEA),
                            borderRadius: BorderRadius.circular(999)),
                        child: Text(feature,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF10403D))),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('บันทึกตัวเลือกแล้ว')));
                  },
                  icon: const Icon(Icons.bookmark_border),
                  label: const Text('บันทึก'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10403D),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: const Color(0xFFFAFAF8),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      builder: (_) => _CheckoutSheet(
                        listing: listing,
                        onCreateOrder: onCompletePayment,
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10403D),
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('จองเลย'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _CheckoutSheet extends StatefulWidget {
  const _CheckoutSheet({required this.listing, required this.onCreateOrder});
  final Map<String, dynamic> listing;
  final ValueChanged<Map<String, dynamic>> onCreateOrder;

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  int _step = 0;
  int _quantity = 1;
  String _paymentMethod = 'promptpay';
  DateTimeRange? _stayDates;

  static const _paymentMethods = [
    _PaymentMethod(
      id: 'promptpay',
      title: 'พร้อมเพย์ / QR',
      subtitle: 'สแกนจ่ายผ่านแอปธนาคาร',
      icon: Icons.qr_code_2_rounded,
    ),
    _PaymentMethod(
      id: 'card',
      title: 'บัตรเครดิต / เดบิต',
      subtitle: 'Visa, Mastercard และบัตรที่รองรับ',
      icon: Icons.credit_card_rounded,
    ),
    _PaymentMethod(
      id: 'transfer',
      title: 'โอนผ่านธนาคาร',
      subtitle: 'รับรายละเอียดบัญชีหลังยืนยันรายการ',
      icon: Icons.account_balance_rounded,
    ),
  ];

  bool get _isStay => widget.listing['type'] == 'ที่พัก';
  int get _nights => _stayDates == null ? 1 : _stayDates!.duration.inDays;
  int get _unitPrice => widget.listing['price'] as int;
  int get _total => _unitPrice * (_isStay ? _nights : _quantity);
  String get _formattedDates {
    if (_stayDates == null) return 'เลือกวันเดินทาง';
    final start = _stayDates!.start;
    final end = _stayDates!.end;
    if (!_isStay) return '${start.day}/${start.month}/${start.year}';
    return '${start.day}/${start.month}/${start.year} - ${end.day}/${end.month}/${end.year}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _selectDates() async {
    final today = DateTime.now();
    if (!_isStay) {
      final picked = await showDatePicker(
        context: context,
        firstDate: DateTime(today.year, today.month, today.day),
        lastDate: DateTime(today.year + 2),
        initialDate: _stayDates?.start,
        helpText: 'เลือกวันที่ใช้บริการ',
      );
      if (picked != null) {
        setState(() => _stayDates = DateTimeRange(start: picked, end: picked));
      }
      return;
    }
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 2),
      initialDateRange: _stayDates,
      helpText: 'เลือกวันเช็กอินและเช็กเอาต์',
      saveText: 'ยืนยันวันเดินทาง',
    );
    if (picked != null) setState(() => _stayDates = picked);
  }

  String? _validateRequired(String? value) =>
      value == null || value.trim().isEmpty ? 'กรุณากรอกข้อมูลนี้' : null;

  void _continue() {
    if (_step == 0) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
      if (_stayDates == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(_isStay ? 'กรุณาเลือกวันเช็กอินและเช็กเอาต์' : 'กรุณาเลือกวันที่ใช้บริการ'),
          ),
        );
        return;
      }
      setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      setState(() => _step = 2);
      return;
    }

    final listing = widget.listing;
    final booking = <String, dynamic>{
      'title': listing['name'] as String,
      'destination': listing['location'] as String,
      'date': _formattedDates,
      'amount': _total,
      'status': 'รอชำระเงิน',
      'booking_id': 'SB${DateTime.now().microsecondsSinceEpoch}',
      'payment_method': _paymentMethods.firstWhere((item) => item.id == _paymentMethod).title,
      'customer_name': _nameController.text.trim(),
      'customer_email': _emailController.text.trim(),
      'customer_phone': _phoneController.text.trim(),
      'quantity': _isStay ? _nights : _quantity,
      'icon': listing['icon'] as IconData,
      'color': listing['color'] as Color,
    };
    Navigator.pop(context);
    widget.onCreateOrder(booking);
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, 18, 22, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .88),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                  child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                          color: const Color(0xFFCBD5D1),
                          borderRadius: BorderRadius.circular(999)))),
              const SizedBox(height: 16),
              Row(children: [
                const Expanded(
                    child: Text('จองและชำระเงิน',
                        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800))),
                Text('ขั้นตอน ${_step + 1}/3',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64716C))),
              ]),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                    value: (_step + 1) / 3,
                    minHeight: 5,
                    backgroundColor: const Color(0xFFE7ECE8),
                    color: const Color(0xFF10403D)),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _step == 0
                        ? _buildDetailsStep(listing)
                        : _step == 1
                            ? _buildPaymentStep()
                            : _buildReviewStep(listing),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(children: [
                if (_step > 0) ...[
                  Expanded(
                      child: OutlinedButton(
                          onPressed: () => setState(() => _step--), child: const Text('ย้อนกลับ'))),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: _step == 0 ? 1 : 2,
                  child: FilledButton.icon(
                    onPressed: _continue,
                    icon: Icon(
                        _step == 2 ? Icons.receipt_long_outlined : Icons.arrow_forward_rounded,
                        size: 18),
                    label: Text(_step == 2 ? 'สร้างรายการจอง' : 'ดำเนินการต่อ'),
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF10403D),
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsStep(Map<String, dynamic> listing) => Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _checkoutProduct(listing),
          const SizedBox(height: 16),
          const Text('ข้อมูลผู้จอง', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _checkoutField(
              controller: _nameController,
              label: 'ชื่อ-นามสกุล',
              icon: Icons.person_outline,
              validator: _validateRequired),
          const SizedBox(height: 10),
          _checkoutField(
              controller: _emailController,
              label: 'อีเมลสำหรับรับการยืนยัน',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                final email = value?.trim() ?? '';
                return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
                    ? null
                    : 'กรุณากรอกอีเมลให้ถูกต้อง';
              }),
          const SizedBox(height: 10),
          _checkoutField(
              controller: _phoneController,
              label: 'เบอร์โทรศัพท์',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (value) {
                final phone = value?.replaceAll(RegExp(r'\D'), '') ?? '';
                return phone.length >= 9 ? null : 'กรุณากรอกเบอร์โทรศัพท์ให้ถูกต้อง';
              }),
          const SizedBox(height: 16),
          Text(_isStay ? 'วันเช็กอิน - เช็กเอาต์' : 'วันที่ใช้บริการ',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _selectDates,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(_stayDates == null ? 'เลือกวันที่' : _formattedDates),
            style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13)),
          ),
          const SizedBox(height: 14),
          if (_isStay)
            _summaryLine('จำนวนคืน', '$_nights คืน')
          else
            Row(children: [
              const Expanded(child: Text('จำนวน', style: TextStyle(fontWeight: FontWeight.w700))),
              IconButton(
                  onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                  icon: const Icon(Icons.remove_circle_outline)),
              Text('$_quantity', style: const TextStyle(fontWeight: FontWeight.w800)),
              IconButton(
                  onPressed: () => setState(() => _quantity++),
                  icon: const Icon(Icons.add_circle_outline)),
            ]),
          const SizedBox(height: 6),
          _priceSummary(),
        ]),
      );

  Widget _buildPaymentStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('เลือกรูปแบบการชำระ', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('เลือกช่องทางที่สะดวก ระบบจะแสดงยอดและข้อมูลคำสั่งจองก่อนยืนยัน',
            style: TextStyle(fontSize: 12, color: Color(0xFF64716C))),
        const SizedBox(height: 12),
        for (final method in _paymentMethods)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: InkWell(
              onTap: () => setState(() => _paymentMethod = method.id),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: _paymentMethod == method.id ? const Color(0xFFEDF5F0) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: _paymentMethod == method.id
                          ? const Color(0xFF10403D)
                          : const Color(0xFFE1E6E2)),
                ),
                child: Row(children: [
                  Icon(method.icon, color: const Color(0xFF10403D)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(method.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(method.subtitle,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64716C))),
                  ])),
                  Radio<String>(
                      value: method.id,
                      groupValue: _paymentMethod,
                      onChanged: (value) => setState(() => _paymentMethod = value!)),
                ]),
              ),
            ),
          ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
              color: const Color(0xFFFFF5E4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEBD8B2))),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, size: 18, color: Color(0xFF8A5A17)),
            SizedBox(width: 8),
            Expanded(
                child: Text(
                    'ช่องทางชำระเงินจริงยังรอเชื่อมต่อผู้ให้บริการ ขั้นนี้จะบันทึกคำสั่งจองเป็น “รอชำระเงิน” และยังไม่มีการตัดเงิน',
                    style: TextStyle(fontSize: 11.5, height: 1.45, color: Color(0xFF694A1B)))),
          ]),
        ),
        const SizedBox(height: 14),
        _priceSummary(),
      ]);

  Widget _buildReviewStep(Map<String, dynamic> listing) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('ตรวจสอบคำสั่งจอง', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _checkoutProduct(listing),
        const SizedBox(height: 12),
        _summaryLine('ผู้จอง', _nameController.text.trim()),
        _summaryLine('อีเมล', _emailController.text.trim()),
        _summaryLine('โทรศัพท์', _phoneController.text.trim()),
        _summaryLine('วันเดินทาง', _formattedDates),
        _summaryLine(_isStay ? 'จำนวนคืน' : 'จำนวน', _isStay ? '$_nights คืน' : '$_quantity'),
        _summaryLine('วิธีชำระที่เลือก',
            _paymentMethods.firstWhere((method) => method.id == _paymentMethod).title),
        const Divider(height: 24),
        _priceSummary(),
        const SizedBox(height: 12),
        const Text('ยืนยันแล้วรายการจะอยู่ในประวัติการจอง โดยยังไม่ถือว่าชำระเงินสำเร็จ',
            style: TextStyle(fontSize: 11, color: Color(0xFF64716C))),
      ]);

  Widget _checkoutProduct(Map<String, dynamic> listing) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE4E1D8))),
        child: Row(children: [
          Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: (listing['color'] as Color).withOpacity(.12),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(listing['icon'] as IconData, color: listing['color'] as Color)),
          const SizedBox(width: 11),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(listing['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(listing['location'] as String,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64716C))),
          ])),
          Text('฿$_unitPrice${_isStay ? '/คืน' : '/รายการ'}',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF10403D))),
        ]),
      );

  Widget _priceSummary() => Column(children: [
        _summaryLine('ราคา ${_isStay ? '$_nights คืน' : '$_quantity รายการ'}',
            '฿${_unitPrice * (_isStay ? _nights : _quantity)}'),
        _summaryLine('ค่าบริการ', '฿0'),
        const Divider(height: 18),
        _summaryLine('ยอดรวม', '฿$_total', emphasized: true),
      ]);

  Widget _summaryLine(String label, String value, {bool emphasized = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: emphasized ? 14 : 12,
                      fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
                      color: const Color(0xFF5C6A64)))),
          Text(value,
              style: TextStyle(
                  fontSize: emphasized ? 18 : 12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF10403D))),
        ]),
      );

  Widget _checkoutField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
  }) =>
      TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 19),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE1E6E2))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE1E6E2))),
        ),
      );
}

class _PaymentMethod {
  const _PaymentMethod(
      {required this.id, required this.title, required this.subtitle, required this.icon});

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
}

class _BookingDateChip extends StatelessWidget {
  const _BookingDateChip({required this.label, this.selected = false});
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF10403D) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE4E1D8)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : const Color(0xFF16241F),
        ),
      ));
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))
          ])));
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      child: Column(children: [
        Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: const Color(0xFFE4EDEA), borderRadius: BorderRadius.circular(15)),
            child: Icon(icon, color: const Color(0xFF10403D))),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center)
      ]));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.action, required this.onTap});
  final String title;
  final String action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
        TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF10403D)),
            child: Text(action, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)))
      ]);
}

class _SelectChip extends StatelessWidget {
  const _SelectChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFF10403D),
      labelStyle: TextStyle(
          color: selected ? Colors.white : const Color(0xFF16241F), fontWeight: FontWeight.w600));
}

class _StepperRow extends StatelessWidget {
  const _StepperRow(
      {required this.label,
      required this.value,
      required this.min,
      required this.max,
      required this.onChanged});
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
        IconButton(
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline)),
        SizedBox(
            width: 28,
            child: Text('$value',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
        IconButton(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline))
      ]);
}

class _ItineraryDay extends StatelessWidget {
  const _ItineraryDay({required this.day});
  final Map<String, dynamic> day;
  @override
  Widget build(BuildContext context) {
    final items = day['items'] as List<Map<String, String>>;
    return Padding(
        padding: const EdgeInsets.only(bottom: 19),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(day['title'] as String,
              style: const TextStyle(color: Color(0xFF10403D), fontWeight: FontWeight.w800)),
          const SizedBox(height: 11),
          for (final item in items)
            Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(
                      padding: EdgeInsets.only(top: 4, right: 11),
                      child: Icon(Icons.circle, size: 8, color: Color(0xFFE3A23C))),
                  SizedBox(
                      width: 42,
                      child: Text(item['time']!,
                          style: const TextStyle(
                              color: Color(0xFF5C6A64),
                              fontWeight: FontWeight.w700,
                              fontSize: 12))),
                  Expanded(
                      child: Text(item['text']!, style: const TextStyle(fontSize: 13, height: 1.4)))
                ]))
        ]));
  }
}

class _BudgetLine extends StatelessWidget {
  const _BudgetLine({required this.label, required this.value, required this.total});
  final String label;
  final int value;
  final int total;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: Column(
          children: [
            Row(children: [
              Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
              Text('฿$value', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 5),
            LinearProgressIndicator(
              value: total == 0 ? 0 : value / total,
              minHeight: 5,
              borderRadius: BorderRadius.circular(5),
              backgroundColor: const Color(0xFFE4EDEA),
              color: const Color(0xFFE3A23C),
            ),
          ],
        ),
      );
}

class _ProfileStatCard extends StatelessWidget {
  const _ProfileStatCard({required this.title, required this.value, required this.subtitle});
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4E1D8))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF5C6A64))),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF10403D))),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF5C6A64))),
        ]),
      );
}

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: const Color(0xFFE4EDEA), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: const Color(0xFF10403D))),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF5C6A64))),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF5C6A64)));
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
            children: const [
              _HomeHeader(),
              SizedBox(height: 8),
              _SearchBox(),
              _FilterChips(),
              _SectionHeader(title: 'Trending Destinations', actionText: 'See all →'),
              _TrendingDestinations(),
              _SectionHeader(title: 'Your Upcoming Trips', actionText: 'Manage →'),
              _TripCard(
                emoji: '🏯',
                title: 'Kyoto Explorer',
                subtitle: 'May 12 – May 20, 2025 · 8 days',
                progress: 0.65,
                status: '65% planned · 3 activities left',
                gradient: LinearGradient(colors: [Color(0xFF0F4C6D), Color(0xFF0A2840)]),
              ),
              _TripCard(
                emoji: '🌴',
                title: 'Bali Escape',
                subtitle: 'Jul 3 – Jul 10, 2025 · 7 days',
                progress: 0.20,
                status: '20% planned · Just started',
                gradient: LinearGradient(colors: [Color(0xFF1A3A20), Color(0xFF0D2D15)]),
              ),
              SizedBox(height: 12),
              _AdBanner(
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
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: _ScreenHeader(title: 'Explore', subtitle: 'Attractions · Hotels · Restaurants'),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _CategoryGrid(),
        ),
        SizedBox(height: 20),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _SectionHeader(title: 'Top Attractions', actionText: 'Map view'),
        ),
        SizedBox(height: 12),
        Padding(
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
        SizedBox(height: 12),
        Padding(
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
        SizedBox(height: 20),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _MapPlaceholder(),
        ),
        SizedBox(height: 20),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _SectionHeader(title: 'Recommended Hotels', actionText: 'See all'),
        ),
        SizedBox(height: 12),
        Padding(
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
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: _ScreenHeader(title: 'Trip Timeline', subtitle: 'Kyoto Explorer · May 2025'),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _CalendarBlock(),
        ),
        SizedBox(height: 20),
        Padding(
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
        SizedBox(height: 16),
        Padding(
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
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: _ScreenHeader(
              title: 'Travel Assistant', subtitle: 'Everything you need, offline-ready'),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _WeatherStrip(),
        ),
        SizedBox(height: 16),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _CurrencyCard(),
        ),
        SizedBox(height: 16),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _AssistGrid(),
        ),
        SizedBox(height: 12),
        Padding(
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
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
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
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
      child: const Row(
        children: [
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
  const _SectionHeader({required this.title, required this.actionText});
  final String title;
  final String actionText;

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

        final List<Destination> cards = snapshot.data ?? [];

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
              final Destination card = cards[index];
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
  const _DestCardData(
      {required this.emoji,
      required this.label,
      required this.title,
      required this.meta,
      required this.gradient});
  final String emoji;
  final String label;
  final String title;
  final String meta;
  final Gradient gradient;
}

class _TripCard extends StatelessWidget {
  const _TripCard(
      {required this.emoji,
      required this.title,
      required this.subtitle,
      required this.progress,
      required this.status,
      required this.gradient});
  final String emoji;
  final String title;
  final String subtitle;
  final double progress;
  final String status;
  final Gradient gradient;

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
  const _AdBanner(
      {required this.label,
      required this.title,
      required this.subtitle,
      required this.buttonText,
      required this.gradient});
  final String label;
  final String title;
  final String subtitle;
  final String buttonText;
  final Gradient gradient;

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
  const _ScreenHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

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
              const Expanded(
                  child: _RouteField(label: 'FROM', code: 'BKK', city: 'Bangkok, Thailand')),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(color: Color(0xFF00C9A7), shape: BoxShape.circle),
                child: const Icon(Icons.swap_vert, color: Color(0xFF0A1628), size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(child: _RouteField(label: 'TO', code: 'NRT', city: 'Tokyo, Japan')),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
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
  const _RouteField({required this.label, required this.code, required this.city});
  final String label;
  final String code;
  final String city;

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
  const _DateField({required this.label, required this.value});
  final String label;
  final String value;

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
  const _FlightTimeBlock({required this.time, required this.airport});
  final String time;
  final String airport;

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
      const _CategoryData(
          emoji: '🌿',
          title: 'Nature',
          subtitle: '142 places',
          colors: [Color(0xFF1A3A2A), Color(0xFF0F6E56)]),
      const _CategoryData(
          emoji: '🏛️',
          title: 'History',
          subtitle: '89 places',
          colors: [Color(0xFF2A1A0A), Color(0xFF854F0B)]),
      const _CategoryData(
          emoji: '☕',
          title: 'Lifestyle',
          subtitle: '211 places',
          colors: [Color(0xFF1A1A3A), Color(0xFF534AB7)]),
      const _CategoryData(
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
        final _CategoryData item = items[index];
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
  const _CategoryData(
      {required this.emoji, required this.title, required this.subtitle, required this.colors});
  final String emoji;
  final String title;
  final String subtitle;
  final List<Color> colors;
}

class _AttractionCard extends StatelessWidget {
  const _AttractionCard(
      {required this.emoji,
      required this.name,
      required this.location,
      required this.rating,
      required this.reviews,
      required this.tag});
  final String emoji;
  final String name;
  final String location;
  final String rating;
  final String reviews;
  final String tag;

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
        const Positioned(
          bottom: 12,
          left: 16,
          right: 16,
          child: Row(children: [
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
  const _HotelCard(
      {required this.emoji,
      required this.name,
      required this.stars,
      required this.reviews,
      required this.price});
  final String emoji;
  final String name;
  final String stars;
  final String reviews;
  final String price;

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
          decoration: const BoxDecoration(
              color: Color(0xFF1E2E47),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
            final bool isEmpty = day.isEmpty;
            final bool isSelected = day == '12' || day == '20';
            final isToday = day == '23';
            final bool isRange = ['13', '14', '15', '16', '17', '18', '19'].contains(day);
            final bool hasEvent = ['13', '14', '15', '16', '17', '18', '19'].contains(day);
            Color? bg;
            var textColor = const Color(0xFFB0C4DE);
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
      const Row(children: [
        _LegendDot(color: Color(0xFFFF6B6B), label: 'Flight'),
        SizedBox(width: 16),
        _LegendDot(color: Color(0xFFFFB347), label: 'Hotel check-in'),
        SizedBox(width: 16),
        _LegendDot(color: Color(0xFF00C9A7), label: 'Activity'),
      ]),
    ]);
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

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
  const _TimelineItem({required this.day, required this.date, required this.events});
  final String day;
  final String date;
  final List<_TimelineEvent> events;

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
  const _TimelineEvent(
      {required this.time, required this.color, required this.title, required this.subtitle});
  final String time;
  final Color color;
  final String title;
  final String subtitle;
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
        const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Kyoto, Japan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text('Partly cloudy · Humidity 68%',
                style: TextStyle(fontSize: 12, color: Color(0xFF8BA0BC))),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
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
      const _CurrencyData(flag: '🇯🇵', name: 'Japanese Yen', code: 'JPY', rate: '4.24 ¥'),
      const _CurrencyData(flag: '🇺🇸', name: 'US Dollar', code: 'USD', rate: r'0.028 $'),
      const _CurrencyData(flag: '🇪🇺', name: 'Euro', code: 'EUR', rate: '0.026 €'),
      const _CurrencyData(flag: '🇸🇬', name: 'Singapore Dollar', code: 'SGD', rate: r'0.038 S$'),
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
  const _CurrencyData(
      {required this.flag, required this.name, required this.code, required this.rate});
  final String flag;
  final String name;
  final String code;
  final String rate;
}

class _AssistGrid extends StatelessWidget {
  const _AssistGrid();

  @override
  Widget build(BuildContext context) {
    final items = [
      const _AssistData(
          icon: '🗺️',
          title: 'Offline Maps',
          subtitle: 'Downloaded for Kyoto region',
          badge: '532 MB saved'),
      const _AssistData(
          icon: '🛂', title: 'Documents', subtitle: 'Passport, Visa, Insurance', badge: '3 stored'),
      const _AssistData(
          icon: '📡', title: 'Travel SIM', subtitle: 'eSIM for Japan · 10GB', badge: 'Active'),
      const _AssistData(
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
        final _AssistData item = items[index];
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
  const _AssistData(
      {required this.icon, required this.title, required this.subtitle, required this.badge});
  final String icon;
  final String title;
  final String subtitle;
  final String badge;
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
          child: const Row(children: [
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
  const _ProfileStat({required this.value, required this.label});
  final String value;
  final String label;

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
  const _MenuItem(
      {required this.emoji,
      required this.title,
      required this.subtitle,
      required this.backgroundColor});
  final String emoji;
  final String title;
  final String subtitle;
  final Color backgroundColor;

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
