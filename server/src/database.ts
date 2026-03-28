import Database from 'better-sqlite3';
import path from 'path';

// Database instance
let database: Database.Database | null = null;

// Initialize database
export function initializeDatabase() {
  try {
    const dbPath = path.join(__dirname, '../../data/travel-app.db');

    // Create data directory if it doesn't exist
    const fs = require('fs');
    const dataDir = path.join(__dirname, '../../data');
    if (!fs.existsSync(dataDir)) {
      fs.mkdirSync(dataDir, { recursive: true });
    }

    database = new Database(dbPath);

    // Enable foreign key constraints
    database.pragma('foreign_keys = ON');

    // Create tables
    createTables();

    console.log('🗄️ SQLite database initialized successfully');
    console.log(`📁 Database file: ${dbPath}`);
  } catch (error) {
    console.error('❌ Failed to initialize SQLite database:', error);
    // Fallback to in-memory if file-based fails
    database = new Database(':memory:');
    createTables();
    console.log('⚠️  Falling back to in-memory database');
  }
}

// Create database tables
function createTables() {
  if (!database) return;

  try {
    // Create users table
    database.exec(`
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        avatar_url TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Create trips table
    database.exec(`
      CREATE TABLE IF NOT EXISTS trips (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        destination TEXT,
        start_date DATE,
        end_date DATE,
        timezone TEXT,
        base_location TEXT,
        preferences TEXT, -- JSON
        template_id TEXT,
        created_by TEXT NOT NULL,
        status TEXT DEFAULT 'draft',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    `);

    // Create collaborators table
    database.exec(`
      CREATE TABLE IF NOT EXISTS collaborators (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'editor',
        invited_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    `);

    // Create destinations table
    database.exec(`
      CREATE TABLE IF NOT EXISTS destinations (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        description TEXT,
        latitude REAL,
        longitude REAL,
        address TEXT,
        visit_date DATETIME,
        duration_hours REAL,
        notes TEXT,
        business_hours_start TEXT,
        business_hours_end TEXT,
        business_days TEXT, -- JSON array of days
        order_index INTEGER DEFAULT 0,
        locked BOOLEAN DEFAULT FALSE,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
      )
    `);

    // Create bookings table for flights, hotels, etc.
    database.exec(`
      CREATE TABLE IF NOT EXISTS bookings (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        booking_ref TEXT,
        date DATE,
        start_time TEXT,
        end_time TEXT,
        location TEXT,
        cost INTEGER,
        currency TEXT DEFAULT 'JPY',
        status TEXT DEFAULT 'confirmed',
        voucher_url TEXT,
        notes TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
      )
    `);

    console.log('📊 Database tables created/verified');

    // Create timeline management tables
    database.exec(`
      CREATE TABLE IF NOT EXISTS timeline_items (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        destination_id TEXT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        start_time DATETIME NOT NULL,
        end_time DATETIME NOT NULL,
        duration_minutes INTEGER,
        order_index INTEGER DEFAULT 0,
        locked BOOLEAN DEFAULT FALSE,
        buffer_minutes INTEGER DEFAULT 0,
        walking_distance_meters INTEGER,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE,
        FOREIGN KEY (destination_id) REFERENCES destinations (id) ON DELETE SET NULL
      )
    `);

    database.exec(`
      CREATE TABLE IF NOT EXISTS travel_times (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        from_destination_id TEXT,
        to_destination_id TEXT,
        transport_mode TEXT NOT NULL,
        duration_minutes INTEGER NOT NULL,
        distance_meters INTEGER,
        cost INTEGER,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE,
        FOREIGN KEY (from_destination_id) REFERENCES destinations (id) ON DELETE CASCADE,
        FOREIGN KEY (to_destination_id) REFERENCES destinations (id) ON DELETE CASCADE
      )
    `);

    database.exec(`
      CREATE TABLE IF NOT EXISTS buffer_settings (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        type TEXT NOT NULL, -- 'buffer' or 'gap'
        duration_minutes INTEGER DEFAULT 30,
        applied_to TEXT NOT NULL, -- 'all' or 'specific'
        destination_ids TEXT, -- JSON array of destination IDs
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
      )
    `);

    database.exec(`
      CREATE TABLE IF NOT EXISTS timezone_settings (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        home_timezone TEXT NOT NULL,
        destination_timezone TEXT NOT NULL,
        timezone_offset_hours INTEGER NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
      )
    `);

    database.exec(`
      CREATE TABLE IF NOT EXISTS weather_alternatives (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        destination_id TEXT,
        weather_condition TEXT NOT NULL,
        alternative_name TEXT NOT NULL,
        alternative_type TEXT,
        notes TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE,
        FOREIGN KEY (destination_id) REFERENCES destinations (id) ON DELETE CASCADE
      )
    `);

    console.log('🕐 Timeline management tables created/verified');

    // Create transportation planning tables
    database.exec(`
      CREATE TABLE IF NOT EXISTS transportation_modes (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL, -- 'walking', 'public', 'taxi', 'car', 'bike', 'train', 'bus', 'ferry'
        cost_per_km INTEGER DEFAULT 0,
        duration_factor REAL DEFAULT 1.0,
        reliability_score REAL DEFAULT 1.0,
        carbon_footprint_score REAL DEFAULT 1.0,
        icon TEXT,
        description TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
      )
    `);

    database.exec(`
      CREATE TABLE IF NOT EXISTS route_optimizations (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        name TEXT NOT NULL,
        algorithm TEXT NOT NULL, -- 'nearest_neighbor', 'genetic', 'simulated_annealing', 'two_opt'
        total_duration_minutes INTEGER,
        total_distance_meters INTEGER,
        total_cost INTEGER,
        optimized_route_order TEXT, -- JSON array of destination IDs
        waypoints TEXT, -- JSON array of coordinates
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
      )
    `);

    database.exec(`
      CREATE TABLE IF NOT EXISTS transportation_segments (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        from_destination_id TEXT NOT NULL,
        to_destination_id TEXT NOT NULL,
        transport_mode_id TEXT NOT NULL,
        duration_minutes INTEGER NOT NULL,
        distance_meters INTEGER NOT NULL,
        cost INTEGER DEFAULT 0,
        instructions TEXT, -- JSON array of navigation instructions
        departure_time DATETIME,
        arrival_time DATETIME,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE,
        FOREIGN KEY (from_destination_id) REFERENCES destinations (id) ON DELETE CASCADE,
        FOREIGN KEY (to_destination_id) REFERENCES destinations (id) ON DELETE CASCADE,
        FOREIGN KEY (transport_mode_id) REFERENCES transportation_modes (id) ON DELETE CASCADE
      )
    `);

    console.log('🚗 Transportation planning tables created/verified');

    // Module 3: Japanese Transport Ticket Calculator (F23)
    database.exec(`
      CREATE TABLE IF NOT EXISTS japan_transport_tickets (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        ticket_name TEXT NOT NULL,
        ticket_type TEXT NOT NULL, -- 'jr_pass', 'ic_card', 'rail_pass', 'bus_pass', 'subway_pass', 'tram_pass'
        issuer TEXT NOT NULL, -- 'JR', 'Tokyo Metro', 'Odakyu', etc.
        description TEXT,
        price_yen INTEGER NOT NULL,
        validity_days INTEGER,
        validity_period TEXT, -- JSON with start_date and end_date
        coverage_areas TEXT, -- JSON array of covered areas/lines
        eligible_routes TEXT, -- JSON of route eligibility
        conditions TEXT, -- JSON of usage conditions
        is_active BOOLEAN DEFAULT TRUE,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
      )
    `);

    database.exec(`
      CREATE TABLE IF NOT EXISTS japan_ticket_calculations (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        ticket_id TEXT NOT NULL,
        calculation_date DATETIME DEFAULT CURRENT_TIMESTAMP,
        planned_trips TEXT, -- JSON array of planned trips
        calculated_cost_yen INTEGER,
        alternative_ticket_suggestions TEXT, -- JSON of suggested alternatives
        savings_yen INTEGER,
        breakeven_analysis TEXT, -- JSON with breakeven point analysis
        recommendation TEXT,
        notes TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE,
        FOREIGN KEY (ticket_id) REFERENCES japan_transport_tickets (id) ON DELETE CASCADE
      )
    `);

    database.exec(`
      CREATE TABLE IF NOT EXISTS japan_ticket_usage_records (
        id TEXT PRIMARY KEY,
        ticket_id TEXT NOT NULL,
        trip_id TEXT NOT NULL,
        used_date DATETIME NOT NULL,
        from_location TEXT NOT NULL,
        to_location TEXT NOT NULL,
        transport_mode TEXT NOT NULL, -- 'train', 'bus', 'subway', 'shinkansen'
        distance_km REAL,
        cost_yen INTEGER,
        is_valid BOOLEAN DEFAULT TRUE,
        validation_notes TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (ticket_id) REFERENCES japan_transport_tickets (id) ON DELETE CASCADE,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
      )
    `);

    // Insert sample Japanese transport tickets
    insertSampleJapanTickets();

    console.log('🎫 Japanese transport ticket calculator tables created/verified');

    // Module 4: POI & Content tables
    // Custom map pins table (F31)
    database.exec(`
      CREATE TABLE IF NOT EXISTS custom_pins (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL, -- 'restaurant', 'hotel', 'attraction', 'transport', 'shopping', 'other'
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        address TEXT,
        description TEXT,
        icon TEXT DEFAULT '📍',
        color TEXT DEFAULT '#FF5733',
        size INTEGER DEFAULT 20,
        z_index INTEGER DEFAULT 1,
        is_visible BOOLEAN DEFAULT TRUE,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
      )
    `);

    // Multi-dimensional tags table (F33)
    database.exec(`
      CREATE TABLE IF NOT EXISTS poi_tags (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL, -- 'cuisine', 'price_range', 'style', 'activity_type', 'facility', 'season'
        subcategory TEXT,
        icon TEXT,
        color TEXT,
        description TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);

    database.exec(`
      CREATE TABLE IF NOT EXISTS poi_tag_assignments (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        custom_pin_id TEXT,
        destination_id TEXT,
        tag_id TEXT NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE,
        FOREIGN KEY (custom_pin_id) REFERENCES custom_pins (id) ON DELETE CASCADE,
        FOREIGN KEY (destination_id) REFERENCES destinations (id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES poi_tags (id) ON DELETE CASCADE
      )
    `);

    // POI reviews and notes table (F35)
    database.exec(`
      CREATE TABLE IF NOT EXISTS poi_reviews (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        custom_pin_id TEXT,
        destination_id TEXT,
        user_id TEXT NOT NULL,
        rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
        title TEXT,
        content TEXT,
        visit_date DATE,
        photos TEXT, -- JSON array of photo URLs
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE,
        FOREIGN KEY (custom_pin_id) REFERENCES custom_pins (id) ON DELETE CASCADE,
        FOREIGN KEY (destination_id) REFERENCES destinations (id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    `);

    // Bilingual POI names table (F38)
    database.exec(`
      CREATE TABLE IF NOT EXISTS poi_names (
        id TEXT PRIMARY KEY,
        custom_pin_id TEXT,
        destination_id TEXT,
        language TEXT NOT NULL, -- 'zh', 'ja', 'en'
        local_name TEXT NOT NULL,
        romanization TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (custom_pin_id) REFERENCES custom_pins (id) ON DELETE CASCADE,
        FOREIGN KEY (destination_id) REFERENCES destinations (id) ON DELETE CASCADE
      )
    `);

    // Seasonal alerts table (F39)
    database.exec(`
      CREATE TABLE IF NOT EXISTS seasonal_alerts (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        custom_pin_id TEXT,
        destination_id TEXT,
        season TEXT NOT NULL, -- 'spring', 'summer', 'autumn', 'winter'
        alert_type TEXT NOT NULL, -- 'best_time', 'avoid', 'special_event'
        title TEXT NOT NULL,
        description TEXT,
        start_date DATE,
        end_date DATE,
        is_active BOOLEAN DEFAULT TRUE,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE,
        FOREIGN KEY (custom_pin_id) REFERENCES custom_pins (id) ON DELETE CASCADE,
        FOREIGN KEY (destination_id) REFERENCES destinations (id) ON DELETE CASCADE
      )
    `);

    // Experience bookings table (F37)
    database.exec(`
      CREATE TABLE IF NOT EXISTS experience_bookings (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        experience_id TEXT NOT NULL,
        experience_name TEXT NOT NULL,
        experience_type TEXT, -- 'tour', 'activity', 'workshop', 'cultural', 'adventure'
        provider_name TEXT,
        date DATE NOT NULL,
        start_time TIME NOT NULL,
        end_time TIME NOT NULL,
        participants INTEGER DEFAULT 1,
        price_per_person REAL,
        total_price REAL,
        special_requirements TEXT, -- JSON
        booking_reference TEXT UNIQUE,
        status TEXT DEFAULT 'confirmed', -- 'confirmed', 'cancelled', 'completed', 'no_show'
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    `);

    // Initialize default tags
    initializeDefaultPoiTags();

    console.log('📍 POI & Content tables created/verified');
  } catch (error) {
    console.error('❌ Failed to create tables:', error);
  }
}

// Get database instance
export function getDatabase(): Database.Database {
  if (!database) {
    initializeDatabase();
  }
  return database!;
}

// Utility function to generate UUIDs
export function generateUUID(): string {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

// Close database connection gracefully
export function closeDatabase() {
  if (database) {
    database.close();
    database = null;
    console.log('🔒 Database connection closed');
  }
}

// Initialize default POI tags
function initializeDefaultPoiTags() {
  if (!database) return;
  
  try {
    // Check if tags already exist
    const existingTags = database.prepare('SELECT COUNT(*) as count FROM poi_tags').get();
    if ((existingTags as any).count > 0) {
      console.log('🏷️ POI tags already exist, skipping initialization');
      return;
    }
    
    // Default cuisine tags
    const cuisineTags = [
      { name: '中華料理', category: 'cuisine', subcategory: 'chinese', icon: '🥟', color: '#FF6B6B', description: '中式料理' },
      { name: '日本料理', category: 'cuisine', subcategory: 'japanese', icon: '🍣', color: '#4ECDC4', description: '日式料理' },
      { name: '韓國料理', category: 'cuisine', subcategory: 'korean', icon: '🍜', color: '#45B7D1', description: '韓式料理' },
      { name: '義大利料理', category: 'cuisine', subcategory: 'italian', icon: '🍝', color: '#F7DC6F', description: '義式料理' },
      { name: '美式料理', category: 'cuisine', subcategory: 'american', icon: '🍔', color: '#BB8FCE', description: '美式料理' }
    ];
    
    // Default price range tags
    const priceTags = [
      { name: '平價', category: 'price_range', subcategory: 'budget', icon: '💰', color: '#2ECC71', description: '平價選擇' },
      { name: '中等', category: 'price_range', subcategory: 'moderate', icon: '💰💰', color: '#F39C12', description: '中等價位' },
      { name: '高級', category: 'price_range', subcategory: 'premium', icon: '💰💰💰', color: '#E74C3C', description: '高級享受' }
    ];
    
    // Default facility tags
    const facilityTags = [
      { name: 'WiFi', category: 'facility', subcategory: 'connectivity', icon: '📶', color: '#3498DB', description: '免費WiFi' },
      { name: '停車場', category: 'facility', subcategory: 'parking', icon: '🅿️', color: '#95A5A6', description: '停車服務' },
      { name: '無障礙', category: 'facility', subcategory: 'accessible', icon: '♿', color: '#9B59B6', description: '無障礙設施' },
      { name: '寵物友善', category: 'facility', subcategory: 'pet_friendly', icon: '🐕', color: '#E67E22', description: '歡迎寵物' }
    ];
    
    // Insert default tags
    const allTags = [...cuisineTags, ...priceTags, ...facilityTags];
    
    for (const tag of allTags) {
      const tagId = generateUUID();
      database.prepare(`
        INSERT INTO poi_tags (id, name, category, subcategory, icon, color, description)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `).run(tagId, tag.name, tag.category, tag.subcategory, tag.icon, tag.color, tag.description);
    }
    
    console.log('🏷️ Default POI tags initialized successfully');
  } catch (error) {
    console.error('❌ Failed to initialize default POI tags:', error);
  }
}

// Insert sample Japanese transport tickets
function insertSampleJapanTickets() {
  if (!database) return;
  
  try {
    // Check if tickets already exist
    const existingTickets = database.prepare('SELECT COUNT(*) as count FROM japan_transport_tickets').get();
    if ((existingTickets as any).count > 0) {
      console.log('🎫 Japanese transport tickets already exist, skipping insertion');
      return;
    }
    
    // Sample JR Pass tickets
    const jrPasses = [
      {
        ticket_name: 'JR Pass 7日券',
        ticket_type: 'rail_pass',
        issuer: 'JR',
        description: '日本全國鐵路7日通票，包括新幹線在內的大部分JR線路',
        price_yen: 29650,
        validity_days: 7,
        coverage_areas: ['全国', '新幹線', 'JR在来線'],
        conditions: {
          consecutive_use: true,
          seat_reservation: 'recommended',
          exchange_order_required: true
        }
      },
      {
        ticket_name: '東京都内Pass',
        ticket_type: 'subway_pass',
        issuer: 'Tokyo Metro',
        description: '東京地下鐵24/48/72小時券',
        price_yen: 800, // 24小时
        validity_days: 1,
        coverage_areas: ['Tokyo Metro lines'],
        conditions: {
          consecutive_use: false,
          unlimited_ride: true
        }
      },
      {
        ticket_name: 'Suica卡',
        ticket_type: 'ic_card',
        issuer: 'JR East',
        description: '可充值的IC卡，適用於全日本大部分交通工具',
        price_yen: 2000, // 初始充值
        validity_days: null,
        coverage_areas: ['全日本交通網'],
        conditions: {
          refundable: true,
          minimum_charge: 1000
        }
      }
    ];
    
    for (const ticket of jrPasses) {
      const ticketId = generateUUID();
      database.prepare(`
        INSERT INTO japan_transport_tickets 
        (id, trip_id, ticket_name, ticket_type, issuer, description, price_yen, validity_days, coverage_areas, conditions, is_active)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).run(
        ticketId,
        'sample-trip', // This will be updated when actual trip is created
        ticket.ticket_name,
        ticket.ticket_type,
        ticket.issuer,
        ticket.description,
        ticket.price_yen,
        ticket.validity_days,
        JSON.stringify(ticket.coverage_areas),
        JSON.stringify(ticket.conditions),
        true
      );
    }
    
    console.log('🎫 Sample Japanese transport tickets inserted successfully');
  } catch (error) {
    console.error('❌ Failed to insert sample Japanese transport tickets:', error);
  }
}

// Export database for direct use
export { database };