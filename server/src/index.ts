import express from 'express';
import cors from 'cors';
import path from 'path';
import fs from 'fs';
import { initializeDatabase, getDatabase, generateUUID } from './database';
import { createUser, findUserByEmail, verifyPassword, getCurrentUser, generateToken } from './auth';
const app = express();
const PORT = process.env.PORT || 6006;

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
      (trip as any).id, 
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
      destination: (trip as any).destination,
      forecast: [
        {
          date: (trip as any).start_date,
          condition: 'sunny',
          temp_high: 25,
          temp_low: 18,
          humidity: 65,
          precipitation: 0
        },
        {
          date: (trip as any).end_date,
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
      destination: (trip as any).destination,
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
      (trip as any).id,
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

// Collaborators APIs
// POST /api/trips/:id/collaborators - Add collaborator to trip
app.post('/api/trips/:id/collaborators', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    const { collaborator_email, role = 'editor' } = req.body;

    if (!collaborator_email) {
      return res.status(400).json({ error: 'Collaborator email is required' });
    }

    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    // Check if collaborator exists as a user
    const collaboratorUser = findUserByEmail(collaborator_email) as any;
    if (!collaboratorUser) {
      return res.status(404).json({ error: 'Collaborator user not found' });
    }

    // Check if collaborator is already added
    const existing = db.prepare('SELECT * FROM collaborators WHERE trip_id = ? AND user_id = ?').get(req.params.id, collaboratorUser.id);
    if (existing) {
      return res.status(409).json({ error: 'Collaborator already added' });
    }

    const collaboratorId = generateUUID();
    const now = new Date().toISOString();

    db.prepare(`
      INSERT INTO collaborators (id, trip_id, user_id, role, invited_at)
      VALUES (?, ?, ?, ?, ?)
    `).run(collaboratorId, req.params.id, collaboratorUser.id, role, now);

    const collaborator = db.prepare('SELECT * FROM collaborators WHERE id = ?').get(collaboratorId) as any;
    res.status(201).json({
      message: 'Collaborator added successfully',
      collaborator: {
        id: collaborator.id,
        user_id: collaborator.user_id,
        email: collaboratorUser.email,
        name: collaboratorUser.name,
        role: collaborator.role,
        invited_at: collaborator.invited_at
      }
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// GET /api/trips/:id/collaborators - Get all collaborators for a trip
app.get('/api/trips/:id/collaborators', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    
    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    const collaborators = db.prepare(`
      SELECT c.*, u.email, u.name
      FROM collaborators c
      JOIN users u ON c.user_id = u.id
      WHERE c.trip_id = ?
      ORDER BY c.invited_at DESC
    `).all(req.params.id);

    res.json({ collaborators });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// DELETE /api/trips/:id/collaborators/:collaboratorId - Remove collaborator
app.delete('/api/trips/:id/collaborators/:collaboratorId', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    
    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    const collaborator = db.prepare('SELECT * FROM collaborators WHERE id = ? AND trip_id = ?').get(req.params.collaboratorId, req.params.id);
    if (!collaborator) {
      return res.status(404).json({ error: 'Collaborator not found' });
    }

    db.prepare('DELETE FROM collaborators WHERE id = ?').run(req.params.collaboratorId);

    res.json({ message: 'Collaborator removed successfully' });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// PUT /api/trips/:id/collaborators/:collaboratorId - Update collaborator role
app.put('/api/trips/:id/collaborators/:collaboratorId', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    const { role } = req.body;

    if (!role || !['viewer', 'editor', 'admin'].includes(role)) {
      return res.status(400).json({ error: 'Invalid role' });
    }

    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    const collaborator = db.prepare('SELECT * FROM collaborators WHERE id = ? AND trip_id = ?').get(req.params.collaboratorId, req.params.id);
    if (!collaborator) {
      return res.status(404).json({ error: 'Collaborator not found' });
    }

    const now = new Date().toISOString();
    db.prepare(`
      UPDATE collaborators SET role = ?, updated_at = ?
      WHERE id = ? AND trip_id = ?
    `).run(role, now, req.params.collaboratorId, req.params.id);

    const updatedCollaborator = db.prepare('SELECT * FROM collaborators WHERE id = ?').get(req.params.collaboratorId) as any;
    res.json({
      message: 'Collaborator role updated successfully',
      collaborator: {
        id: updatedCollaborator.id,
        user_id: updatedCollaborator.user_id,
        role: updatedCollaborator.role,
        invited_at: updatedCollaborator.invited_at
      }
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// Transportation Preferences APIs
// GET /api/users/me/preferences/transportation - Get user transportation preferences
app.get('/api/users/me/preferences/transportation', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    
    const preferences = db.prepare('SELECT transport_preferences FROM users WHERE id = ?').get(user.id) as any;
    
    const transportPrefs = preferences?.transport_preferences ? JSON.parse(preferences.transport_preferences) : {
      preferred_modes: ['public', 'walking'],
      avoid_tolls: false,
      max_walking_distance: 2000,
      wheelchair_accessible: false,
      pet_friendly: false,
      budget_level: 'medium'
    };

    res.json({ transportation_preferences: transportPrefs });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// PUT /api/users/me/preferences/transportation - Update transportation preferences
app.put('/api/users/me/preferences/transportation', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    const { preferred_modes = [], avoid_tolls = false, max_walking_distance = 2000, wheelchair_accessible = false, pet_friendly = false, budget_level = 'medium' } = req.body;

    const preferences = {
      preferred_modes,
      avoid_tolls,
      max_walking_distance,
      wheelchair_accessible,
      pet_friendly,
      budget_level,
      updated_at: new Date().toISOString()
    };

    db.prepare(`
      UPDATE users SET transport_preferences = ?, updated_at = ?
      WHERE id = ?
    `).run(JSON.stringify(preferences), new Date().toISOString(), user.id);

    res.json({
      message: 'Transportation preferences updated successfully',
      transportation_preferences: preferences
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// Schedule Preferences APIs
// GET /api/users/me/preferences/schedule - Get user schedule preferences
app.get('/api/users/me/preferences/schedule', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    
    const preferences = db.prepare('SELECT schedule_preferences FROM users WHERE id = ?').get(user.id) as any;
    
    const schedulePrefs = preferences?.schedule_preferences ? JSON.parse(preferences.schedule_preferences) : {
      preferred_start_time: '09:00',
      preferred_end_time: '18:00',
      meal_break_duration: 60,
      rest_break_duration: 30,
      max_daily_hours: 10,
      early_bird: false,
      night_owl: false,
      pace: 'moderate'
    };

    res.json({ schedule_preferences: schedulePrefs });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// PUT /api/users/me/preferences/schedule - Update schedule preferences
app.put('/api/users/me/preferences/schedule', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    const { preferred_start_time = '09:00', preferred_end_time = '18:00', meal_break_duration = 60, rest_break_duration = 30, max_daily_hours = 10, early_bird = false, night_owl = false, pace = 'moderate' } = req.body;

    const preferences = {
      preferred_start_time,
      preferred_end_time,
      meal_break_duration,
      rest_break_duration,
      max_daily_hours,
      early_bird,
      night_owl,
      pace,
      updated_at: new Date().toISOString()
    };

    db.prepare(`
      UPDATE users SET schedule_preferences = ?, updated_at = ?
      WHERE id = ?
    `).run(JSON.stringify(preferences), new Date().toISOString(), user.id);

    res.json({
      message: 'Schedule preferences updated successfully',
      schedule_preferences: preferences
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// Base Day Tour Mode APIs
// POST /api/trips/:id/base-tour-mode - Enable base day tour mode
app.post('/api/trips/:id/base-tour-mode', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    const { base_location, tour_radius = 5000, max_destinations = 5 } = req.body;

    if (!base_location) {
      return res.status(400).json({ error: 'Base location is required' });
    }

    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    const now = new Date().toISOString();
    db.prepare(`
      UPDATE trips SET base_location = ?, tour_radius = ?, max_destinations = ?, preferences = json_set(COALESCE(preferences, '{}'), '$.base_tour_mode', true), updated_at = ?
      WHERE id = ? AND user_id = ?
    `).run(base_location, tour_radius, max_destinations, now, req.params.id, user.id);

    // Generate sample nearby destinations
    const sampleDestinations = [
      { name: '咖啡店', type: 'cafe', distance: 200, duration: 30 },
      { name: '觀景台', type: 'viewpoint', distance: 800, duration: 45 },
      { name: '紀念品店', type: 'shopping', distance: 350, duration: 20 },
      { name: '午餐地點', type: 'restaurant', distance: 500, duration: 60 },
      { name: '公園', type: 'park', distance: 1200, duration: 90 }
    ];

    // Clear existing destinations and add new ones
    db.prepare('DELETE FROM destinations WHERE trip_id = ?').run(req.params.id);
    
    sampleDestinations.slice(0, max_destinations).forEach((dest, index) => {
      const destId = generateUUID();
      db.prepare(`
        INSERT INTO destinations (id, trip_id, name, type, description, visit_date, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      `).run(destId, req.params.id, dest.name, dest.type, `距離基地 ${dest.distance}m`, 
        new Date((trip as any).start_date).setDate(new Date((trip as any).start_date).getDate() + index), now, now);
    });

    const updatedTrip = db.prepare('SELECT * FROM trips WHERE id = ?').get(req.params.id);
    res.status(201).json({
      message: 'Base tour mode enabled successfully',
      trip: updatedTrip,
      suggested_destinations: sampleDestinations.slice(0, max_destinations)
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// GET /api/trips/:id/base-tour-mode - Check if base tour mode is enabled
app.get('/api/trips/:id/base-tour-mode', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    
    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    const baseTourMode = trip && (trip as any).preferences ? JSON.parse((trip as any).preferences)?.base_tour_mode || false : false;
    const baseLocation = (trip as any).base_location;

    res.json({
      base_tour_mode: baseTourMode,
      base_location: baseLocation,
      tour_radius: (trip as any).tour_radius || 5000,
      max_destinations: (trip as any).max_destinations || 5
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// API routes must be defined before static files

// Module 2: Timeline & Scheduling APIs

// GET /api/trips/:id/timeline - Get timeline for a trip
app.get('/api/trips/:id/timeline', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    
    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    // Get timeline items in order (simplified to avoid join issues)
    const timelineItems = db.prepare(`
      SELECT ti.*, 
             CASE WHEN ti.destination_id IS NOT NULL THEN 'destination' ELSE ti.type END as destination_name,
             ti.type as destination_type,
             '' as address
      FROM timeline_items ti
      WHERE ti.trip_id = ?
      ORDER BY ti.order_index
    `).all(req.params.id);

    // Get business hours conflicts (simplified - no business hours support yet)
    const conflicts: any[] = [];

    // Calculate walking distances
    const walkingDistances = db.prepare(`
      SELECT SUM(ti.walking_distance_meters) as total_walking_distance
      FROM timeline_items ti
      WHERE ti.trip_id = ? AND ti.walking_distance_meters > 0
    `).get(req.params.id);

    res.json({
      timeline_items: timelineItems,
      business_hours_conflicts: conflicts,
      total_walking_distance: (walkingDistances as any)?.total_walking_distance || 0,
      daily_summary: generateDailySummary(timelineItems)
    });
  } catch (error: any) {
    console.error('Timeline API error:', error);
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// POST /api/trips/:id/timeline - Add timeline item
app.post('/api/trips/:id/timeline', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    const { destination_id, name, type, start_time, end_time, duration_minutes, buffer_minutes = 0 } = req.body;

    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    // Get max order index
    const maxOrder = db.prepare('SELECT MAX(order_index) as max_index FROM timeline_items WHERE trip_id = ?').get(req.params.id);
    const newIndex = (maxOrder && (maxOrder as any)?.max_index || 0) + 1;

    const timelineId = generateUUID();
    const now = new Date().toISOString();

    db.prepare(`
      INSERT INTO timeline_items (id, trip_id, destination_id, name, type, start_time, end_time, duration_minutes, buffer_minutes, order_index, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      timelineId,
      req.params.id,
      destination_id,
      name,
      type,
      start_time,
      end_time,
      duration_minutes,
      buffer_minutes,
      newIndex,
      now
    );

    // Calculate and update walking distance (mock calculation)
    if (destination_id) {
      const walkingDistance = Math.floor(Math.random() * 1000) + 200; // Mock 200-1200m
      db.prepare('UPDATE timeline_items SET walking_distance_meters = ? WHERE id = ?').run(walkingDistance, timelineId);
    }

    const timelineItem = db.prepare('SELECT * FROM timeline_items WHERE id = ?').get(timelineId);
    res.status(201).json({
      message: 'Timeline item added successfully',
      timeline_item: timelineItem
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// PUT /api/trips/:id/timeline/:itemId - Update timeline item
app.put('/api/trips/:id/timeline/:itemId', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    const { name, start_time, end_time, duration_minutes, buffer_minutes, locked } = req.body;

    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    const existing = db.prepare('SELECT * FROM timeline_items WHERE id = ? AND trip_id = ?').get(req.params.itemId, req.params.id);
    if (!existing) {
      return res.status(404).json({ error: 'Timeline item not found' });
    }

    const now = new Date().toISOString();
    db.prepare(`
      UPDATE timeline_items SET 
        name = COALESCE(?, name),
        start_time = COALESCE(?, start_time),
        end_time = COALESCE(?, end_time),
        duration_minutes = COALESCE(?, duration_minutes),
        buffer_minutes = COALESCE(?, buffer_minutes),
        locked = COALESCE(?, locked),
        updated_at = ?
      WHERE id = ? AND trip_id = ?
    `).run(
      name,
      start_time,
      end_time,
      duration_minutes,
      buffer_minutes,
      locked,
      now,
      req.params.itemId,
      req.params.id
    );

    const updatedItem = db.prepare('SELECT * FROM timeline_items WHERE id = ?').get(req.params.itemId);
    res.json({
      message: 'Timeline item updated successfully',
      timeline_item: updatedItem
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// PUT /api/trips/:id/timeline/reorder - Reorder timeline items
app.put('/api/trips/:id/timeline/reorder', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    const { item_orders } = req.body; // Array of { item_id, new_index }

    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    const now = new Date().toISOString();
    for (const order of item_orders) {
      db.prepare(`
        UPDATE timeline_items SET order_index = ?, updated_at = ?
        WHERE id = ? AND trip_id = ?
      `).run(order.new_index, now, order.item_id, req.params.id);
    }

    res.json({ message: 'Timeline reordered successfully' });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// GET /api/trips/:id/timeline/conflicts - Check for timeline conflicts
app.get('/api/trips/:id/timeline/conflicts', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    
    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    // Get overlapping timeline items
    const conflicts = db.prepare(`
      SELECT ti1.name as item1_name, ti2.name as item2_name,
             ti1.start_time as item1_start, ti1.end_time as item1_end,
             ti2.start_time as item2_start, ti2.end_time as item2_end
      FROM timeline_items ti1
      JOIN timeline_items ti2 ON ti1.trip_id = ti2.trip_id AND ti1.id < ti2.id
      WHERE ti1.trip_id = ? 
        AND ti1.start_time < ti2.end_time AND ti1.end_time > ti2.start_time
      ORDER BY ti1.start_time
    `).all(req.params.id);

    // Get business hours conflicts
    const businessConflicts = db.prepare(`
      SELECT ti.name, ti.start_time, ti.end_time, d.name as destination_name,
             d.business_hours_start, d.business_hours_end
      FROM timeline_items ti
      JOIN destinations d ON ti.destination_id = d.id
      WHERE ti.trip_id = ? AND d.business_hours_start IS NOT NULL AND d.business_hours_end IS NOT NULL
        AND (ti.start_time < d.business_hours_start || ti.end_time > d.business_hours_end)
    `).all(req.params.id);

    res.json({
      overlapping_conflicts: conflicts,
      business_hours_conflicts: businessConflicts,
      total_conflicts: conflicts.length + businessConflicts.length
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// POST /api/trips/:id/timeline/smart-fill - Smart gap filling
app.post('/api/trips/:id/timeline/smart-fill', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    const { gap_start, gap_end, preferences = {} } = req.body;

    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    // Find suggested activities for the gap
    const gapMinutes = (new Date(gap_end).getTime() - new Date(gap_start).getTime()) / (1000 * 60);
    
    // Mock suggestions based on time of day and gap duration
    const suggestions = generateSmartFillSuggestions(gap_start, gapMinutes, preferences);
    
    // Add suggested timeline items
    const addedItems = [];
    for (const suggestion of suggestions) {
      if (suggestion.duration_minutes <= gapMinutes) {
        const timelineId = generateUUID();
        const maxOrder = db.prepare('SELECT MAX(order_index) as max_index FROM timeline_items WHERE trip_id = ?').get(req.params.id);
        const newIndex = (maxOrder && (maxOrder as any)?.max_index || 0) + 1;
        
        db.prepare(`
          INSERT INTO timeline_items (id, trip_id, name, type, start_time, end_time, duration_minutes, order_index, created_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        `).run(
          timelineId,
          req.params.id,
          suggestion.name,
          suggestion.type,
          suggestion.start_time,
          suggestion.end_time,
          suggestion.duration_minutes,
          newIndex,
          new Date().toISOString()
        );
        
        addedItems.push({ id: timelineId, ...suggestion });
      }
    }

    res.json({
      message: 'Smart fill completed successfully',
      added_items: addedItems,
      gap_filled_minutes: addedItems.reduce((sum, item) => sum + item.duration_minutes, 0)
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// GET /api/trips/:id/travel-times - Calculate point-to-point travel times
app.get('/api/trips/:id/travel-times', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    
    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    // Get timeline items with destination info
    const timelineItems = db.prepare(`
      SELECT ti.*, d.latitude, d.longitude, d.name as dest_name
      FROM timeline_items ti
      LEFT JOIN destinations d ON ti.destination_id = d.id
      WHERE ti.trip_id = ?
      ORDER BY ti.order_index
    `).all(req.params.id);

    // Calculate travel times between consecutive items
    const travelTimes = [];
    for (let i = 0; i < timelineItems.length - 1; i++) {
      const from = timelineItems[i] as any;
      const to = timelineItems[i + 1] as any;
      
      // Mock travel time calculation
      const travelTime = {
        from_destination: from.dest_name || 'Unknown',
        to_destination: to.dest_name || 'Unknown',
        transport_mode: 'walking',
        duration_minutes: Math.floor(Math.random() * 30) + 10, // 10-40 minutes mock
        distance_meters: Math.floor(Math.random() * 2000) + 100, // 100-2100m mock
        cost: 0
      };
      
      travelTimes.push(travelTime);
    }

    res.json({ travel_times: travelTimes });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// GET /api/trips/:id/timezone-settings - Get timezone settings
app.get('/api/trips/:id/timezone-settings', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    
    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    // Mock timezone data based on destination
    const timezoneSettings = db.prepare('SELECT * FROM timezone_settings WHERE trip_id = ?').get(req.params.id);
    if (!timezoneSettings) {
      // Generate default timezone settings
      const settings = {
        home_timezone: 'Asia/Taipei',
        destination_timezone: 'Asia/Tokyo',
        timezone_offset_hours: 1, // Tokyo is 1 hour ahead of Taipei
        created_at: new Date().toISOString()
      };
      
      // Save to database
      const settingsId = generateUUID();
      db.prepare(`
        INSERT INTO timezone_settings (id, trip_id, home_timezone, destination_timezone, timezone_offset_hours, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
      `).run(settingsId, req.params.id, settings.home_timezone, settings.destination_timezone, settings.timezone_offset_hours, settings.created_at);
      
      res.json(settings);
    } else {
      res.json(timezoneSettings);
    }
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// PUT /api/trips/:id/timezone-settings - Update timezone settings
app.put('/api/trips/:id/timezone-settings', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    const { home_timezone, destination_timezone } = req.body;

    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    // Calculate timezone offset
    const now = new Date();
    const homeTime = new Date(now.toLocaleString("en-US", {timeZone: home_timezone}));
    const destTime = new Date(now.toLocaleString("en-US", {timeZone: destination_timezone}));
    const offsetHours = Math.round((destTime.getTime() - homeTime.getTime()) / (1000 * 60 * 60));

    const existing = db.prepare('SELECT * FROM timezone_settings WHERE trip_id = ?').get(req.params.id);
    const nowTime = new Date().toISOString();
    
    if (existing) {
      db.prepare(`
        UPDATE timezone_settings SET 
          home_timezone = ?, 
          destination_timezone = ?, 
          timezone_offset_hours = ?, 
          created_at = ?
        WHERE trip_id = ?
      `).run(home_timezone, destination_timezone, offsetHours, nowTime, req.params.id);
    } else {
      const settingsId = generateUUID();
      db.prepare(`
        INSERT INTO timezone_settings (id, trip_id, home_timezone, destination_timezone, timezone_offset_hours, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
      `).run(settingsId, req.params.id, home_timezone, destination_timezone, offsetHours, nowTime);
    }

    const settings = db.prepare('SELECT * FROM timezone_settings WHERE trip_id = ?').get(req.params.id);
    res.json({
      message: 'Timezone settings updated successfully',
      timezone_settings: settings
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// GET /api/trips/:id/weather-alternatives - Get rainy day alternatives
app.get('/api/trips/:id/weather-alternatives', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    
    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    const alternatives = db.prepare(`
      SELECT wa.*, d.name as destination_name
      FROM weather_alternatives wa
      LEFT JOIN destinations d ON wa.destination_id = d.id
      WHERE wa.trip_id = ?
      ORDER BY wa.created_at DESC
    `).all(req.params.id);

    // Generate mock alternatives if none exist
    if (alternatives.length === 0) {
      const mockAlternatives = [
        {
          weather_condition: 'rain',
          alternative_name: '室内博物館',
          alternative_type: 'indoor',
          notes: '適合雨天參觀，免費WiFi和空調'
        },
        {
          weather_condition: 'rain',
          alternative_name: '購物中心',
          alternative_type: 'shopping',
          notes: '逛街、用餐、娛樂一應俱全'
        },
        {
          weather_condition: 'heavy_rain',
          alternative_name: '咖啡廳體驗',
          alternative_type: 'cafe',
          notes: '品嘗當地特色咖啡，休息避雨'
        }
      ];

      for (const alt of mockAlternatives) {
        const altId = generateUUID();
        db.prepare(`
          INSERT INTO weather_alternatives (id, trip_id, weather_condition, alternative_name, alternative_type, notes, created_at)
          VALUES (?, ?, ?, ?, ?, ?, ?)
        `).run(altId, req.params.id, alt.weather_condition, alt.alternative_name, alt.alternative_type, alt.notes, new Date().toISOString());
      }

      const newAlternatives = db.prepare(`
        SELECT wa.*, d.name as destination_name
        FROM weather_alternatives wa
        LEFT JOIN destinations d ON wa.destination_id = d.id
        WHERE wa.trip_id = ?
        ORDER BY wa.created_at DESC
      `).all(req.params.id);

      res.json({ weather_alternatives: newAlternatives });
    } else {
      res.json({ weather_alternatives: alternatives });
    }
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// Helper functions
function generateDailySummary(timelineItems: any[]) {
  const dailySummary: { [date: string]: any } = {};
  
  timelineItems.forEach(item => {
    const date = item.start_time.split('T')[0];
    if (!dailySummary[date]) {
      dailySummary[date] = {
        date,
        total_duration: 0,
        items_count: 0,
        walking_distance: 0,
        locked_items: 0
      };
    }
    
    dailySummary[date].total_duration += item.duration_minutes || 0;
    dailySummary[date].items_count += 1;
    dailySummary[date].walking_distance += item.walking_distance_meters || 0;
    if (item.locked) dailySummary[date].locked_items += 1;
  });
  
  return Object.values(dailySummary);
}

function generateSmartFillSuggestions(gapStart: string, gapMinutes: number, preferences: any) {
  const suggestions = [];
  const gapStartTime = new Date(gapStart);
  const hour = gapStartTime.getHours();
  
  // Morning suggestions (6-12)
  if (hour >= 6 && hour < 12) {
    if (gapMinutes >= 30) {
      suggestions.push({
        name: '早餐咖啡',
        type: 'meal',
        duration_minutes: 30,
        start_time: new Date(gapStartTime.getTime() + 10 * 60000).toISOString(),
        end_time: new Date(gapStartTime.getTime() + 40 * 60000).toISOString()
      });
    }
  }
  
  // Afternoon suggestions (12-17)
  if (hour >= 12 && hour < 17) {
    if (gapMinutes >= 45) {
      suggestions.push({
        name: '午休散步',
        type: 'activity',
        duration_minutes: 45,
        start_time: new Date(gapStartTime.getTime() + 15 * 60000).toISOString(),
        end_time: new Date(gapStartTime.getTime() + 60 * 60000).toISOString()
      });
    }
  }
  
  // Evening suggestions (17-22)
  if (hour >= 17 && hour < 22) {
    if (gapMinutes >= 60) {
      suggestions.push({
        name: '晚餐時間',
        type: 'meal',
        duration_minutes: 60,
        start_time: new Date(gapStartTime.getTime() + 20 * 60000).toISOString(),
        end_time: new Date(gapStartTime.getTime() + 80 * 60000).toISOString()
      });
    }
  }
  
  return suggestions.slice(0, 3); // Return top 3 suggestions
}

// Transportation Planning APIs (Module 3: F21-F30)

// GET /api/trips/:id/transportation-modes - Get available transportation modes for a trip
app.get('/api/trips/:id/transportation-modes', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    
    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }
    
    // Get user transportation preferences
    const userPrefs = db.prepare('SELECT transport_preferences FROM users WHERE id = ?').get(user.id) as any;
    const preferences = userPrefs?.transport_preferences ? JSON.parse(userPrefs.transport_preferences) : {};
    
    // Get existing transportation modes for this trip
    const existingModes = db.prepare('SELECT * FROM transportation_modes WHERE trip_id = ?').all(req.params.id);
    
    // Default transportation modes based on preferences
    const defaultModes = [
      {
        id: generateUUID(),
        trip_id: req.params.id,
        name: '步行',
        type: 'walking',
        cost_per_km: 0,
        duration_factor: 1.0,
        reliability_score: 0.9,
        carbon_footprint_score: 0.1,
        icon: '🚶',
        description: '適合短距離移動，環保健康'
      },
      {
        id: generateUUID(),
        trip_id: req.params.id,
        name: '大眾運輸',
        type: 'public',
        cost_per_km: 30,
        duration_factor: 1.2,
        reliability_score: 0.8,
        carbon_footprint_score: 0.5,
        icon: '🚌',
        description: '經濟实惠，覆蓋範圍廣'
      },
      {
        id: generateUUID(),
        trip_id: req.params.id,
        name: '計程車',
        type: 'taxi',
        cost_per_km: 200,
        duration_factor: 0.8,
        reliability_score: 0.95,
        carbon_footprint_score: 0.8,
        icon: '🚕',
        description: '便捷舒適，點對點服務'
      },
      {
        id: generateUUID(),
        trip_id: req.params.id,
        name: '自行車',
        type: 'bike',
        cost_per_km: 10,
        duration_factor: 1.5,
        reliability_score: 0.7,
        carbon_footprint_score: 0.05,
        icon: '🚲',
        description: '環保健康，適合觀光'
      }
    ];
    
    // Filter and return modes based on preferences
    let modes = existingModes.length > 0 ? existingModes : defaultModes;
    
    // Apply user preferences filtering
    if (preferences.preferred_modes && preferences.preferred_modes.length > 0) {
      modes = modes.filter((mode: any) => preferences.preferred_modes.includes(mode.type));
    }
    
    res.json({ transportation_modes: modes });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// POST /api/trips/:id/transportation-modes - Add custom transportation mode
app.post('/api/trips/:id/transportation-modes', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    const { name, type, cost_per_km = 0, duration_factor = 1.0, reliability_score = 1.0, carbon_footprint_score = 1.0, icon, description } = req.body;
    
    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }
    
    if (!name || !type) {
      return res.status(400).json({ error: 'Name and type are required' });
    }
    
    const modeId = generateUUID();
    const now = new Date().toISOString();
    
    db.prepare(`
      INSERT INTO transportation_modes (id, trip_id, name, type, cost_per_km, duration_factor, reliability_score, carbon_footprint_score, icon, description, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(modeId, req.params.id, name, type, cost_per_km, duration_factor, reliability_score, carbon_footprint_score, icon || '', description || '', now);
    
    const newMode = db.prepare('SELECT * FROM transportation_modes WHERE id = ?').get(modeId);
    res.status(201).json({ 
      message: 'Transportation mode added successfully',
      transportation_mode: newMode 
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// POST /api/trips/:id/route-optimization - Optimize route using TSP algorithm
app.post('/api/trips/:id/route-optimization', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    const { algorithm = 'nearest_neighbor', optimize_for = 'time', exclude_locked = true } = req.body;
    
    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }
    
    // Get destinations for this trip
    const destinations = db.prepare('SELECT * FROM destinations WHERE trip_id = ? ORDER BY visit_date').all(req.params.id);
    if (destinations.length < 2) {
      return res.status(400).json({ error: 'At least 2 destinations required for route optimization' });
    }
    
    // Filter out locked destinations if requested
    let filteredDestinations = destinations;
    if (exclude_locked) {
      filteredDestinations = destinations.filter((dest: any) => !dest.locked);
    }
    
    if (filteredDestinations.length < 2) {
      return res.status(400).json({ error: 'At least 2 unlocked destinations required for route optimization' });
    }
    
    // Get transportation modes
    const transportationModes = db.prepare('SELECT * FROM transportation_modes WHERE trip_id = ?').all(req.params.id);
    
    // Calculate distances between all pairs of destinations
    const distances = calculateDistances(filteredDestinations);
    
    // Apply TSP algorithm to find optimal order
    const optimizedOrder = applyTSPAlgorithm(filteredDestinations, distances, algorithm, optimize_for);
    
    // Calculate total metrics for the optimized route
    const totalMetrics = calculateRouteMetrics(optimizedOrder, distances, transportationModes);
    
    // Store the optimization result
    const optimizationId = generateUUID();
    const now = new Date().toISOString();
    
    db.prepare(`
      INSERT INTO route_optimizations (id, trip_id, name, algorithm, total_duration_minutes, total_distance_meters, total_cost, optimized_route_order, waypoints, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      optimizationId,
      req.params.id,
      `${algorithm} optimization`,
      algorithm,
      totalMetrics.totalDuration,
      totalMetrics.totalDistance,
      totalMetrics.totalCost,
      JSON.stringify(optimizedOrder.map(dest => dest.id)),
      JSON.stringify(optimizedOrder.map(dest => ({ lat: dest.latitude, lng: dest.longitude }))),
      now
    );
    
    // Get transportation segments for the optimized route
    const segments = generateTransportationSegments(optimizedOrder, distances, transportationModes);
    
    // Store segments in database
    for (const segment of segments) {
      const segmentId = generateUUID();
      db.prepare(`
        INSERT INTO transportation_segments (id, trip_id, from_destination_id, to_destination_id, transport_mode_id, duration_minutes, distance_meters, cost, instructions, departure_time, arrival_time, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).run(
        segmentId,
        req.params.id,
        segment.from_destination_id,
        segment.to_destination_id,
        segment.transport_mode_id,
        segment.duration_minutes,
        segment.distance_meters,
        segment.cost,
        JSON.stringify(segment.instructions || []),
        segment.departure_time,
        segment.arrival_time,
        now
      );
    }
    
    res.status(201).json({
      message: 'Route optimization completed successfully',
      route_optimization: {
        id: optimizationId,
        algorithm,
        optimize_for,
        total_duration_minutes: totalMetrics.totalDuration,
        total_distance_meters: totalMetrics.totalDistance,
        total_cost: totalMetrics.totalCost,
        optimized_route: optimizedOrder,
        segments,
        statistics: {
          destinations_count: optimizedOrder.length,
          segments_count: segments.length,
          average_speed_kmh: totalMetrics.totalDistance / (totalMetrics.totalDuration / 60),
          cost_per_km: totalMetrics.totalDistance > 0 ? totalMetrics.totalCost / (totalMetrics.totalDistance / 1000) : 0
        }
      }
    });
  } catch (error: any) {
    console.error('Route optimization error:', error);
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// Helper function to calculate distances between destinations
function calculateDistances(destinations: any[]) {
  const distances: any = {};
  
  for (let i = 0; i < destinations.length; i++) {
    for (let j = 0; j < destinations.length; j++) {
      if (i !== j) {
        const from = destinations[i];
        const to = destinations[j];
        
        // Simple Euclidean distance calculation (in real app, use actual routing API)
        const dx = (to.latitude || 0) - (from.latitude || 0);
        const dy = (to.longitude || 0) - (from.longitude || 0);
        const distance = Math.sqrt(dx * dx + dy * dy) * 1000; // Convert to meters
        
        distances[`${from.id}-${to.id}`] = {
          from_destination_id: from.id,
          to_destination_id: to.id,
          distance_meters: Math.round(distance),
          duration_minutes: Math.round(distance / 80) // Assuming average walking speed of 80m/min
        };
      }
    }
  }
  
  return distances;
}

// Helper function to apply TSP algorithm
function applyTSPAlgorithm(destinations: any[], distances: any, algorithm: string, optimize_for: string) {
  switch (algorithm) {
    case 'nearest_neighbor':
      return nearestNeighborTSP(destinations, distances, optimize_for);
    case 'genetic':
      return geneticAlgorithmTSP(destinations, distances, optimize_for);
    default:
      return nearestNeighborTSP(destinations, distances, optimize_for);
  }
}

// Nearest Neighbor TSP implementation
function nearestNeighborTSP(destinations: any[], distances: any, optimize_for: string) {
  const n = destinations.length;
  const visited = new Array(n).fill(false);
  const route = [];
  
  // Start from the first destination
  let current = 0;
  route.push(destinations[current]);
  visited[current] = true;
  
  // Visit all other destinations
  for (let i = 1; i < n; i++) {
    let nearest = -1;
    let minDistance = Infinity;
    
    // Find the nearest unvisited destination
    for (let j = 0; j < n; j++) {
      if (!visited[j]) {
        const distance = distances[`${destinations[current].id}-${destinations[j].id}`];
        if (distance && distance.distance_meters < minDistance) {
          minDistance = distance.distance_meters;
          nearest = j;
        }
      }
    }
    
    if (nearest !== -1) {
      current = nearest;
      route.push(destinations[current]);
      visited[current] = true;
    }
  }
  
  return route;
}

// Simple Genetic Algorithm for TSP
function geneticAlgorithmTSP(destinations: any[], distances: any, optimize_for: string) {
  const populationSize = 50;
  const generations = 100;
  const mutationRate = 0.1;
  
  // Initialize population with random routes
  const population = [];
  for (let i = 0; i < populationSize; i++) {
    const route = [...destinations];
    for (let j = route.length - 1; j > 0; j--) {
      const k = Math.floor(Math.random() * (j + 1));
      [route[j], route[k]] = [route[k], route[j]];
    }
    population.push(route);
  }
  
  // Evolve population
  for (let gen = 0; gen < generations; gen++) {
    // Calculate fitness for each individual
    const fitness = population.map((route: any[]) => calculateRouteFitness(route, distances, optimize_for));
    
    // Selection (tournament selection)
    const newPopulation = [];
    for (let i = 0; i < populationSize; i++) {
      const parent1 = tournamentSelection(population, fitness);
      const parent2 = tournamentSelection(population, fitness);
      
      // Crossover (ordered crossover)
      const child = orderedCrossover(parent1, parent2);
      
      // Mutation
      if (Math.random() < mutationRate) {
        mutate(child);
      }
      
      newPopulation.push(child);
    }
    
    population.splice(0, populationSize, ...newPopulation);
  }
  
  // Return the best route
  const finalFitness = population.map(route => calculateRouteFitness(route, distances, optimize_for));
  const bestIndex = finalFitness.indexOf(Math.min(...finalFitness));
  return population[bestIndex];
}

// Helper function for tournament selection
function tournamentSelection(population: any[], fitness: number[], tournamentSize = 3) {
  const tournament = [];
  for (let i = 0; i < tournamentSize; i++) {
    const index = Math.floor(Math.random() * population.length);
    tournament.push({ individual: population[index], fitness: fitness[index] });
  }
  
  tournament.sort((a: any, b: any) => a.fitness - b.fitness);
  return tournament[0].individual;
}

// Ordered crossover for TSP
function orderedCrossover(parent1: any[], parent2: any[]) {
  const start = Math.floor(Math.random() * parent1.length);
  const end = Math.floor(Math.random() * (parent1.length - start)) + start;
  
  const child = new Array(parent1.length).fill(null);
  
  // Copy segment from parent1
  for (let i = start; i < end; i++) {
    child[i] = parent1[i];
  }
  
  // Fill remaining positions from parent2
  let childIndex = 0;
  for (let i = 0; i < parent2.length; i++) {
    if (!child.includes(parent2[i])) {
      while (child[childIndex] !== null) childIndex++;
      child[childIndex] = parent2[i];
    }
  }
  
  return child;
}

// Mutation function for genetic algorithm
function mutate(route: any[]) {
  const i = Math.floor(Math.random() * route.length);
  const j = Math.floor(Math.random() * route.length);
  [route[i], route[j]] = [route[j], route[i]];
}

// Calculate route fitness (lower is better)
function calculateRouteFitness(route: any[], distances: any, optimize_for: string) {
  let totalDistance = 0;
  let totalDuration = 0;
  
  for (let i = 0; i < route.length - 1; i++) {
    const segment = distances[`${route[i].id}-${route[i + 1].id}`];
    if (segment) {
      totalDistance += segment.distance_meters;
      totalDuration += segment.duration_minutes;
    }
  }
  
  switch (optimize_for) {
    case 'time':
      return totalDuration;
    case 'distance':
      return totalDistance;
    case 'cost':
      return totalDistance * 0.03; // Simple cost estimation
    default:
      return totalDuration;
  }
}

// Calculate route metrics
function calculateRouteMetrics(route: any[], distances: any, transportationModes: any[]) {
  let totalDistance = 0;
  let totalDuration = 0;
  let totalCost = 0;
  
  for (let i = 0; i < (route as any[]).length - 1; i++) {
    const segment = distances[`${(route as any[])[i].id}-${(route as any[])[i + 1].id}`];
    if (segment) {
      totalDistance += segment.distance_meters;
      totalDuration += segment.duration_minutes;
      totalCost += segment.distance_meters * 0.03; // Simple cost calculation
    }
  }
  
  return {
    totalDistance,
    totalDuration,
    totalCost
  };
}

// Generate transportation segments for optimized route
function generateTransportationSegments(route: any[], distances: any[], transportationModes: any[]) {
  const segments = [];
  
  for (let i = 0; i < (route as any[]).length - 1; i++) {
    const from = (route as any[])[i];
    const to = (route as any[])[i + 1];
    const segment = (distances as any)[`${from.id}-${to.id}`];
    
    if (segment) {
      // Select best transportation mode for this segment
      const bestMode = selectBestTransportMode(segment as any, transportationModes);
      
      segments.push({
        from_destination_id: from.id,
        to_destination_id: to.id,
        transport_mode_id: bestMode.id,
        duration_minutes: segment.duration_minutes,
        distance_meters: segment.distance_meters,
        cost: segment.distance_meters * bestMode.cost_per_km / 1000,
        instructions: generateInstructions(from, to, bestMode),
        departure_time: null, // Would be calculated based on timeline
        arrival_time: null
      });
    }
  }
  
  return segments;
}

// Select best transportation mode for a segment
function selectBestTransportMode(segment: any, transportationModes: any[]) {
  // For now, prefer walking for short distances, public for medium, taxi for long
  if (segment.distance_meters < 1000) {
    return transportationModes.find(mode => mode.type === 'walking') || transportationModes[0];
  } else if (segment.distance_meters < 5000) {
    return transportationModes.find(mode => mode.type === 'public') || transportationModes[1];
  } else {
    return transportationModes.find(mode => mode.type === 'taxi') || transportationModes[2];
  }
}

// Generate navigation instructions
function generateInstructions(from: any, to: any, mode: any) {
  const instructions = [];
  
  instructions.push({
    step: 1,
    instruction: `從${from.name}出發`,
    distance: 0,
    duration: 0
  });
  
  if (mode.type === 'walking') {
    instructions.push({
      step: 2,
      instruction: `步行前往${to.name}`,
      distance: `${Math.round(to.distance_meters / 1000)}公里`,
      duration: `${Math.round(to.duration_minutes)}分鐘`
    });
  } else if (mode.type === 'public') {
    instructions.push({
      step: 2,
      instruction: `搭乘大眾運輸前往${to.name}`,
      distance: `${Math.round(to.distance_meters / 1000)}公里`,
      duration: `${Math.round(to.duration_minutes)}分鐘`
    });
  } else if (mode.type === 'taxi') {
    instructions.push({
      step: 2,
      instruction: `搭乘計程車前往${to.name}`,
      distance: `${Math.round(to.distance_meters / 1000)}公里`,
      duration: `${Math.round(to.duration_minutes)}分鐘`
    });
  }
  
  instructions.push({
    step: 3,
    instruction: `抵達${to.name}`,
    distance: 0,
    duration: 0
  });
  
  return instructions;
}

// Module 4: POI & Content APIs

// Custom Map Pins (F31) - GET /api/trips/:id/custom-pins
app.get('/api/trips/:id/custom-pins', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    
    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    const pins = db.prepare('SELECT * FROM custom_pins WHERE trip_id = ? ORDER BY created_at DESC').all(req.params.id);
    res.json({ custom_pins: pins });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// Custom Map Pins (F31) - POST /api/trips/:id/custom-pins
app.post('/api/trips/:id/custom-pins', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    const { name, type, latitude, longitude, address, description, icon, color, size } = req.body;

    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    if (!name || !type || !latitude || !longitude) {
      return res.status(400).json({ error: 'Name, type, latitude, and longitude are required' });
    }

    const pinId = generateUUID();
    const now = new Date().toISOString();

    db.prepare(`
      INSERT INTO custom_pins (id, trip_id, name, type, latitude, longitude, address, description, icon, color, size, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      pinId,
      req.params.id,
      name,
      type,
      latitude,
      longitude,
      address || null,
      description || null,
      icon || '📍',
      color || '#FF5733',
      size || 20,
      now,
      now
    );

    const pin = db.prepare('SELECT * FROM custom_pins WHERE id = ?').get(pinId);
    res.status(201).json({
      message: 'Custom pin created successfully',
      custom_pin: pin
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// Custom Map Pins (F31) - PUT /api/trips/:id/custom-pins/:pinId
app.put('/api/trips/:id/custom-pins/:pinId', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    const { name, type, latitude, longitude, address, description, icon, color, size, is_visible } = req.body;

    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    const existing = db.prepare('SELECT * FROM custom_pins WHERE id = ? AND trip_id = ?').get(req.params.pinId, req.params.id);
    if (!existing) {
      return res.status(404).json({ error: 'Custom pin not found' });
    }

    const now = new Date().toISOString();
    db.prepare(`
      UPDATE custom_pins SET 
        name = COALESCE(?, name),
        type = COALESCE(?, type),
        latitude = COALESCE(?, latitude),
        longitude = COALESCE(?, longitude),
        address = COALESCE(?, address),
        description = COALESCE(?, description),
        icon = COALESCE(?, icon),
        color = COALESCE(?, color),
        size = COALESCE(?, size),
        is_visible = COALESCE(?, is_visible),
        updated_at = ?
      WHERE id = ? AND trip_id = ?
    `).run(
      name,
      type,
      latitude,
      longitude,
      address,
      description,
      icon,
      color,
      size,
      is_visible,
      now,
      req.params.pinId,
      req.params.id
    );

    const updatedPin = db.prepare('SELECT * FROM custom_pins WHERE id = ?').get(req.params.pinId);
    res.json({
      message: 'Custom pin updated successfully',
      custom_pin: updatedPin
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// Custom Map Pins (F31) - DELETE /api/trips/:id/custom-pins/:pinId
app.delete('/api/trips/:id/custom-pins/:pinId', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();

    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    const existing = db.prepare('SELECT * FROM custom_pins WHERE id = ? AND trip_id = ?').get(req.params.pinId, req.params.id);
    if (!existing) {
      return res.status(404).json({ error: 'Custom pin not found' });
    }

    // Delete related tag assignments, reviews, and names
    db.prepare('DELETE FROM poi_tag_assignments WHERE custom_pin_id = ?').run(req.params.pinId);
    db.prepare('DELETE FROM poi_reviews WHERE custom_pin_id = ?').run(req.params.pinId);
    db.prepare('DELETE FROM poi_names WHERE custom_pin_id = ?').run(req.params.pinId);
    db.prepare('DELETE FROM seasonal_alerts WHERE custom_pin_id = ?').run(req.params.pinId);
    
    db.prepare('DELETE FROM custom_pins WHERE id = ?').run(req.params.pinId);

    res.json({ message: 'Custom pin deleted successfully' });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// Multi-dimensional Tags (F33) - GET /api/poi-tags
app.get('/api/poi-tags', (req, res) => {
  try {
    const db = getDatabase();
    const tags = db.prepare('SELECT * FROM poi_tags ORDER BY category, name').all();
    res.json({ poi_tags: tags });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// Multi-dimensional Tags (F33) - GET /api/trips/:id/poi-tags
app.get('/api/trips/:id/poi-tags', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    
    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    const tags = db.prepare(`
      SELECT pt.*, pta.custom_pin_id, pta.destination_id
      FROM poi_tags pt
      LEFT JOIN poi_tag_assignments pta ON pt.id = pta.tag_id AND pta.trip_id = ?
      WHERE pta.id IS NOT NULL OR pt.category IN ('cuisine', 'price_range', 'facility')
      ORDER BY pt.category, pt.name
    `).all(req.params.id);

    res.json({ poi_tags: tags });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// Multi-dimensional Tags (F33) - POST /api/trips/:id/poi-tags/assign
app.post('/api/trips/:id/poi-tags/assign', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    const { tag_id, custom_pin_id, destination_id } = req.body;

    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    if (!tag_id) {
      return res.status(400).json({ error: 'Tag ID is required' });
    }

    const tag = db.prepare('SELECT * FROM poi_tags WHERE id = ?').get(tag_id);
    if (!tag) {
      return res.status(404).json({ error: 'Tag not found' });
    }

    // Check if assignment already exists
    const existing = db.prepare('SELECT * FROM poi_tag_assignments WHERE trip_id = ? AND tag_id = ? AND custom_pin_id = ? AND destination_id = ?').get(
      req.params.id, tag_id, custom_pin_id || null, destination_id || null
    );

    if (existing) {
      return res.status(409).json({ error: 'Tag assignment already exists' });
    }

    const assignmentId = generateUUID();
    const now = new Date().toISOString();

    db.prepare(`
      INSERT INTO poi_tag_assignments (id, trip_id, tag_id, custom_pin_id, destination_id, created_at)
      VALUES (?, ?, ?, ?, ?, ?)
    `).run(assignmentId, req.params.id, tag_id, custom_pin_id, destination_id, now);

    const tagData = tag as any;
    const assignment = db.prepare('SELECT * FROM poi_tag_assignments WHERE id = ?').get(assignmentId) as any;
    res.status(201).json({
      message: 'Tag assigned successfully',
      tag_assignment: {
        id: assignment.id,
        tag_id: assignment.tag_id,
        tag_name: tagData.name,
        tag_category: tagData.category,
        custom_pin_id: assignment.custom_pin_id,
        destination_id: assignment.destination_id,
        created_at: assignment.created_at
      }
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// Multi-dimensional Tags (F33) - DELETE /api/trips/:id/poi-tags/assignment/:assignmentId
app.delete('/api/trips/:id/poi-tags/assignment/:assignmentId', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();

    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    const assignment = db.prepare('SELECT * FROM poi_tag_assignments WHERE id = ? AND trip_id = ?').get(req.params.assignmentId, req.params.id);
    if (!assignment) {
      return res.status(404).json({ error: 'Tag assignment not found' });
    }

    db.prepare('DELETE FROM poi_tag_assignments WHERE id = ?').run(req.params.assignmentId);

    res.json({ message: 'Tag assignment removed successfully' });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// POI Reviews and Notes (F35) - GET /api/trips/:id/poi-reviews
app.get('/api/trips/:id/poi-reviews', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    
    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    const reviews = db.prepare(`
      SELECT pr.*, u.name as user_name, cp.name as pin_name, cp.type as pin_type, d.name as dest_name
      FROM poi_reviews pr
      LEFT JOIN users u ON pr.user_id = u.id
      LEFT JOIN custom_pins cp ON pr.custom_pin_id = cp.id
      LEFT JOIN destinations d ON pr.destination_id = d.id
      WHERE pr.trip_id = ?
      ORDER BY pr.created_at DESC
    `).all(req.params.id);

    res.json({ poi_reviews: reviews });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// POI Reviews and Notes (F35) - POST /api/trips/:id/poi-reviews
app.post('/api/trips/:id/poi-reviews', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    const { custom_pin_id, destination_id, rating, title, content, visit_date, photos } = req.body;

    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    if (!rating || rating < 1 || rating > 5) {
      return res.status(400).json({ error: 'Rating must be between 1 and 5' });
    }

    const reviewId = generateUUID();
    const now = new Date().toISOString();

    db.prepare(`
      INSERT INTO poi_reviews (id, trip_id, custom_pin_id, destination_id, user_id, rating, title, content, visit_date, photos, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      reviewId,
      req.params.id,
      custom_pin_id,
      destination_id,
      user.id,
      rating,
      title || null,
      content || null,
      visit_date || null,
      photos ? JSON.stringify(photos) : null,
      now,
      now
    );

    const review = db.prepare('SELECT * FROM poi_reviews WHERE id = ?').get(reviewId) as any;
    res.status(201).json({
      message: 'POI review created successfully',
      poi_review: review
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// Bilingual POI Names (F38) - GET /api/trips/:id/poi-names
app.get('/api/trips/:id/poi-names', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    
    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    const names = db.prepare(`
      SELECT pn.*, cp.name as original_name, cp.type as pin_type, d.name as dest_name
      FROM poi_names pn
      LEFT JOIN custom_pins cp ON pn.custom_pin_id = cp.id
      LEFT JOIN destinations d ON pn.destination_id = d.id
      WHERE cp.trip_id = ? OR d.trip_id = ?
      ORDER BY pn.language, pn.local_name
    `).all(req.params.id, req.params.id);

    res.json({ poi_names: names });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// Seasonal Alerts (F39) - GET /api/trips/:id/seasonal-alerts
app.get('/api/trips/:id/seasonal-alerts', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    
    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    const alerts = db.prepare(`
      SELECT sa.*, cp.name as pin_name, cp.type as pin_type, d.name as dest_name
      FROM seasonal_alerts sa
      LEFT JOIN custom_pins cp ON sa.custom_pin_id = cp.id
      LEFT JOIN destinations d ON sa.destination_id = d.id
      WHERE sa.trip_id = ? AND sa.is_active = TRUE
      ORDER BY sa.season, sa.start_date
    `).all(req.params.id);

    res.json({ seasonal_alerts: alerts });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// Error handling middleware
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

// Module 3: Japanese Transport Ticket Calculator APIs (F23)

// GET /api/trips/:id/japan-tickets - Get available Japanese transport tickets
app.get('/api/trips/:id/japan-tickets', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    
    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }
    
    const tickets = db.prepare('SELECT * FROM japan_transport_tickets WHERE trip_id = ? AND is_active = TRUE').all(req.params.id);
    
    // Format response
    const formattedTickets = tickets.map((ticket: any) => ({
      ...ticket,
      coverage_areas: JSON.parse(ticket.coverage_areas || '[]'),
      conditions: JSON.parse(ticket.conditions || '{}')
    }));
    
    res.json({ japan_transport_tickets: formattedTickets });
  } catch (error: any) {
    console.error('Get Japan tickets error:', error);
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// POST /api/trips/:id/japan-tickets/calculate - Calculate ticket cost and recommendations
app.post('/api/trips/:id/japan-tickets/calculate', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    const { planned_trips, ticket_id } = req.body;
    
    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }
    
    // Get the ticket
    const ticket = db.prepare('SELECT * FROM japan_transport_tickets WHERE id = ? AND trip_id = ?').get(ticket_id, req.params.id);
    if (!ticket) {
      return res.status(404).json({ error: 'Ticket not found' });
    }
    
    // Parse ticket details
    const ticketDetails: any = {
      ...ticket,
      coverage_areas: JSON.parse((ticket as any).coverage_areas || '[]'),
      conditions: JSON.parse((ticket as any).conditions || '{}')
    };
    
    // Calculate costs based on planned trips
    const calculationResults = calculateJapanTicketCost(ticketDetails, planned_trips);
    
    // Save calculation record
    const calculationId = generateUUID();
    db.prepare(`
      INSERT INTO japan_ticket_calculations 
      (id, trip_id, ticket_id, planned_trips, calculated_cost_yen, alternative_ticket_suggestions, savings_yen, breakeven_analysis, recommendation)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      calculationId,
      req.params.id,
      ticket_id,
      JSON.stringify(planned_trips),
      calculationResults.calculated_cost_yen,
      JSON.stringify(calculationResults.alternative_ticket_suggestions),
      calculationResults.savings_yen,
      JSON.stringify(calculationResults.breakeven_analysis),
      calculationResults.recommendation
    );
    
    res.json({
      message: 'Ticket calculation completed successfully',
      calculation_id: calculationId,
      ...calculationResults
    });
  } catch (error: any) {
    console.error('Japan ticket calculation error:', error);
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// Function to calculate Japan ticket cost and recommendations
function calculateJapanTicketCost(ticket: any, planned_trips: any[]) {
  // Mock calculation logic for Japanese transport tickets
  const individual_trip_costs = planned_trips.map((trip: any) => {
    // Base cost calculation (simplified)
    let base_cost = 0;
    
    switch (trip.transport_mode) {
      case 'shinkansen':
        base_cost = 14000; // Average Shinkansen cost
        break;
      case 'train':
        base_cost = 500; // Average train cost
        break;
      case 'subway':
        base_cost = 200; // Average subway cost
        break;
      case 'bus':
        base_cost = 300; // Average bus cost
        break;
      default:
        base_cost = 400; // Default cost
    }
    
    // Apply distance multiplier
    const distance_multiplier = trip.distance_km > 0 ? Math.max(1, trip.distance_km / 10) : 1;
    
    return Math.round(base_cost * distance_multiplier);
  });
  
  const total_individual_cost = individual_trip_costs.reduce((sum: number, cost: number) => sum + cost, 0);
  const ticket_cost = ticket.price_yen;
  
  const savings_yen = Math.max(0, total_individual_cost - ticket_cost);
  const breakeven_analysis = {
    individual_total_cost: total_individual_cost,
    ticket_cost,
    savings_yen,
    breakeven_point: total_individual_cost - ticket_cost >= 0,
    cost_ratio: ticket_cost / total_individual_cost,
    payback_trips: Math.ceil(ticket_cost / (total_individual_cost / planned_trips.length))
  };
  
  // Generate alternative suggestions
  const alternative_ticket_suggestions = [
    {
      ticket_name: 'IC Card (Suica/Pasmo)',
      estimated_savings: Math.round(total_individual_cost * 0.1), // 10% savings
      description: '適合短距離頻繁搭乘'
    },
    {
      ticket_name: 'Regional Pass',
      estimated_savings: Math.round(total_individual_cost * 0.15), // 15% savings
      description: '適合特定地區長期旅行'
    }
  ];
  
  let recommendation = '';
  if (breakeven_analysis.breakeven_point && savings_yen > 1000) {
    recommendation = `推薦使用${ticket.ticket_name}，可節省${savings_yen}日圓`;
  } else if (breakeven_analysis.breakeven_point) {
    recommendation = `${ticket.ticket_name}剛好達到成本效益平衡`;
  } else {
    recommendation = `建議考慮其他交通方案，${ticket.ticket_name}可能不划算`;
  }
  
  return {
    calculated_cost_yen: ticket_cost,
    total_individual_cost,
    alternative_ticket_suggestions,
    savings_yen,
    breakeven_analysis,
    recommendation
  };
}

// POST /api/trips/:id/japan-tickets/:ticket_id/record-usage - Record ticket usage
app.post('/api/trips/:id/japan-tickets/:ticket_id/record-usage', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    const { from_location, to_location, transport_mode, distance_km, cost_yen } = req.body;
    
    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }
    
    const ticket = db.prepare('SELECT * FROM japan_transport_tickets WHERE id = ? AND trip_id = ?').get(req.params.ticket_id, req.params.id);
    if (!ticket) {
      return res.status(404).json({ error: 'Ticket not found' });
    }
    
    const usageId = generateUUID();
    db.prepare(`
      INSERT INTO japan_ticket_usage_records 
      (id, ticket_id, trip_id, used_date, from_location, to_location, transport_mode, distance_km, cost_yen, is_valid)
      VALUES (?, ?, ?, datetime('now'), ?, ?, ?, ?, ?, ?)
    `).run(
      usageId,
      req.params.ticket_id,
      req.params.id,
      from_location,
      to_location,
      transport_mode,
      distance_km || 0,
      cost_yen || 0,
      true
    );
    
    res.status(201).json({
      message: 'Ticket usage recorded successfully',
      usage_record: { id: usageId, ...req.body }
    });
  } catch (error: any) {
    console.error('Record ticket usage error:', error);
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// GET /api/trips/:id/japan-tickets/:ticket_id/usage-history - Get ticket usage history
app.get('/api/trips/:id/japan-tickets/:ticket_id/usage-history', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    
    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }
    
    const usageRecords = db.prepare(`
      SELECT * FROM japan_ticket_usage_records 
      WHERE ticket_id = ? AND trip_id = ? 
      ORDER BY used_date DESC
    `).all(req.params.ticket_id, req.params.id);
    
    const formattedRecords = usageRecords.map((record: any) => ({
      ...record,
      used_date: new Date(record.used_date).toISOString()
    }));
    
    res.json({ usage_history: formattedRecords });
  } catch (error: any) {
    console.error('Get ticket usage history error:', error);
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// Module 4: Additional POI & Content APIs

// F32 - Crowd prediction heatmap - GET /api/trips/:id/crowd-prediction
app.get('/api/trips/:id/crowd-prediction', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    
    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    // Get all custom pins and destinations for crowd prediction
    const pins = db.prepare('SELECT * FROM custom_pins WHERE trip_id = ?').all(req.params.id);
    const destinations = db.prepare('SELECT * FROM destinations WHERE trip_id = ?').all(req.params.id);
    
    // Simulate crowd prediction data based on time of day and day of week
    const now = new Date();
    const hour = now.getHours();
    const dayOfWeek = now.getDay();
    
    const crowdData: any[] = [];
    
    // Process pins
    pins.forEach((pin: any) => {
      const crowdLevel = Math.floor(Math.random() * 100); // Simulated crowd level 0-100
      const crowdStatus = crowdLevel < 30 ? 'low' : crowdLevel < 70 ? 'medium' : 'high';
      
      crowdData.push({
        id: pin.id,
        name: pin.name,
        type: pin.type,
        latitude: pin.latitude,
        longitude: pin.longitude,
        crowd_level: crowdLevel,
        crowd_status: crowdStatus,
        estimated_wait_time: Math.floor(crowdLevel / 20), // Simulated wait time in minutes
        time_factor: hour >= 10 && hour <= 18 ? 1.2 : 0.8, // Higher crowds during day time
        day_factor: dayOfWeek === 0 || dayOfWeek === 6 ? 1.3 : 1.0, // Higher crowds on weekends
        last_updated: now.toISOString()
      });
    });
    
    // Process destinations
    destinations.forEach((dest: any) => {
      const crowdLevel = Math.floor(Math.random() * 100);
      const crowdStatus = crowdLevel < 30 ? 'low' : crowdLevel < 70 ? 'medium' : 'high';
      
      crowdData.push({
        id: dest.id,
        name: dest.name,
        type: dest.type,
        latitude: dest.latitude,
        longitude: dest.longitude,
        crowd_level: crowdLevel,
        crowd_status: crowdStatus,
        estimated_wait_time: Math.floor(crowdLevel / 15),
        time_factor: hour >= 9 && hour <= 17 ? 1.3 : 0.9,
        day_factor: dayOfWeek === 0 || dayOfWeek === 6 ? 1.4 : 1.0,
        last_updated: now.toISOString()
      });
    });

    res.json({ 
      crowd_prediction: crowdData,
      metadata: {
        generated_at: now.toISOString(),
        data_points: crowdData.length,
        peak_hours: [11, 12, 13, 14, 15],
        peak_days: [0, 6] // Sunday, Saturday
      }
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// F34 - POI surrounding facilities search - GET /api/trips/:id/poi-facilities
app.get('/api/trips/:id/poi-facilities', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    
    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    // Get custom pins and destinations to search around
    const customPins = db.prepare('SELECT * FROM custom_pins WHERE trip_id = ?').all(req.params.id);
    const destinations = db.prepare('SELECT * FROM destinations WHERE trip_id = ?').all(req.params.id);
    
    // Simulated nearby facilities database
    const facilityCategories = [
      { type: 'restroom', icon: '🚻', name: '洗手間', priority: 1 },
      { type: 'atm', icon: '🏦', name: 'ATM', priority: 2 },
      { type: 'pharmacy', icon: '💊', name: '藥局', priority: 1 },
      { type: 'convenience', icon: '🏪', name: '便利商店', priority: 3 },
      { type: 'restaurant', icon: '🍽️', name: '餐廳', priority: 2 },
      { type: 'parking', icon: '🅿️', name: '停車場', priority: 3 },
      { type: 'hospital', icon: '🏥', name: '醫院', priority: 1 },
      { type: 'police', icon: '👮', name: '警察局', priority: 1 }
    ];

    const allFacilities: any[] = [];
    
    // Generate facilities around each POI
    [...customPins, ...destinations].forEach((poi: any) => {
      facilityCategories.forEach(category => {
        // Generate facilities within 500-2000m radius
        const distance = Math.floor(Math.random() * 1500) + 500;
        const duration = Math.floor(distance / 80); // Walking speed ~80m/min
        
        allFacilities.push({
          id: generateUUID(),
          poi_id: poi.id,
          poi_name: poi.name,
          poi_type: poi.type,
          facility_type: category.type,
          facility_name: category.name,
          icon: category.icon,
          distance: distance,
          duration: duration,
          walking_time: `${duration}分鐘`,
          address: `附近${category.name} - 模擬地址`,
          rating: (Math.random() * 2 + 3).toFixed(1), // 3.0-5.0 rating
          is_available: Math.random() > 0.1, // 90% available
          operating_hours: category.type === 'convenience' ? '24小時' : '08:00-22:00',
          created_at: new Date().toISOString()
        });
      });
    });

    // Sort by distance and group by facility type
    const sortedFacilities = allFacilities.sort((a, b) => a.distance - b.distance);
    const groupedFacilities = facilityCategories.map(category => ({
      category: category,
      facilities: sortedFacilities.filter(f => f.facility_type === category.type).slice(0, 5) // Top 5 per category
    }));

    res.json({ 
      poi_facilities: groupedFacilities,
      total_facilities: sortedFacilities.length,
      search_radius: 2000
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// F36 - Nearby search for restaurants/amenities - GET /api/trips/:id/nearby-search
app.get('/api/trips/:id/nearby-search', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    
    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    const { 
      lat, 
      lng, 
      radius = 1000, 
      type = 'all', 
      price_range = null,
      cuisine_type = null 
    } = req.query;

    if (!lat || !lng) {
      return res.status(400).json({ error: 'Latitude and longitude are required' });
    }

    // Get current trip locations
    const customPins = db.prepare('SELECT * FROM custom_pins WHERE trip_id = ?').all(req.params.id);
    const destinations = db.prepare('SELECT * FROM destinations WHERE trip_id = ?').all(req.params.id);

    // Simulated restaurant and amenity database
    const mockData = [
      // Restaurants
      { name: '拉麵一福', type: 'restaurant', cuisine: 'japanese', price_range: 2, rating: 4.5, distance: 150 },
      { name: '四川飯店', type: 'restaurant', cuisine: 'chinese', price_range: 1, rating: 4.2, distance: 300 },
      { name: '韓式烤肉', type: 'restaurant', cuisine: 'korean', price_range: 3, rating: 4.7, distance: 450 },
      { name: '咖啡廳', type: 'cafe', cuisine: 'cafe', price_range: 2, rating: 4.3, distance: 200 },
      { name: '精緻餐廳', type: 'restaurant', cuisine: 'western', price_range: 4, rating: 4.8, distance: 600 },
      
      // Amenities
      { name: '7-Eleven', type: 'convenience', price_range: 0, rating: 4.0, distance: 180 },
      { name: '藥局', type: 'pharmacy', price_range: 0, rating: 4.1, distance: 350 },
      { name: 'ATM', type: 'atm', price_range: 0, rating: 5.0, distance: 120 },
      { name: '停車場', type: 'parking', price_range: 1, rating: 3.8, distance: 400 },
      { name: '觀景台', type: 'attraction', price_range: 0, rating: 4.6, distance: 800 },
      
      // More facilities
      { name: '警察局', type: 'police', price_range: 0, rating: 5.0, distance: 500 },
      { name: '醫院', type: 'hospital', price_range: 0, rating: 4.4, distance: 700 },
      { name: '書店', type: 'shopping', price_range: 2, rating: 4.2, distance: 550 },
      { name: '健身房', type: 'fitness', price_range: 4, rating: 4.5, distance: 900 },
      { name: '加油站', type: 'gas_station', price_range: 2, rating: 3.9, distance: 1100 }
    ];

    // Filter and sort results
    let filteredResults = mockData.filter(item => {
      // Distance filter
      const distance = parseFloat(item.distance.toString());
      if (distance > parseFloat(radius.toString())) return false;
      
      // Type filter
      if (type !== 'all' && item.type !== type) return false;
      
      // Price range filter
      if (price_range && item.price_range !== parseInt(price_range.toString())) return false;
      
      // Cuisine filter
      if (cuisine_type && item.cuisine !== cuisine_type) return false;
      
      return true;
    });

    // Sort by distance and rating
    filteredResults.sort((a, b) => {
      if (a.distance !== b.distance) {
        return a.distance - b.distance;
      }
      return parseFloat(b.rating.toString()) - parseFloat(a.rating.toString());
    });

    // Group by type
    const groupedResults = {
      restaurants: filteredResults.filter(item => item.type === 'restaurant'),
      cafes: filteredResults.filter(item => item.type === 'cafe'),
      convenience: filteredResults.filter(item => item.type === 'convenience'),
      amenities: filteredResults.filter(item => ['pharmacy', 'atm', 'parking', 'police', 'hospital'].includes(item.type)),
      attractions: filteredResults.filter(item => item.type === 'attraction'),
      services: filteredResults.filter(item => ['shopping', 'fitness', 'gas_station'].includes(item.type))
    };

    res.json({ 
      nearby_results: groupedResults,
      search_metadata: {
        center_lat: parseFloat(lat.toString()),
        center_lng: parseFloat(lng.toString()),
        search_radius_meters: parseInt(radius.toString()),
        total_results: filteredResults.length,
        search_filters: {
          type: type,
          price_range: price_range,
          cuisine_type: cuisine_type
        }
      }
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// F37 - Real-time experience booking API - POST /api/trips/:id/experience-bookings
app.post('/api/trips/:id/experience-bookings', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    
    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    const { 
      experience_id, 
      experience_name, 
      experience_type, 
      provider_name, 
      date, 
      start_time, 
      end_time, 
      participants, 
      price_per_person, 
      total_price, 
      special_requirements,
      booking_reference 
    } = req.body;

    if (!experience_id || !experience_name || !date || !start_time) {
      return res.status(400).json({ 
        error: 'Experience ID, name, date, and start time are required' 
      });
    }

    // Generate booking reference if not provided
    const finalBookingRef = booking_reference || `ZV-${generateUUID().substring(0, 8).toUpperCase()}`;
    
    // Check for availability (simulated)
    const existingBooking = db.prepare(`
      SELECT COUNT(*) as count FROM experience_bookings 
      WHERE experience_id = ? AND date = ? AND ((start_time <= ? AND end_time > ?) OR (start_time < ? AND end_time >= ?))
    `).get(experience_id, date, start_time, start_time, end_time, end_time);
    
    if ((existingBooking as any).count > 0) {
      return res.status(409).json({ 
        error: 'This time slot is already booked. Please choose a different time.',
        available_slots: [
          { date: date, start_time: '09:00', end_time: '11:00' },
          { date: date, start_time: '14:00', end_time: '16:00' },
          { date: date, start_time: '17:00', end_time: '19:00' }
        ]
      });
    }

    // Create booking
    const bookingId = generateUUID();
    const now = new Date().toISOString();

    const stmt = db.prepare(`
      INSERT INTO experience_bookings (
        id, trip_id, user_id, experience_id, experience_name, experience_type, 
        provider_name, date, start_time, end_time, participants, price_per_person, 
        total_price, special_requirements, booking_reference, status, created_at, updated_at
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'confirmed', ?, ?)
    `);

    stmt.run(
      bookingId,
      req.params.id,
      user.id,
      experience_id,
      experience_name,
      experience_type,
      provider_name,
      date,
      start_time,
      end_time,
      participants || 1,
      price_per_person,
      total_price,
      special_requirements ? JSON.stringify(special_requirements) : null,
      finalBookingRef,
      now,
      now
    );

    // Get created booking
    const booking = db.prepare(`
      SELECT eb.*, u.name as user_name
      FROM experience_bookings eb
      LEFT JOIN users u ON eb.user_id = u.id
      WHERE eb.id = ?
    `).get(bookingId) as any;

    // Send confirmation (simulated)
    const confirmation = {
      booking_id: bookingId,
      booking_reference: finalBookingRef,
      experience_name: experience_name,
      date: date,
      time: `${start_time} - ${end_time}`,
      participants: participants || 1,
      total_price: total_price,
      status: 'confirmed',
      confirmation_code: generateUUID().substring(0, 6).toUpperCase(),
      cancellation_policy: 'Free cancellation up to 24 hours before the experience',
      contact_info: {
        provider_email: 'support@zenvoyage.app',
        provider_phone: '+886-912-345-678'
      },
      next_steps: [
        'Check your email for detailed confirmation',
        'Prepare identification for check-in',
        'Arrive 15 minutes early for check-in',
        'Contact support with any questions'
      ]
    };

    res.status(201).json({
      message: 'Experience booking confirmed successfully',
      booking: booking,
      confirmation: confirmation
    });

  } catch (error: any) {
    console.error('Experience booking error:', error);
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// F37 - Get experience bookings - GET /api/trips/:id/experience-bookings
app.get('/api/trips/:id/experience-bookings', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    
    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    const bookings = db.prepare(`
      SELECT eb.*, u.name as user_name
      FROM experience_bookings eb
      LEFT JOIN users u ON eb.user_id = u.id
      WHERE eb.trip_id = ?
      ORDER BY eb.date DESC, eb.start_time DESC
    `).all(req.params.id);

    res.json({ experience_bookings: bookings });
  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// F37 - Cancel experience booking - DELETE /api/trips/:id/experience-bookings/:bookingId
app.delete('/api/trips/:id/experience-bookings/:bookingId', (req, res) => {
  try {
    const user = getCurrentUser(req) as any;
    const db = getDatabase();
    
    const trip = db.prepare('SELECT * FROM trips WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }

    const booking = db.prepare(`
      SELECT * FROM experience_bookings 
      WHERE id = ? AND trip_id = ? AND user_id = ?
    `).get(req.params.bookingId, req.params.id, user.id);
    
    if (!booking) {
      return res.status(404).json({ error: 'Booking not found' });
    }

    // Check cancellation policy (24 hours before)
    const bookingDate = new Date((booking as any).date + 'T' + (booking as any).start_time);
    const now = new Date();
    const timeDiff = bookingDate.getTime() - now.getTime();
    const hoursDiff = timeDiff / (1000 * 3600);

    if (hoursDiff < 24) {
      return res.status(400).json({ 
        error: 'Cannot cancel within 24 hours of the experience',
        cancellation_deadline: new Date(now.getTime() + 24 * 60 * 60 * 1000).toISOString()
      });
    }

    // Cancel booking
    db.prepare('DELETE FROM experience_bookings WHERE id = ?').run(req.params.bookingId);

    res.json({ 
      message: 'Experience booking cancelled successfully',
      cancelled_booking: booking,
      refund_info: {
        refund_amount: (booking as any).total_price,
        refund_method: 'Original payment method',
        processing_time: '5-7 business days'
      }
    });

  } catch (error: any) {
    res.status(500).json({ error: error.message || 'Internal server error' });
  }
});

// Serve Flutter Web static files only for non-API requests
const flutterBuildPath = path.join(__dirname, '../../app/build/web');
if (fs.existsSync(flutterBuildPath)) {
  // Serve static files for non-API requests
  app.use(express.static(flutterBuildPath, { 
    maxAge: '1h',
    index: false // Don't serve index.html automatically
  }));
  
  // Fallback to Flutter index.html for non-API requests
  app.get('*', (req, res) => {
    // Only serve index.html for non-API requests
    if (!req.path.startsWith('/api/') && fs.existsSync(path.join(flutterBuildPath, 'index.html'))) {
      res.sendFile(path.join(flutterBuildPath, 'index.html'));
    } else {
      res.status(404).json({ error: 'Not found' });
    }
  });
} else {
  // Fallback for non-API requests when no build exists
  app.get('*', (_req, res) => {
    res.status(404).json({ error: 'Not found' });
  });
}

app.listen(PORT, () => {
  console.log(`🚀 ZenVoyage server running on http://localhost:${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/api/health`);
});


