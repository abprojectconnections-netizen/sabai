import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._(this.db);

  final Database db;

  static LocalDatabase? _instance;

  static Future<void> initialize() async {
    if (_instance != null) {
      return;
    }

    final String databasePath = await _databasePath();
    final Database db = await openDatabase(
      databasePath,
      version: 1,
      onCreate: _createSchema,
    );

    _instance = LocalDatabase._(db);
    await _instance!._seedData();
  }

  static Future<LocalDatabase> get instance async {
    if (_instance == null) {
      await initialize();
    }
    return _instance!;
  }

  static Future<String> _databasePath() async {
    final Directory documentsDirectory = await getApplicationDocumentsDirectory();
    return p.join(documentsDirectory.path, 'apptravel.db');
  }

  static FutureOr<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE destinations(
        id TEXT PRIMARY KEY,
        emoji TEXT,
        label TEXT,
        title TEXT,
        meta TEXT,
        gradient_start INTEGER,
        gradient_end INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE trips(
        id TEXT PRIMARY KEY,
        emoji TEXT,
        title TEXT,
        subtitle TEXT,
        progress REAL,
        status TEXT,
        gradient_start INTEGER,
        gradient_end INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE flights(
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
      )
    ''');
    await db.execute('''
      CREATE TABLE categories(
        id TEXT PRIMARY KEY,
        emoji TEXT,
        title TEXT,
        subtitle TEXT,
        color_start INTEGER,
        color_end INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE attractions(
        id TEXT PRIMARY KEY,
        emoji TEXT,
        name TEXT,
        location TEXT,
        rating TEXT,
        reviews TEXT,
        tag TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE hotels(
        id TEXT PRIMARY KEY,
        emoji TEXT,
        name TEXT,
        stars TEXT,
        reviews TEXT,
        price TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE timeline_events(
        id TEXT PRIMARY KEY,
        day TEXT,
        date TEXT,
        time TEXT,
        color INTEGER,
        title TEXT,
        subtitle TEXT,
        order_index INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE assist_items(
        id TEXT PRIMARY KEY,
        icon TEXT,
        title TEXT,
        subtitle TEXT,
        badge TEXT
      )
    ''');
  }

  Future<void> _seedData() async {
    final int? count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM destinations'),
    );

    if (count != null && count > 0) {
      return;
    }

    await db.transaction((txn) async {
      await txn.insert('destinations', {
        'id': 'dest_kyoto',
        'emoji': '🏯',
        'label': 'Hot',
        'title': 'Kyoto, Japan',
        'meta': '4.9 · 2,341 reviews',
        'gradient_start': const Color(0xFF0F4C6D).value,
        'gradient_end': const Color(0xFF0A2840).value,
      });
      await txn.insert('destinations', {
        'id': 'dest_bali',
        'emoji': '🌴',
        'label': 'New',
        'title': 'Bali, Indonesia',
        'meta': '4.8 · 1,876 reviews',
        'gradient_start': const Color(0xFF1A3A20).value,
        'gradient_end': const Color(0xFF0D2D15).value,
      });
      await txn.insert('destinations', {
        'id': 'dest_dubai',
        'emoji': '🏜️',
        'label': '',
        'title': 'Dubai, UAE',
        'meta': '4.7 · 3,102 reviews',
        'gradient_start': const Color(0xFF2A1A0D).value,
        'gradient_end': const Color(0xFF1A0D06).value,
      });
      await txn.insert('destinations', {
        'id': 'dest_paris',
        'emoji': '🗼',
        'label': '',
        'title': 'Paris, France',
        'meta': '4.8 · 4,521 reviews',
        'gradient_start': const Color(0xFF1A1530).value,
        'gradient_end': const Color(0xFF0E0D25).value,
      });

      await txn.insert('trips', {
        'id': 'trip_kyoto',
        'emoji': '🏯',
        'title': 'Kyoto Explorer',
        'subtitle': 'May 12 – May 20, 2025 · 8 days',
        'progress': 0.65,
        'status': '65% planned · 3 activities left',
        'gradient_start': const Color(0xFF0F4C6D).value,
        'gradient_end': const Color(0xFF0A2840).value,
      });
      await txn.insert('trips', {
        'id': 'trip_bali',
        'emoji': '🌴',
        'title': 'Bali Escape',
        'subtitle': 'Jul 3 – Jul 10, 2025 · 7 days',
        'progress': 0.20,
        'status': '20% planned · Just started',
        'gradient_start': const Color(0xFF1A3A20).value,
        'gradient_end': const Color(0xFF0D2D15).value,
      });

      await txn.insert('flights', {
        'id': 'flight_thai',
        'icon': '✈️',
        'airline': 'Thai Airways',
        'details': 'Economy · Direct',
        'price': '฿8,420',
        'depart': '07:30',
        'depart_airport': 'BKK',
        'arrive': '14:00',
        'arrive_airport': 'NRT',
        'duration': '5h 30m',
        'stop_info': 'Non-stop',
        'badge': 'Best Value',
      });
      await txn.insert('flights', {
        'id': 'flight_jal',
        'icon': '🇯🇵',
        'airline': 'Japan Airlines',
        'details': 'Economy · 1 Stop',
        'price': '฿7,190',
        'depart': '09:15',
        'depart_airport': 'BKK',
        'arrive': '19:00',
        'arrive_airport': 'NRT',
        'duration': '8h 45m',
        'stop_info': '1 stop · KUL',
        'badge': '',
      });
      await txn.insert('flights', {
        'id': 'flight_airasia',
        'icon': '🌏',
        'airline': 'AirAsia X',
        'details': 'Economy · Direct',
        'price': '฿5,880',
        'depart': '22:45',
        'depart_airport': 'BKK',
        'arrive': '06:35',
        'arrive_airport': 'NRT',
        'duration': '5h 50m',
        'stop_info': 'Non-stop',
        'badge': '',
      });

      await txn.insert('categories', {
        'id': 'cat_nature',
        'emoji': '🌿',
        'title': 'Nature',
        'subtitle': '142 places',
        'color_start': const Color(0xFF1A3A2A).value,
        'color_end': const Color(0xFF0F6E56).value,
      });
      await txn.insert('categories', {
        'id': 'cat_history',
        'emoji': '🏛️',
        'title': 'History',
        'subtitle': '89 places',
        'color_start': const Color(0xFF2A1A0A).value,
        'color_end': const Color(0xFF854F0B).value,
      });
      await txn.insert('categories', {
        'id': 'cat_lifestyle',
        'emoji': '☕',
        'title': 'Lifestyle',
        'subtitle': '211 places',
        'color_start': const Color(0xFF1A1A3A).value,
        'color_end': const Color(0xFF534AB7).value,
      });
      await txn.insert('categories', {
        'id': 'cat_adventure',
        'emoji': '🧗',
        'title': 'Adventure',
        'subtitle': '63 places',
        'color_start': const Color(0xFF3A1A1A).value,
        'color_end': const Color(0xFF993C1D).value,
      });

      await txn.insert('attractions', {
        'id': 'attr_fushimi',
        'emoji': '⛩️',
        'name': 'Fushimi Inari Shrine',
        'location': 'Kyoto, Japan',
        'rating': '★★★★★',
        'reviews': '4.9 (2,341)',
        'tag': 'History · Free entry',
      });
      await txn.insert('attractions', {
        'id': 'attr_fuji',
        'emoji': '🏔️',
        'name': 'Mount Fuji Day Trip',
        'location': 'Yamanashi, Japan',
        'rating': '★★★★★',
        'reviews': '4.8 (1,092)',
        'tag': 'Adventure · From ฿1,200',
      });

      await txn.insert('hotels', {
        'id': 'hotel_ritz',
        'emoji': '🏨',
        'name': 'The Ritz-Carlton Kyoto',
        'stars': '★★★★★',
        'reviews': '4.9 · 856 reviews',
        'price': '฿12,400',
      });

      await txn.insert('timeline_events', {
        'id': 'event_flight',
        'day': 'Day 1',
        'date': 'Monday, May 12, 2025',
        'time': '07:30',
        'color': const Color(0xFFFF6B6B).value,
        'title': 'Flight TG622 · BKK → NRT',
        'subtitle': 'Thai Airways · Economy · Gate B12',
        'order_index': 1,
      });
      await txn.insert('timeline_events', {
        'id': 'event_transfer',
        'day': 'Day 1',
        'date': 'Monday, May 12, 2025',
        'time': '14:00',
        'color': const Color(0xFFFFB347).value,
        'title': 'Arrive NRT · Transfer to Kyoto',
        'subtitle': 'Shinkansen · ~2h 30m · ¥13,870',
        'order_index': 2,
      });
      await txn.insert('timeline_events', {
        'id': 'event_checkin',
        'day': 'Day 1',
        'date': 'Monday, May 12, 2025',
        'time': '18:00',
        'color': const Color(0xFF00C9A7).value,
        'title': 'Hotel Check-in · Ritz-Carlton Kyoto',
        'subtitle': 'Confirmation #RC-28741 · Room 812',
        'order_index': 3,
      });
      await txn.insert('timeline_events', {
        'id': 'event_shrine',
        'day': 'Day 2',
        'date': 'Tuesday, May 13, 2025',
        'time': '08:00',
        'color': const Color(0xFF00C9A7).value,
        'title': 'Fushimi Inari Morning Visit',
        'subtitle': 'Free entry · Bring camera · 3h estimated',
        'order_index': 4,
      });
      await txn.insert('timeline_events', {
        'id': 'event_lunch',
        'day': 'Day 2',
        'date': 'Tuesday, May 13, 2025',
        'time': '13:00',
        'color': const Color(0xFF4ECDC4).value,
        'title': 'Lunch · Nishiki Market',
        'subtitle': 'Local street food · Budget ฿400',
        'order_index': 5,
      });

      await txn.insert('assist_items', {
        'id': 'assist_maps',
        'icon': '🗺️',
        'title': 'Offline Maps',
        'subtitle': 'Downloaded for Kyoto region',
        'badge': '532 MB saved',
      });
      await txn.insert('assist_items', {
        'id': 'assist_docs',
        'icon': '🛂',
        'title': 'Documents',
        'subtitle': 'Passport, Visa, Insurance',
        'badge': '3 stored',
      });
      await txn.insert('assist_items', {
        'id': 'assist_sim',
        'icon': '📡',
        'title': 'Travel SIM',
        'subtitle': 'eSIM for Japan · 10GB',
        'badge': 'Active',
      });
      await txn.insert('assist_items', {
        'id': 'assist_help',
        'icon': '🆘',
        'title': 'Emergency',
        'subtitle': 'Local contacts & hotlines',
        'badge': 'Offline ready',
      });
    });
  }

  Future<List<Destination>> getDestinations() async {
    final List<Map<String, Object?>> rows = await db.query('destinations');
    return rows.map(Destination.fromMap).toList();
  }

  Future<List<TripData>> getTrips() async {
    final List<Map<String, Object?>> rows = await db.query('trips');
    return rows.map(TripData.fromMap).toList();
  }

  Future<List<FlightResult>> getFlights() async {
    final List<Map<String, Object?>> rows = await db.query('flights');
    return rows.map(FlightResult.fromMap).toList();
  }

  Future<List<CategoryData>> getCategories() async {
    final List<Map<String, Object?>> rows = await db.query('categories');
    return rows.map(CategoryData.fromMap).toList();
  }

  Future<List<AttractionData>> getAttractions() async {
    final List<Map<String, Object?>> rows = await db.query('attractions');
    return rows.map(AttractionData.fromMap).toList();
  }

  Future<List<HotelData>> getHotels() async {
    final List<Map<String, Object?>> rows = await db.query('hotels');
    return rows.map(HotelData.fromMap).toList();
  }

  Future<List<TimelineEventData>> getTimelineEvents() async {
    final List<Map<String, Object?>> rows = await db.query('timeline_events', orderBy: 'order_index ASC');
    return rows.map(TimelineEventData.fromMap).toList();
  }

  Future<List<AssistItem>> getAssistItems() async {
    final List<Map<String, Object?>> rows = await db.query('assist_items');
    return rows.map(AssistItem.fromMap).toList();
  }
}

class Destination {
  Destination({
    required this.emoji,
    required this.label,
    required this.title,
    required this.meta,
    required this.gradientStart,
    required this.gradientEnd,
  });

  factory Destination.fromMap(Map<String, Object?> map) {
    return Destination(
      emoji: map['emoji']! as String,
      label: map['label']! as String,
      title: map['title']! as String,
      meta: map['meta']! as String,
      gradientStart: map['gradient_start']! as int,
      gradientEnd: map['gradient_end']! as int,
    );
  }

  final String emoji;
  final String label;
  final String title;
  final String meta;
  final int gradientStart;
  final int gradientEnd;
}

class TripData {
  TripData({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.status,
    required this.gradientStart,
    required this.gradientEnd,
  });

  factory TripData.fromMap(Map<String, Object?> map) {
    return TripData(
      emoji: map['emoji']! as String,
      title: map['title']! as String,
      subtitle: map['subtitle']! as String,
      progress: (map['progress']! as num).toDouble(),
      status: map['status']! as String,
      gradientStart: map['gradient_start']! as int,
      gradientEnd: map['gradient_end']! as int,
    );
  }

  final String emoji;
  final String title;
  final String subtitle;
  final double progress;
  final String status;
  final int gradientStart;
  final int gradientEnd;
}

class FlightResult {
  FlightResult({
    required this.icon,
    required this.airline,
    required this.details,
    required this.price,
    required this.depart,
    required this.departAirport,
    required this.arrive,
    required this.arriveAirport,
    required this.duration,
    required this.stopInfo,
    required this.badge,
  });

  factory FlightResult.fromMap(Map<String, Object?> map) {
    return FlightResult(
      icon: map['icon']! as String,
      airline: map['airline']! as String,
      details: map['details']! as String,
      price: map['price']! as String,
      depart: map['depart']! as String,
      departAirport: map['depart_airport']! as String,
      arrive: map['arrive']! as String,
      arriveAirport: map['arrive_airport']! as String,
      duration: map['duration']! as String,
      stopInfo: map['stop_info']! as String,
      badge: map['badge']! as String,
    );
  }

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
  final String badge;
}

class CategoryData {
  CategoryData({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.colorStart,
    required this.colorEnd,
  });

  factory CategoryData.fromMap(Map<String, Object?> map) {
    return CategoryData(
      emoji: map['emoji']! as String,
      title: map['title']! as String,
      subtitle: map['subtitle']! as String,
      colorStart: map['color_start']! as int,
      colorEnd: map['color_end']! as int,
    );
  }

  final String emoji;
  final String title;
  final String subtitle;
  final int colorStart;
  final int colorEnd;
}

class AttractionData {
  AttractionData({
    required this.emoji,
    required this.name,
    required this.location,
    required this.rating,
    required this.reviews,
    required this.tag,
  });

  factory AttractionData.fromMap(Map<String, Object?> map) {
    return AttractionData(
      emoji: map['emoji']! as String,
      name: map['name']! as String,
      location: map['location']! as String,
      rating: map['rating']! as String,
      reviews: map['reviews']! as String,
      tag: map['tag']! as String,
    );
  }

  final String emoji;
  final String name;
  final String location;
  final String rating;
  final String reviews;
  final String tag;
}

class HotelData {
  HotelData({
    required this.emoji,
    required this.name,
    required this.stars,
    required this.reviews,
    required this.price,
  });

  factory HotelData.fromMap(Map<String, Object?> map) {
    return HotelData(
      emoji: map['emoji']! as String,
      name: map['name']! as String,
      stars: map['stars']! as String,
      reviews: map['reviews']! as String,
      price: map['price']! as String,
    );
  }

  final String emoji;
  final String name;
  final String stars;
  final String reviews;
  final String price;
}

class TimelineEventData {
  TimelineEventData({
    required this.day,
    required this.date,
    required this.time,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.orderIndex,
  });

  factory TimelineEventData.fromMap(Map<String, Object?> map) {
    return TimelineEventData(
      day: map['day']! as String,
      date: map['date']! as String,
      time: map['time']! as String,
      color: map['color']! as int,
      title: map['title']! as String,
      subtitle: map['subtitle']! as String,
      orderIndex: map['order_index']! as int,
    );
  }

  final String day;
  final String date;
  final String time;
  final int color;
  final String title;
  final String subtitle;
  final int orderIndex;
}

class AssistItem {
  AssistItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
  });

  factory AssistItem.fromMap(Map<String, Object?> map) {
    return AssistItem(
      icon: map['icon']! as String,
      title: map['title']! as String,
      subtitle: map['subtitle']! as String,
      badge: map['badge']! as String,
    );
  }

  final String icon;
  final String title;
  final String subtitle;
  final String badge;
}
