import express from 'express';
import { authenticateJWT } from '../middleware/auth.js';
import { requireRole, requirePermissions } from '../middleware/rbac.js';

const router = express.Router();

router.get('/public', (req, res) => {
  res.json({
    message: 'This is a public endpoint',
    timestamp: new Date().toISOString(),
    access: 'public'
  });
});

router.get('/guest', 
  authenticateJWT, 
  requireRole(['guest', 'user', 'admin']),
  (req, res) => {
    res.json({
      message: 'Welcome to the guest area',
      user: req.user.username,
      role: req.user.role,
      access: 'guest'
    });
  }
);

router.get('/user',
  authenticateJWT,
  requireRole(['user', 'admin']),
  (req, res) => {
    res.json({
      message: 'Welcome to the user area',
      user: req.user.username,
      role: req.user.role,
      access: 'user',
      data: {
        feature1: 'User feature access',
        feature2: 'Read and write capabilities'
      }
    });
  }
);

router.get('/admin',
  authenticateJWT,
  requireRole(['admin']),
  (req, res) => {
    res.json({
      message: 'Welcome to the admin area',
      user: req.user.username,
      role: req.user.role,
      access: 'admin',
      data: {
        systemStatus: 'All systems operational',
        users: 3,
        uptime: process.uptime()
      }
    });
  }
);


router.post('/admin/users',
  authenticateJWT,
  requirePermissions(['manage_users']),
  (req, res) => {
    res.json({
      message: 'User creation endpoint',
      note: 'This is a mock endpoint. Implement user creation logic here.',
      requestedBy: req.user.username
    });
  }
);


router.delete('/admin/users/:id',
  authenticateJWT,
  requirePermissions(['delete']),
  (req, res) => {
    const { id } = req.params;
    res.json({
      message: 'User deletion endpoint',
      note: 'This is a mock endpoint. Implement user deletion logic here.',
      userId: id,
      requestedBy: req.user.username
    });
  }
);


router.get('/protected',
  authenticateJWT,
  (req, res) => {
    res.json({
      message: 'This is a protected endpoint',
      user: {
        userId: req.user.userId,
        username: req.user.username,
        role: req.user.role
      },
      timestamp: new Date().toISOString()
    });
  }
);

export default router;
