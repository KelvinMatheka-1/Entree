import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { config } from '../config/env.js';
import { UnauthorizedError, ForbiddenError } from '../errors/AppError.js';

export type UserRole = 'admin' | 'organizer' | 'scanner' | 'viewer';

export type Permission =
  | 'events:read'
  | 'events:write'
  | 'events:delete'
  | 'guests:read'
  | 'guests:write'
  | 'scan:verify'
  | 'scan:checkin'
  | 'profile:manage'
  | 'sync:read'
  | 'sync:trigger';

export interface AuthUser {
  id: string;
  username: string;
  role: UserRole;
  permissions: Permission[];
  organization?: string;
}

declare global {
  namespace Express {
    interface Request {
      user?: AuthUser;
    }
  }
}

export const ROLE_PERMISSIONS: Record<UserRole, Permission[]> = {
  admin: [
    'events:read',
    'events:write',
    'events:delete',
    'guests:read',
    'guests:write',
    'scan:verify',
    'scan:checkin',
    'profile:manage',
    'sync:read',
    'sync:trigger',
  ],
  organizer: [
    'events:read',
    'events:write',
    'guests:read',
    'guests:write',
    'scan:verify',
    'scan:checkin',
    'profile:manage',
    'sync:read',
    'sync:trigger',
  ],
  scanner: [
    'events:read',
    'guests:read',
    'scan:verify',
    'scan:checkin',
  ],
  viewer: [
    'events:read',
    'guests:read',
  ],
};

export function getRolePermissions(role: UserRole): Permission[] {
  return ROLE_PERMISSIONS[role] || ROLE_PERMISSIONS.viewer;
}

export function generateToken(user: Omit<AuthUser, 'permissions'>): string {
  const permissions = getRolePermissions(user.role);
  const payload: AuthUser = {
    ...user,
    permissions,
  };

  return jwt.sign(payload, config.security.jwtSecret, {
    expiresIn: config.security.jwtExpiresIn as any,
  });
}

/**
 * Authentication Middleware:
 * Inspects Authorization: Bearer <token> or X-API-Key: <key>.
 * Falls back safely to a default local admin context in development mode.
 */
export function authenticate(req: Request, _res: Response, next: NextFunction): void {
  const authHeader = req.headers.authorization;
  const apiKeyHeader = req.headers['x-api-key'] as string | undefined;

  // 1. Check API Key
  if (apiKeyHeader && apiKeyHeader === config.security.apiKey) {
    req.user = {
      id: 'api-key-user',
      username: 'ApiKeyClient',
      role: 'admin',
      permissions: ROLE_PERMISSIONS.admin,
    };
    return next();
  }

  // 2. Check JWT Bearer token
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.substring(7).trim();
    try {
      const decoded = jwt.verify(token, config.security.jwtSecret) as AuthUser;
      req.user = decoded;
      return next();
    } catch {
      return next(new UnauthorizedError('Invalid or expired authentication token'));
    }
  }

  // 3. Fallback for Local / Development / Offline Flutter execution
  if (config.security.allowAnonymousDev || config.nodeEnv !== 'production') {
    req.user = {
      id: 'dev-user',
      username: 'DefaultOrganizer',
      role: 'admin',
      permissions: ROLE_PERMISSIONS.admin,
      organization: 'Entrée Local',
    };
    return next();
  }

  return next(new UnauthorizedError('Authentication token or valid API key is required'));
}

/**
 * Authorization Middleware:
 * Validates that the authenticated user possesses the required permissions.
 */
export function requirePermission(...requiredPermissions: Permission[]) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    if (!req.user) {
      return next(new UnauthorizedError('Authentication required'));
    }

    const userPermissions = new Set(req.user.permissions || []);
    const hasAll = requiredPermissions.every((p) => userPermissions.has(p));

    if (!hasAll) {
      return next(
        new ForbiddenError(
          `Permission denied: Requires [${requiredPermissions.join(', ')}]`
        )
      );
    }

    next();
  };
}

/**
 * Role Verification Middleware:
 * Validates that the authenticated user has one of the allowed roles.
 */
export function requireRole(...allowedRoles: UserRole[]) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    if (!req.user) {
      return next(new UnauthorizedError('Authentication required'));
    }

    if (!allowedRoles.includes(req.user.role)) {
      return next(
        new ForbiddenError(
          `Forbidden: Role '${req.user.role}' lacks access to this operation`
        )
      );
    }

    next();
  };
}
