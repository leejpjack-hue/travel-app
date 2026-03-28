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

// Export database for direct use
export { database };