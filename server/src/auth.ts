import { getDatabase, generateUUID } from './database';
import bcrypt from 'bcryptjs';

// Hash password
export async function hashPassword(password: string): Promise<string> {
  const saltRounds = 12;
  return await bcrypt.hash(password, saltRounds);
}

// Verify password
export async function verifyPassword(password: string, hash: string): Promise<boolean> {
  return await bcrypt.compare(password, hash);
}

// Create user
export async function createUser(email: string, name: string, password: string) {
  const db = getDatabase();
  const id = generateUUID();
  const passwordHash = await hashPassword(password);
  const now = new Date().toISOString();
  
  try {
    const stmt = db.prepare(`
      INSERT INTO users (id, email, name, password_hash, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?)
    `);
    
    stmt.run(id, email, name, passwordHash, now, now);
    
    return { id, email, name };
  } catch (error: any) {
    if (error.message && error.message.includes('UNIQUE constraint failed')) {
      throw new Error('User with this email already exists');
    }
    throw error;
  }
}

// Find user by email
export function findUserByEmail(email: string) {
  const db = getDatabase();
  try {
    const stmt = db.prepare('SELECT * FROM users WHERE email = ?');
    const user = stmt.get(email);
    return user || null;
  } catch (error) {
    console.error('Error finding user by email:', error);
    return null;
  }
}

// Find user by ID
export function findUserById(id: string) {
  const db = getDatabase();
  try {
    const stmt = db.prepare('SELECT * FROM users WHERE id = ?');
    const user = stmt.get(id);
    return user || null;
  } catch (error) {
    console.error('Error finding user by ID:', error);
    return null;
  }
}

// Update user
export async function updateUser(id: string, updates: Partial<{ name: string; avatar_url: string }>) {
  const db = getDatabase();
  const now = new Date().toISOString();
  
  const updateFields = Object.keys(updates).filter(key => updates[key as keyof typeof updates] !== undefined);
  const updateValues = updateFields.map(field => updates[field as keyof typeof updates]);
  
  if (updateFields.length === 0) {
    throw new Error('No fields to update');
  }
  
  try {
    const setClause = updateFields.map(field => `${field} = ?`).join(', ');
    const sql = `UPDATE users SET ${setClause}, updated_at = ? WHERE id = ?`;
    
    const stmt = db.prepare(sql);
    stmt.run([...updateValues, now, id]);
    
    const updatedUser = findUserById(id);
    if (!updatedUser) {
      throw new Error('User not found after update');
    }
    
    return updatedUser;
  } catch (error) {
    console.error('Error updating user:', error);
    throw error;
  }
}

// JWT secret (in production, use environment variable)
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';

// Middleware to verify JWT token
export function verifyToken(token: string): any {
  try {
    // Simple JWT verification for demo
    // In production, use a proper JWT library like jsonwebtoken
    const parts = token.split('.');
    if (parts.length !== 3) {
      throw new Error('Invalid token format');
    }
    
    // Decode payload (not secure, just for demo)
    const payload = JSON.parse(Buffer.from(parts[1], 'base64').toString());
    
    // Check if token is expired
    if (payload.exp && payload.exp < Date.now() / 1000) {
      throw new Error('Token expired');
    }
    
    return payload;
  } catch (error) {
    throw new Error('Invalid token');
  }
}

// Generate JWT token
export function generateToken(userId: string, email: string): string {
  const header = {
    alg: 'HS256',
    typ: 'JWT'
  };
  
  const payload = {
    userId,
    email,
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + (24 * 60 * 60) // 24 hours
  };
  
  const encodedHeader = Buffer.from(JSON.stringify(header)).toString('base64');
  const encodedPayload = Buffer.from(JSON.stringify(payload)).toString('base64');
  const signature = require('crypto')
    .createHmac('sha256', JWT_SECRET)
    .update(`${encodedHeader}.${encodedPayload}`)
    .digest('base64');
  
  return `${encodedHeader}.${encodedPayload}.${signature}`;
}

// Get current user from request
export function getCurrentUser(req: any): any {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) {
    throw new Error('No token provided');
  }
  
  const payload = verifyToken(token);
  const user = findUserById(payload.userId);
  
  if (!user) {
    throw new Error('User not found');
  }
  
  return user;
}