import jwt from 'jsonwebtoken';
import logger from '../config/logger.js';

/**
 * JWT Authentication Middleware
 * Verifies JWT token from Authorization header and attaches user to request
 */
export const authenticateJWT = (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    logger.warn('Missing or invalid Authorization header', { 
      ip: req.ip,
      path: req.path 
    });
    return res.status(401).json({ 
      error: 'Unauthorized', 
      message: 'No token provided' 
    });
  }

  const token = authHeader.substring(7); // Remove 'Bearer ' prefix

  try {
    const jwtSecret = process.env.JWT_SECRET;
    
    if (!jwtSecret) {
      logger.error('JWT_SECRET is not configured');
      return res.status(500).json({ 
        error: 'Internal Server Error',
        message: 'Authentication not properly configured' 
      });
    }

    const decoded = jwt.verify(token, jwtSecret);
    
    // Attach user information to request
    req.user = {
      userId: decoded.userId,
      username: decoded.username,
      role: decoded.role,
      permissions: decoded.permissions || []
    };

    logger.debug('JWT verified successfully', { 
      userId: req.user.userId,
      role: req.user.role 
    });

    next();
  } catch (error) {
    logger.warn('JWT verification failed', { 
      error: error.message,
      ip: req.ip 
    });

    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ 
        error: 'Unauthorized', 
        message: 'Token expired' 
      });
    }

    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({ 
        error: 'Unauthorized', 
        message: 'Invalid token' 
      });
    }

    return res.status(401).json({ 
      error: 'Unauthorized', 
      message: 'Authentication failed' 
    });
  }
};

/**
 * Generate JWT token for user
 * @param {Object} payload - User data to encode in token
 * @returns {string} JWT token
 */
export const generateToken = (payload) => {
  const jwtSecret = process.env.JWT_SECRET;
  const jwtExpiry = process.env.JWT_EXPIRY || '1h';

  if (!jwtSecret) {
    throw new Error('JWT_SECRET is not configured');
  }

  return jwt.sign(payload, jwtSecret, { 
    expiresIn: jwtExpiry,
    issuer: 'secure-api-gateway',
    audience: 'api-clients'
  });
};
