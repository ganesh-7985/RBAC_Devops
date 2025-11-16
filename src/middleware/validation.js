import { z } from 'zod';
import logger from '../config/logger.js';

/**
 * Validation middleware using Zod
 * @param {z.ZodSchema} schema - Zod schema to validate against
 * @param {string} source - Where to get data from: 'body', 'query', 'params'
 * @returns {Function} Express middleware
 */
export const validate = (schema, source = 'body') => {
  return (req, res, next) => {
    try {
      const data = req[source];
      const validated = schema.parse(data);
      req[source] = validated; // Replace with validated data
      next();
    } catch (error) {
      if (error instanceof z.ZodError) {
        logger.warn('Validation failed', { 
          source,
          errors: error.errors,
          path: req.path 
        });

        return res.status(400).json({
          error: 'Validation Error',
          message: 'Invalid input data',
          details: error.errors.map(err => ({
            field: err.path.join('.'),
            message: err.message,
            code: err.code
          }))
        });
      }

      logger.error('Validation middleware error', { error: error.message });
      return res.status(500).json({ 
        error: 'Internal Server Error',
        message: 'Validation processing failed' 
      });
    }
  };
};

/**
 * Common validation schemas
 */
export const schemas = {
  // Login validation
  login: z.object({
    username: z.string().min(3).max(50),
    password: z.string().min(6)
  }),

  // User creation validation
  createUser: z.object({
    username: z.string().min(3).max(50),
    email: z.string().email(),
    password: z.string().min(8).regex(
      /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/,
      'Password must contain uppercase, lowercase, number and special character'
    ),
    role: z.enum(['admin', 'user', 'guest']).optional().default('user')
  }),

  // Update user validation
  updateUser: z.object({
    email: z.string().email().optional(),
    role: z.enum(['admin', 'user', 'guest']).optional()
  }),

  // Generic ID validation
  idParam: z.object({
    id: z.string().uuid()
  }),

  // Query pagination
  pagination: z.object({
    page: z.string().regex(/^\d+$/).transform(Number).optional(),
    limit: z.string().regex(/^\d+$/).transform(Number).optional()
  })
};

/**
 * Sanitize input to prevent XSS and injection attacks
 * @param {string} input - Input string to sanitize
 * @returns {string} Sanitized string
 */
export const sanitizeInput = (input) => {
  if (typeof input !== 'string') return input;
  
  return input
    .replace(/[<>]/g, '') // Remove < and >
    .replace(/javascript:/gi, '') // Remove javascript: protocol
    .replace(/on\w+=/gi, '') // Remove event handlers
    .trim();
};

/**
 * Middleware to sanitize all request data
 */
export const sanitizeRequest = (req, res, next) => {
  // Sanitize body
  if (req.body && typeof req.body === 'object') {
    Object.keys(req.body).forEach(key => {
      if (typeof req.body[key] === 'string') {
        req.body[key] = sanitizeInput(req.body[key]);
      }
    });
  }

  // Sanitize query params
  if (req.query && typeof req.query === 'object') {
    Object.keys(req.query).forEach(key => {
      if (typeof req.query[key] === 'string') {
        req.query[key] = sanitizeInput(req.query[key]);
      }
    });
  }

  next();
};
