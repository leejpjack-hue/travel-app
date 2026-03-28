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
        status TEXT DEFAULT 'draft',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
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
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
      )
    `);
    
    console.log('📊 Database tables created/verified');
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