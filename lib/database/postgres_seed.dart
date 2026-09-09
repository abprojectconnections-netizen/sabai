import 'postgres_service.dart';

/// Seed the `apptravel` PostgreSQL database with demo data.
///
/// The function connects using the provided credentials, creates tables if
/// they do not exist, and inserts sample rows similar to the local SQLite
/// seed used in the UI.
Future<void> seedPostgres({
  required String host,
  required int port,
  required String database,
  required String username,
  required String password,
  bool useSSL = false,
}) async {
  final service = PostgresService(
    host: host,
    port: port,
    database: database,
    username: username,
    password: password,
    useSSL: useSSL,
  );

  await service.open();
  try {
    // Create schema (if not exists)
    await service.query('''
      CREATE TABLE IF NOT EXISTS destinations (
        id TEXT PRIMARY KEY,
        emoji TEXT,
        label TEXT,
        title TEXT,
        meta TEXT,
        gradient_start INTEGER,
        gradient_end INTEGER
      );
    ''');

    await service.query('''
      CREATE TABLE IF NOT EXISTS trips (
        id TEXT PRIMARY KEY,
        emoji TEXT,
        title TEXT,
        subtitle TEXT,
        progress REAL,
        status TEXT,
        gradient_start INTEGER,
        gradient_end INTEGER
      );
    ''');

    await service.query('''
      CREATE TABLE IF NOT EXISTS flights (
        id TEXT PRIMARY KEY,
        icon TEXT,
        airline TEXT,
        details TEXT,
        price TEXT,
        depart TEXT,
        depart_airport TEXT,
        arrive TEXT,
        arrive_airport TEXT,
        duration TEXT,
        stop_info TEXT,
        badge TEXT
      );
    ''');

    await service.query('''
      CREATE TABLE IF NOT EXISTS categories (
        id TEXT PRIMARY KEY,
        emoji TEXT,
        title TEXT,
        subtitle TEXT,
        color_start INTEGER,
        color_end INTEGER
      );
    ''');

    await service.query('''
      CREATE TABLE IF NOT EXISTS attractions (
        id TEXT PRIMARY KEY,
        emoji TEXT,
        name TEXT,
        location TEXT,
        rating TEXT,
        reviews TEXT,
        tag TEXT
      );
    ''');

    await service.query('''
      CREATE TABLE IF NOT EXISTS hotels (
        id TEXT PRIMARY KEY,
        emoji TEXT,
        name TEXT,
        stars TEXT,
        reviews TEXT,
        price TEXT
      );
    ''');

    await service.query('''
      CREATE TABLE IF NOT EXISTS timeline_events (
        id TEXT PRIMARY KEY,
        day TEXT,
        date TEXT,
        time TEXT,
        color INTEGER,
        title TEXT,
        subtitle TEXT,
        order_index INTEGER
      );
    ''');

    await service.query('''
      CREATE TABLE IF NOT EXISTS assist_items (
        id TEXT PRIMARY KEY,
        icon TEXT,
        title TEXT,
        subtitle TEXT,
        badge TEXT
      );
    ''');

    // Upsert sample data (use ON CONFLICT DO NOTHING to avoid duplicates)
    await service.query('''
      INSERT INTO destinations(id, emoji, label, title, meta, gradient_start, gradient_end) VALUES
      ('dest_kyoto','🏯','Hot','Kyoto, Japan','4.9 · 2,341 reviews', 0xFF0F4C6D, 0xFF0A2840)
      ON CONFLICT (id) DO NOTHING;
    ''');

    await service.query('''
      INSERT INTO destinations(id, emoji, label, title, meta, gradient_start, gradient_end) VALUES
      ('dest_bali','🌴','New','Bali, Indonesia','4.8 · 1,876 reviews', 0xFF1A3A20, 0xFF0D2D15)
      ON CONFLICT (id) DO NOTHING;
    ''');

    await service.query('''
      INSERT INTO destinations(id, emoji, label, title, meta, gradient_start, gradient_end) VALUES
      ('dest_dubai','🏜️','', 'Dubai, UAE','4.7 · 3,102 reviews', 0xFF2A1A0D, 0xFF1A0D06)
      ON CONFLICT (id) DO NOTHING;
    ''');

    await service.query('''
      INSERT INTO destinations(id, emoji, label, title, meta, gradient_start, gradient_end) VALUES
      ('dest_paris','🗼','', 'Paris, France','4.8 · 4,521 reviews', 0xFF1A1530, 0xFF0E0D25)
      ON CONFLICT (id) DO NOTHING;
    ''');

    await service.query('''
      INSERT INTO trips(id, emoji, title, subtitle, progress, status, gradient_start, gradient_end) VALUES
      ('trip_kyoto','🏯','Kyoto Explorer','May 12 – May 20, 2025 · 8 days', 0.65, '65% planned · 3 activities left', 0xFF0F4C6D, 0xFF0A2840)
      ON CONFLICT (id) DO NOTHING;
    ''');

    await service.query('''
      INSERT INTO trips(id, emoji, title, subtitle, progress, status, gradient_start, gradient_end) VALUES
      ('trip_bali','🌴','Bali Escape','Jul 3 – Jul 10, 2025 · 7 days', 0.20, '20% planned · Just started', 0xFF1A3A20, 0xFF0D2D15)
      ON CONFLICT (id) DO NOTHING;
    ''');

    await service.query('''
      INSERT INTO flights(id, icon, airline, details, price, depart, depart_airport, arrive, arrive_airport, duration, stop_info, badge) VALUES
      ('flight_thai','✈️','Thai Airways','Economy · Direct','฿8,420','07:30','BKK','14:00','NRT','5h 30m','Non-stop','Best Value')
      ON CONFLICT (id) DO NOTHING;
    ''');

    await service.query('''
      INSERT INTO flights(id, icon, airline, details, price, depart, depart_airport, arrive, arrive_airport, duration, stop_info, badge) VALUES
      ('flight_jal','🇯🇵','Japan Airlines','Economy · 1 Stop','฿7,190','09:15','BKK','19:00','NRT','8h 45m','1 stop · KUL','')
      ON CONFLICT (id) DO NOTHING;
    ''');

    await service.query('''
      INSERT INTO flights(id, icon, airline, details, price, depart, depart_airport, arrive, arrive_airport, duration, stop_info, badge) VALUES
      ('flight_airasia','🌏','AirAsia X','Economy · Direct','฿5,880','22:45','BKK','06:35','NRT','5h 50m','Non-stop','')
      ON CONFLICT (id) DO NOTHING;
    ''');

    await service.query('''
      INSERT INTO categories(id, emoji, title, subtitle, color_start, color_end) VALUES
      ('cat_nature','🌿','Nature','142 places', 0xFF1A3A2A, 0xFF0F6E56)
      ON CONFLICT (id) DO NOTHING;
    ''');

    await service.query('''
      INSERT INTO categories(id, emoji, title, subtitle, color_start, color_end) VALUES
      ('cat_history','🏛️','History','89 places', 0xFF2A1A0A, 0xFF854F0B)
      ON CONFLICT (id) DO NOTHING;
    ''');

    await service.query('''
      INSERT INTO categories(id, emoji, title, subtitle, color_start, color_end) VALUES
      ('cat_lifestyle','☕','Lifestyle','211 places', 0xFF1A1A3A, 0xFF534AB7)
      ON CONFLICT (id) DO NOTHING;
    ''');

    await service.query('''
      INSERT INTO categories(id, emoji, title, subtitle, color_start, color_end) VALUES
      ('cat_adventure','🧗','Adventure','63 places', 0xFF3A1A1A, 0xFF993C1D)
      ON CONFLICT (id) DO NOTHING;
    ''');

    await service.query('''
      INSERT INTO attractions(id, emoji, name, location, rating, reviews, tag) VALUES
      ('attr_fushimi','⛩️','Fushimi Inari Shrine','Kyoto, Japan','★★★★★','4.9 (2,341)','History · Free entry')
      ON CONFLICT (id) DO NOTHING;
    ''');

    await service.query('''
      INSERT INTO attractions(id, emoji, name, location, rating, reviews, tag) VALUES
      ('attr_fuji','🏔️','Mount Fuji Day Trip','Yamanashi, Japan','★★★★★','4.8 (1,092)','Adventure · From ฿1,200')
      ON CONFLICT (id) DO NOTHING;
    ''');

    await service.query('''
      INSERT INTO hotels(id, emoji, name, stars, reviews, price) VALUES
      ('hotel_ritz','🏨','The Ritz-Carlton Kyoto','★★★★★','4.9 · 856 reviews','฿12,400')
      ON CONFLICT (id) DO NOTHING;
    ''');

    await service.query('''
      INSERT INTO timeline_events(id, day, date, time, color, title, subtitle, order_index) VALUES
      ('event_flight','Day 1','Monday, May 12, 2025','07:30', 0xFFFF6B6B, 'Flight TG622 · BKK → NRT', 'Thai Airways · Economy · Gate B12', 1)
      ON CONFLICT (id) DO NOTHING;
    ''');

    await service.query('''
      INSERT INTO timeline_events(id, day, date, time, color, title, subtitle, order_index) VALUES
      ('event_transfer','Day 1','Monday, May 12, 2025','14:00', 0xFFFFB347, 'Arrive NRT · Transfer to Kyoto', 'Shinkansen · ~2h 30m · ¥13,870', 2)
      ON CONFLICT (id) DO NOTHING;
    ''');

    await service.query('''
      INSERT INTO timeline_events(id, day, date, time, color, title, subtitle, order_index) VALUES
      ('event_checkin','Day 1','Monday, May 12, 2025','18:00', 0xFF00C9A7, 'Hotel Check-in · Ritz-Carlton Kyoto', 'Confirmation #RC-28741 · Room 812', 3)
      ON CONFLICT (id) DO NOTHING;
    ''');

    await service.query('''
      INSERT INTO timeline_events(id, day, date, time, color, title, subtitle, order_index) VALUES
      ('event_shrine','Day 2','Tuesday, May 13, 2025','08:00', 0xFF00C9A7, 'Fushimi Inari Morning Visit', 'Free entry · Bring camera · 3h estimated', 4)
      ON CONFLICT (id) DO NOTHING;
    ''');

    await service.query('''
      INSERT INTO timeline_events(id, day, date, time, color, title, subtitle, order_index) VALUES
      ('event_lunch','Day 2','Tuesday, May 13, 2025','13:00', 0xFF4ECDC4, 'Lunch · Nishiki Market', 'Local street food · Budget ฿400', 5)
      ON CONFLICT (id) DO NOTHING;
    ''');

    await service.query('''
      INSERT INTO assist_items(id, icon, title, subtitle, badge) VALUES
      ('assist_maps','🗺️','Offline Maps','Downloaded for Kyoto region','532 MB saved')
      ON CONFLICT (id) DO NOTHING;
    ''');

    await service.query('''
      INSERT INTO assist_items(id, icon, title, subtitle, badge) VALUES
      ('assist_docs','🛂','Documents','Passport, Visa, Insurance','3 stored')
      ON CONFLICT (id) DO NOTHING;
    ''');

    await service.query('''
      INSERT INTO assist_items(id, icon, title, subtitle, badge) VALUES
      ('assist_sim','📡','Travel SIM','eSIM for Japan · 10GB','Active')
      ON CONFLICT (id) DO NOTHING;
    ''');

    await service.query('''
      INSERT INTO assist_items(id, icon, title, subtitle, badge) VALUES
      ('assist_help','🆘','Emergency','Local contacts & hotlines','Offline ready')
      ON CONFLICT (id) DO NOTHING;
    ''');

    print('Seed complete.');
  } finally {
    await service.close();
  }
}
