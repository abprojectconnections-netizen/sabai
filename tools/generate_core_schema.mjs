import fs from 'node:fs/promises';

const out = 'D:/Project/apptravel/database/migrations/000001_travel_super_app_schema.up.sql';
const down = 'D:/Project/apptravel/database/migrations/000001_travel_super_app_schema.down.sql';

// Core production schema: intentionally bounded to 101 tables for phase delivery.
const modules = {
  identity: ['users', 'user_profiles', 'roles', 'permissions', 'user_roles', 'role_permissions', 'oauth_accounts', 'auth_sessions', 'devices', 'otp_requests'],
  geography: ['countries', 'cities', 'airports', 'currencies', 'exchange_rates', 'weather_snapshots'],
  catalog: ['destinations', 'destination_categories', 'destination_category_map', 'destination_media', 'airlines', 'flights', 'flight_schedules', 'flight_prices', 'hotels', 'hotel_rooms', 'hotel_room_rates', 'hotel_availability', 'restaurants', 'restaurant_menus', 'tour_places', 'tours', 'tour_schedules'],
  trip: ['trips', 'trip_members', 'trip_days', 'trip_activities', 'trip_expenses', 'favorites'],
  booking: ['bookings', 'booking_items', 'booking_travelers', 'booking_status_logs', 'cancellations', 'refunds'],
  payment: ['payment_methods', 'payments', 'payment_logs', 'invoices', 'receipts', 'webhook_events'],
  wallet: ['wallets', 'wallet_transactions', 'coins', 'coin_transactions', 'rewards', 'reward_redemptions'],
  partner: ['partners', 'partner_users', 'partner_documents', 'commissions', 'commission_transactions', 'affiliate_profiles', 'affiliate_links', 'affiliate_conversions'],
  marketing: ['promotions', 'promotion_rules', 'coupons', 'coupon_redemptions', 'campaigns'],
  engagement: ['reviews', 'review_media', 'ratings', 'notifications', 'notification_preferences', 'support_tickets', 'support_messages', 'chat_rooms', 'chat_members', 'chat_messages'],
  ai: ['ai_plans', 'ai_plan_items', 'ai_requests', 'ai_feedback', 'recommendations'],
  ops: ['documents', 'passports', 'visas', 'content_pages', 'banners', 'audit_logs', 'activity_logs', 'job_runs', 'system_settings', 'feature_flags'],
};

const extra = {
  users: ['email VARCHAR(255) NOT NULL UNIQUE', 'phone VARCHAR(30) UNIQUE', 'password_hash VARCHAR(255)', "status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE'", 'last_login_at DATETIME(6) NULL'],
  user_profiles: ['user_id CHAR(36) NOT NULL UNIQUE', 'first_name VARCHAR(100)', 'last_name VARCHAR(100)', 'avatar_url VARCHAR(500)'],
  roles: ['code VARCHAR(50) NOT NULL UNIQUE', 'name VARCHAR(100) NOT NULL'],
  permissions: ['code VARCHAR(100) NOT NULL UNIQUE', 'name VARCHAR(150) NOT NULL'],
  countries: ['code CHAR(2) NOT NULL UNIQUE', 'name VARCHAR(100) NOT NULL'],
  cities: ['country_id CHAR(36) NOT NULL', 'name VARCHAR(150) NOT NULL'],
  airports: ['city_id CHAR(36) NOT NULL', 'iata_code CHAR(3) NOT NULL UNIQUE', 'name VARCHAR(150) NOT NULL'],
  currencies: ['code CHAR(3) NOT NULL UNIQUE', 'name VARCHAR(100) NOT NULL', 'symbol VARCHAR(10)'],
  destinations: ['city_id CHAR(36)', 'name VARCHAR(200) NOT NULL', 'description TEXT', 'latitude DECIMAL(10,7)', 'longitude DECIMAL(10,7)', "status VARCHAR(30) NOT NULL DEFAULT 'DRAFT'"],
  hotels: ['partner_id CHAR(36)', 'city_id CHAR(36) NOT NULL', 'name VARCHAR(200) NOT NULL', 'address TEXT', "status VARCHAR(30) NOT NULL DEFAULT 'PENDING'"],
  hotel_rooms: ['hotel_id CHAR(36) NOT NULL', 'name VARCHAR(150) NOT NULL', 'capacity INT NOT NULL DEFAULT 1'],
  restaurants: ['partner_id CHAR(36)', 'city_id CHAR(36) NOT NULL', 'name VARCHAR(200) NOT NULL', 'address TEXT'],
  tours: ['partner_id CHAR(36)', 'destination_id CHAR(36)', 'name VARCHAR(200) NOT NULL', 'description TEXT'],
  trips: ['user_id CHAR(36) NOT NULL', 'destination_id CHAR(36)', 'name VARCHAR(200) NOT NULL', 'start_date DATE', 'end_date DATE', "status VARCHAR(30) NOT NULL DEFAULT 'DRAFT'"],
  trip_days: ['trip_id CHAR(36) NOT NULL', 'travel_date DATE NOT NULL', 'day_number INT NOT NULL'],
  trip_activities: ['trip_day_id CHAR(36) NOT NULL', 'destination_id CHAR(36)', 'title VARCHAR(200) NOT NULL', 'starts_at DATETIME(6)', 'ends_at DATETIME(6)'],
  bookings: ['user_id CHAR(36) NOT NULL', 'booking_code VARCHAR(40) NOT NULL UNIQUE', 'currency_code CHAR(3) NOT NULL', 'total_amount DECIMAL(14,2) NOT NULL', "status VARCHAR(30) NOT NULL DEFAULT 'PENDING'"],
  booking_items: ['booking_id CHAR(36) NOT NULL', 'item_type VARCHAR(30) NOT NULL', 'reference_id CHAR(36)', 'quantity INT NOT NULL DEFAULT 1', 'unit_amount DECIMAL(14,2) NOT NULL'],
  payments: ['booking_id CHAR(36)', 'user_id CHAR(36) NOT NULL', 'payment_method_id CHAR(36)', 'provider VARCHAR(50) NOT NULL', 'provider_reference VARCHAR(150)', 'amount DECIMAL(14,2) NOT NULL', 'currency_code CHAR(3) NOT NULL', "status VARCHAR(30) NOT NULL DEFAULT 'PENDING'"],
  wallets: ['user_id CHAR(36) NOT NULL UNIQUE', 'currency_code CHAR(3) NOT NULL', 'available_balance DECIMAL(14,2) NOT NULL DEFAULT 0', 'pending_balance DECIMAL(14,2) NOT NULL DEFAULT 0'],
  partners: ['owner_user_id CHAR(36) NOT NULL', 'legal_name VARCHAR(200) NOT NULL', "status VARCHAR(30) NOT NULL DEFAULT 'PENDING'"],
  promotions: ['name VARCHAR(200) NOT NULL', 'starts_at DATETIME(6)', 'ends_at DATETIME(6)', "status VARCHAR(30) NOT NULL DEFAULT 'DRAFT'"],
  coupons: ['promotion_id CHAR(36)', 'code VARCHAR(80) NOT NULL UNIQUE', 'max_redemptions INT', 'expires_at DATETIME(6)'],
  reviews: ['user_id CHAR(36) NOT NULL', 'subject_type VARCHAR(30) NOT NULL', 'subject_id CHAR(36) NOT NULL', 'rating DECIMAL(2,1) NOT NULL', 'body TEXT'],
  notifications: ['user_id CHAR(36) NOT NULL', 'type VARCHAR(50) NOT NULL', 'title VARCHAR(200) NOT NULL', 'body TEXT', 'read_at DATETIME(6)'],
  chat_rooms: ['room_type VARCHAR(30) NOT NULL', 'booking_id CHAR(36)', 'title VARCHAR(200)'],
  chat_messages: ['room_id CHAR(36) NOT NULL', 'sender_user_id CHAR(36) NOT NULL', 'body TEXT NOT NULL', 'sent_at DATETIME(6) NOT NULL'],
  ai_plans: ['user_id CHAR(36) NOT NULL', 'trip_id CHAR(36)', 'destination_id CHAR(36)', 'input_json JSON', 'result_json JSON'],
  documents: ['user_id CHAR(36)', 'owner_type VARCHAR(30) NOT NULL', 'owner_id CHAR(36) NOT NULL', 'file_url VARCHAR(500) NOT NULL', 'document_type VARCHAR(50) NOT NULL'],
  audit_logs: ['actor_user_id CHAR(36)', 'action VARCHAR(100) NOT NULL', 'subject_type VARCHAR(50) NOT NULL', 'subject_id CHAR(36)', 'before_json JSON', 'after_json JSON', 'ip_address VARCHAR(64)'],
};

const fk = [
  ['user_profiles','user_id','users'], ['user_roles','user_id','users'], ['user_roles','role_id','roles'], ['role_permissions','role_id','roles'], ['role_permissions','permission_id','permissions'], ['oauth_accounts','user_id','users'], ['auth_sessions','user_id','users'], ['devices','user_id','users'], ['cities','country_id','countries'], ['airports','city_id','cities'], ['destinations','city_id','cities'], ['hotels','partner_id','partners'], ['hotels','city_id','cities'], ['hotel_rooms','hotel_id','hotels'], ['restaurants','partner_id','partners'], ['restaurants','city_id','cities'], ['tours','partner_id','partners'], ['tours','destination_id','destinations'], ['trips','user_id','users'], ['trips','destination_id','destinations'], ['trip_days','trip_id','trips'], ['trip_activities','trip_day_id','trip_days'], ['trip_activities','destination_id','destinations'], ['bookings','user_id','users'], ['payments','booking_id','bookings'], ['payments','user_id','users'], ['wallets','user_id','users'], ['partners','owner_user_id','users'], ['coupons','promotion_id','promotions'], ['reviews','user_id','users'], ['notifications','user_id','users'], ['chat_messages','room_id','chat_rooms'], ['chat_messages','sender_user_id','users'], ['ai_plans','user_id','users'], ['ai_plans','trip_id','trips'], ['documents','user_id','users'], ['audit_logs','actor_user_id','users'],
];

const tables = Object.values(modules).flat();
const foreignColumns = new Map();
for (const [table, column] of fk) {
  if (!foreignColumns.has(table)) foreignColumns.set(table, new Set());
  foreignColumns.get(table).add(column);
}
const create = [`-- Travel Super App Core Schema (${tables.length} tables)`, '-- MySQL 8.0+, InnoDB, utf8mb4; UUIDs are generated by the application.', 'SET NAMES utf8mb4;', 'SET FOREIGN_KEY_CHECKS = 0;', ''];
for (const table of tables) {
  const defined = extra[table] ?? [];
  const names = new Set(defined.map((definition) => definition.split(/\s+/)[0]));
  const relationshipColumns = [...(foreignColumns.get(table) ?? [])]
    .filter((column) => !names.has(column))
    .map((column) => `${column} CHAR(36) NULL`);
  const columns = ['id CHAR(36) NOT NULL', 'created_at DATETIME(6) NOT NULL', 'updated_at DATETIME(6) NOT NULL', 'deleted_at DATETIME(6) NULL', ...defined, ...relationshipColumns];
  create.push(`CREATE TABLE ${table} (\n  ${columns.join(',\n  ')},\n  PRIMARY KEY (id),\n  INDEX idx_${table}_deleted_at (deleted_at)\n) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;`, '');
}
for (const [from, column, to] of fk) create.push(`ALTER TABLE ${from} ADD INDEX idx_${from}_${column} (${column}), ADD CONSTRAINT fk_${from}_${column}_${to} FOREIGN KEY (${column}) REFERENCES ${to}(id) ON UPDATE CASCADE ON DELETE RESTRICT;`);
create.push('', 'SET FOREIGN_KEY_CHECKS = 1;', '');
await fs.mkdir('D:/Project/apptravel/database/migrations', { recursive: true });
await fs.writeFile(out, create.join('\n'));
await fs.writeFile(down, ['-- WARNING: destructive rollback.', 'SET FOREIGN_KEY_CHECKS = 0;', ...tables.reverse().map((t) => `DROP TABLE IF EXISTS ${t};`), 'SET FOREIGN_KEY_CHECKS = 1;', ''].join('\n'));
console.log(`Generated ${tables.length} core tables and ${fk.length} foreign keys.`);
