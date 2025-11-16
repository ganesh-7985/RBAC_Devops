import express from 'express';
import { generateToken } from '../middleware/auth.js';
import { validate, schemas } from '../middleware/validation.js';
import logger from '../config/logger.js';

const router = express.Router();


const MOCK_USERS = [
  {
    userId: '550e8400-e29b-41d4-a716-446655440000',
    username: 'admin',
    password: 'Admin@123', // In production, use bcrypt hashed passwords
    role: 'admin',
    email: 'admin@example.com'
  },
  {
    userId: '550e8400-e29b-41d4-a716-446655440001',
    username: 'user',
    password: 'User@123',
    role: 'user',
    email: 'user@example.com'
  },
  {
    userId: '550e8400-e29b-41d4-a716-446655440002',
    username: 'guest',
    password: 'Guest@123',
    role: 'guest',
    email: 'guest@example.com'
  }
];


router.post('/login', validate(schemas.login), (req, res) => {
  const { username, password } = req.body;

  const user = MOCK_USERS.find(u => u.username === username);

  if (!user || user.password !== password) {
    logger.warn('Login failed', { username, ip: req.ip });
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Invalid username or password'
    });
  }

  const token = generateToken({
    userId: user.userId,
    username: user.username,
    role: user.role
  });

  logger.info('User logged in', { 
    userId: user.userId, 
    username: user.username,
    role: user.role 
  });

  res.json({
    message: 'Login successful',
    token,
    user: {
      userId: user.userId,
      username: user.username,
      role: user.role,
      email: user.email
    }
  });
});


router.get('/users', (req, res) => {
  const users = MOCK_USERS.map(({ password, ...user }) => user);
  res.json({ users });
});

export default router;
