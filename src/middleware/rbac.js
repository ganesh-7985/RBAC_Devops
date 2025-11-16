import logger from '../config/logger.js';

/**
 * Role-Based Access Control (RBAC) Configuration
 * Defines role hierarchy and permissions
 */
const ROLE_HIERARCHY = {
  admin: 3,
  user: 2,
  guest: 1
};

const ROLE_PERMISSIONS = {
  admin: ['read', 'write', 'delete', 'manage_users'],
  user: ['read', 'write'],
  guest: ['read']
};

/**
 * Check if a role has required permissions
 * @param {string} userRole - User's role
 * @param {string[]} requiredPermissions - Required permissions
 * @returns {boolean}
 */
const hasPermissions = (userRole, requiredPermissions) => {
  const userPermissions = ROLE_PERMISSIONS[userRole] || [];
  return requiredPermissions.every(permission => 
    userPermissions.includes(permission)
  );
};

/**
 * RBAC Middleware - Check if user has required role
 * @param {string[]} allowedRoles - Array of allowed roles
 * @returns {Function} Express middleware
 */
export const requireRole = (allowedRoles) => {
  return (req, res, next) => {
    // Ensure user is authenticated first
    if (!req.user) {
      logger.warn('RBAC check failed: User not authenticated', { 
        path: req.path 
      });
      return res.status(401).json({ 
        error: 'Unauthorized', 
        message: 'Authentication required' 
      });
    }

    const userRole = req.user.role;

    // Check if user's role is in allowed roles
    if (!allowedRoles.includes(userRole)) {
      logger.warn('RBAC check failed: Insufficient role', {
        userId: req.user.userId,
        userRole: userRole,
        requiredRoles: allowedRoles,
        path: req.path
      });

      return res.status(403).json({ 
        error: 'Forbidden', 
        message: 'Insufficient permissions',
        required: allowedRoles,
        current: userRole
      });
    }

    logger.debug('RBAC check passed', { 
      userId: req.user.userId,
      role: userRole 
    });

    next();
  };
};

/**
 * Permission-based access control middleware
 * @param {string[]} requiredPermissions - Required permissions
 * @returns {Function} Express middleware
 */
export const requirePermissions = (requiredPermissions) => {
  return (req, res, next) => {
    if (!req.user) {
      logger.warn('Permission check failed: User not authenticated');
      return res.status(401).json({ 
        error: 'Unauthorized', 
        message: 'Authentication required' 
      });
    }

    const userRole = req.user.role;

    if (!hasPermissions(userRole, requiredPermissions)) {
      logger.warn('Permission check failed', {
        userId: req.user.userId,
        userRole: userRole,
        requiredPermissions: requiredPermissions,
        path: req.path
      });

      return res.status(403).json({ 
        error: 'Forbidden', 
        message: 'Insufficient permissions',
        required: requiredPermissions
      });
    }

    logger.debug('Permission check passed', { 
      userId: req.user.userId,
      permissions: requiredPermissions 
    });

    next();
  };
};

/**
 * Check if user role is at least the minimum required level
 * @param {string} minRole - Minimum required role
 * @returns {Function} Express middleware
 */
export const requireMinRole = (minRole) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ 
        error: 'Unauthorized', 
        message: 'Authentication required' 
      });
    }

    const userLevel = ROLE_HIERARCHY[req.user.role] || 0;
    const requiredLevel = ROLE_HIERARCHY[minRole] || 0;

    if (userLevel < requiredLevel) {
      logger.warn('Role level check failed', {
        userId: req.user.userId,
        userRole: req.user.role,
        userLevel: userLevel,
        requiredRole: minRole,
        requiredLevel: requiredLevel
      });

      return res.status(403).json({ 
        error: 'Forbidden', 
        message: 'Insufficient role level',
        required: minRole,
        current: req.user.role
      });
    }

    next();
  };
};

export { ROLE_PERMISSIONS, ROLE_HIERARCHY };
