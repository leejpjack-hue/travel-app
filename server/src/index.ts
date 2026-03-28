import express from 'express';
import cors from 'cors';
import path from 'path';
import fs from 'fs';
import { initializeDatabase, getDatabase, generateUUID } from './database';
import { createUser, findUserByEmail, verifyPassword, getCurrentUser, generateToken } from './auth';
const app = express();
const PORT = 6006;

// Initialize database on startup
initializeDatabase();

// Middleware
app.use(cors());
app.use(express.json());

// Health check
app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok', app: 'ZenVoyage', timestamp: new Date().toISOString() });
});

// Auth routes
app.post('/api/auth/register', async (req, res) => {
  try {
    const { email, name, password } = req.body;
    
    if (!email || !name || !password) {
      return res.status(400).json({ error: 'Email, name, and password are required' });
    }
    
    if (password.length < 8) {
      return res.status(400).json({ error: 'Password must be at least 8 characters' });
    }
    
    // Check if user already exists
    const existingUser = findUserByEmail(email);
    if (existingUser) {
      return res.status(409).json({ error: 'User already exists' });
    }
    
    const user = await createUser(email, name, password) as any;
    res.status(201).json({ 
      message: 'User created successfully',
      user: { id: user.id, email: user.email, name: user.name }
    });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    
    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }
    
    const user = findUserByEmail(email) as any;
    if (!user) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }
    
    const isValidPassword = await verifyPassword(password, user.password_hash);
    if (!isValidPassword) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }
    
    const token = generateToken(user.id, user.email);
    
    res.json({ 
      message: 'Login successful',
      token,
      user: { id: user.id, email: user.email, name: user.name }
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.get('/api/auth/me', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    res.json({ user: { id: user.id, email: user.email, name: user.name, avatar_url: user.avatar_url } });
  } catch (error) {
    res.status(401).json({ error: 'Unauthorized' });
  }
});

// Trips CRUD routes

// GET /api/trips - List all trips for current user
app.get('/api/trips', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    const stmt = db.prepare('SELECT * FROM trips WHERE user_id = ? ORDER BY created_at DESC');
    const trips = stmt.all(user.id);
    res.json({ trips });
  } catch (error: any) {
    res.status(401).json({ error: error.message || 'Unauthorized' });
  }
});

// POST /api/trips - Create a new trip
app.post('/api/trips', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    const { name, description, destination, start_date, end_date } = req.body;

    if (!name) {
      return res.status(400).json({ error: 'Trip name is required' });
    }

    const id = generateUUID();
    const now = new Date().toISOString();

    const stmt = db.prepare(`
      INSERT INTO trips (id, user_id, name, description, destination, start_date, end_date, status, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, 'draft', ?, ?)
    `);

    stmt.run(id, user.id, name, description || null, destination || null, start_date || null, end_date || null, now, now);

    const trip: any = db.prepare('SELECT * FROM trips WHERE id = ?').get(id);
    res.status(201).json({ trip });
  } catch (error: any) {
    res.status(error.message?.includes('Unauthorized') ? 401 : 500).json({ error: error.message || 'Internal server error' });
  }
});

// GET /api/trips/:id - Get a single trip
app.get('/api/trips/:id', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    // Get trip details with user filter
    const trip: any = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }
    
    // Get destinations for this trip
    const destinations = db.prepare('SELECT * FROM destinations WHERE trip_id = ? ORDER BY visit_date').all(trip.id);
    
    res.json({ trip, destinations });
  } catch (error: any) {
    res.status(401).json({ error: error.message || 'Unauthorized' });
  }
});

// PUT /api/trips/:id - Update a trip
app.put('/api/trips/:id', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    const { name, description, destination, start_date, end_date, status } = req.body;

    const existing: any = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!existing) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    const now = new Date().toISOString();
    const stmt = db.prepare(`
      UPDATE trips SET name = ?, description = ?, destination = ?, start_date = ?, end_date = ?, status = ?, updated_at = ?
      WHERE id = ? AND user_id = ?
    `);

    stmt.run(
      name !== undefined ? name : existing.name,
      description !== undefined ? description : existing.description,
      destination !== undefined ? destination : existing.destination,
      start_date !== undefined ? start_date : existing.start_date,
      end_date !== undefined ? end_date : existing.end_date,
      status !== undefined ? status : existing.status,
      now,
      req.params.id,
      user.id
    );

    const trip: any = db.prepare('SELECT * FROM trips WHERE id = ?').get(req.params.id);
    res.json({ trip });
  } catch (error: any) {
    res.status(error.message?.includes('Unauthorized') ? 401 : 500).json({ error: error.message || 'Internal server error' });
  }
});

// DELETE /api/trips/:id - Delete a trip
app.delete('/api/trips/:id', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();

    const existing = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!existing) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    db.prepare('DELETE FROM destinations WHERE trip_id = ?').run(req.params.id);
    db.prepare('DELETE FROM trips WHERE id = ?').run(req.params.id);

    res.json({ message: 'Trip deleted successfully' });
  } catch (error: any) {
    res.status(error.message?.includes('Unauthorized') ? 401 : 500).json({ error: error.message || 'Internal server error' });
  }
});

// Module 1: Pre-trip & Preferences APIs

// POST /api/trips/:id/import-flight - Import flight information
app.post('/api/trips/:id/import-flight', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    const { flight_number, departure_airport, arrival_airport, departure_time, arrival_time, airline } = req.body;

    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    const flightId = generateUUID();
    const now = new Date().toISOString();

    db.prepare(`
      INSERT INTO bookings (id, trip_id, type, title, booking_ref, date, start_time, end_time, location, status, created_at)
      VALUES (?, ?, 'flight', ?, ?, ?, ?, ?, ?, 'confirmed', ?)
    `).run(
      flightId, 
      trip.id, 
      `${airline} ${flight_number}` || 'Flight',
      flight_number || '',
      departure_time,
      arrival_time,
      `${departure_airport} → ${arrival_airport}` || '',
      'confirmed',
      now
    );

    const flight = db.prepare('SELECT * FROM bookings WHERE id = ?').get(flightId);
    res.status(201).json({ 
      message: 'Flight imported successfully',
      flight
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// GET /api/trips/:id/weather - Get weather forecast
app.get('/api/trips/:id/weather', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    
    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    // Mock weather data (in real app, call OpenWeather API)
    const mockWeather = {
      destination: trip.destination,
      forecast: [
        {
          date: trip.start_date,
          condition: 'sunny',
          temp_high: 25,
          temp_low: 18,
          humidity: 65,
          precipitation: 0
        },
        {
          date: trip.end_date,
          condition: 'partly_cloudy',
          temp_high: 23,
          temp_low: 16,
          humidity: 70,
          precipitation: 10
        }
      ]
    };

    res.json({ weather: mockWeather });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// GET /api/trips/:id/visa-info - Get visa requirements
app.get('/api/trips/:id/visa-info', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    
    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    // Mock visa info based on destination
    const mockVisaInfo = {
      destination: trip.destination,
      visa_required: true,
      visa_type: 'Tourist Visa',
      processing_time: '5-10 business days',
      documents: [
        'Passport valid for 6 months',
        'Visa application form',
        'Passport photos',
        'Flight itinerary',
        'Hotel reservations',
        'Proof of funds'
      ],
      entry_requirements: [
        'Return ticket',
        'Sufficient funds for stay',
        'Yellow fever certificate (if required)'
      ]
    };

    res.json({ visa_info: mockVisaInfo });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// POST /api/trips/:id/packing-list - Generate packing list
app.post('/api/trips/:id/packing-list', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    const { preferences, destination, duration } = req.body;

    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    // Generate packing list based on trip preferences
    const packingList = {
      essentials: [
        'Passport/ID',
        'Credit cards',
        'Cash',
        'Phone charger',
        'Medications',
        'Travel insurance'
      ],
      clothing: [
        'Underwear (duration + 1)',
        'Socks (duration + 1)',
        'T-shirts (duration + 1)',
        'Pants/trousers (3-4)',
        'Jacket',
        'Sleepwear',
        'Swimwear (if applicable)'
      ],
      electronics: [
        'Phone',
        'Power bank',
        'Camera (optional)',
        'Headphones'
      ],
      documents: [
        'Flight tickets',
        'Hotel confirmations',
        'Insurance details',
        'Emergency contacts'
      ]
    };

    const packingListId = generateUUID();
    const now = new Date().toISOString();

    // Store packing list in database
    db.prepare(`
      INSERT INTO destinations (id, trip_id, name, type, description, created_at, updated_at)
      VALUES (?, ?, 'Packing List', 'packing_list', ?, ?, ?)
    `).run(
      packingListId,
      trip.id,
      JSON.stringify(packingList),
      now,
      now
    );

    res.status(201).json({
      message: 'Packing list generated successfully',
      packing_list: packingList
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// GET /api/templates - List available templates
app.get('/api/templates', (req, res) => {
  try {
    const mockTemplates = [
      {
        id: 'tokyo-basic',
        name: '東京基本行程',
        description: '3天東京經典行程',
        duration: 3,
        destinations: ['淺草寺', '東京塔', '新宿', '渋谷'],
        preferences: {
          pace: 'moderate',
          transport: 'public',
          budget: 'medium'
        }
      },
      {
        id: 'osaka-food',
        name: '大阪美食之旅',
        description: '4天大阪美食探險',
        duration: 4,
        destinations: ['道頓堀', '大阪城', '心齋橋', '黑門市場'],
        preferences: {
          pace: 'relaxed',
          transport: 'walking',
          budget: 'low'
        }
      }
    ];

    res.json({ templates: mockTemplates });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// POST /api/trips/from-template/:templateId - Create trip from template
app.post('/api/trips/from-template/:templateId', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    const { name, start_date, end_date } = req.body;

    const template = {
      id: req.params.templateId,
      name: 'Template Name',
      destinations: ['Destination 1', 'Destination 2'],
      preferences: { pace: 'moderate', transport: 'public' }
    };

    if (!name || !start_date || !end_date) {
      return res.status(400).json({ error: 'Name, start_date, and end_date are required' });
    }

    const tripId = generateUUID();
    const now = new Date().toISOString();

    // Create trip
    const stmt = db.prepare(`
      INSERT INTO trips (id, user_id, name, destination, start_date, end_date, preferences, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

    stmt.run(
      tripId,
      user.id,
      name,
      template.destinations.join(', '),
      start_date,
      end_date,
      JSON.stringify(template.preferences),
      now,
      now
    );

    // Add destinations from template
    template.destinations.forEach((dest, index) => {
      const destId = generateUUID();
      db.prepare(`
        INSERT INTO destinations (id, trip_id, name, type, visit_date, created_at, updated_at)
        VALUES (?, ?, ?, 'destination', ?, ?, ?)
      `).run(destId, tripId, dest, new Date(start_date).setDate(new Date(start_date).getDate() + index), now, now);
    });

    const trip: any = db.prepare('SELECT * FROM trips WHERE id = ?').get(tripId);
    res.status(201).json({
      message: 'Trip created from template successfully',
      trip
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// Serve Flutter Web static files (after API routes)
const flutterBuildPath = path.join(__dirname, '../../app/build/web');
if (fs.existsSync(flutterBuildPath)) {
  app.use(express.static(flutterBuildPath));
}

// Fallback to Flutter index.html (only if it exists)
app.get('*', (_req, res) => {
  if (fs.existsSync(path.join(flutterBuildPath, 'index.html'))) {
    res.sendFile(path.join(flutterBuildPath, 'index.html'));
  } else {
    res.status(404).json({ error: 'Not found' });
  }
});

// Error handling middleware
app.use((err: any, req: any, res: any, next: any) => {
  console.error('Server error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\n🛑 Received SIGINT, shutting down gracefully...');
  // TODO: Close database connection
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('\n🛑 Received SIGTERM, shutting down gracefully...');
  // TODO: Close database connection
  process.exit(0);
});

app.listen(PORT, () => {
  console.log(`🚀 ZenVoyage server running on http://localhost:${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/api/health`);
});


