import { Request, Response, NextFunction } from 'express';
import { ZodSchema, ZodError } from 'zod';
import { ValidationError } from '../errors/AppError.js';

export interface ValidationTargets {
  body?: ZodSchema<any>;
  query?: ZodSchema<any>;
  params?: ZodSchema<any>;
}

/**
 * Middleware factory to validate Express request body, query, and/or params against Zod schemas.
 */
export function validateRequest(schemas: ValidationTargets) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    try {
      if (schemas.params) {
        req.params = schemas.params.parse(req.params);
      }
      if (schemas.query) {
        req.query = schemas.query.parse(req.query);
      }
      if (schemas.body) {
        req.body = schemas.body.parse(req.body);
      }
      next();
    } catch (err: any) {
      if (err instanceof ZodError) {
        const formattedErrors = err.errors.map((e) => ({
          field: e.path.join('.'),
          message: e.message,
          rule: e.code,
        }));
        return next(new ValidationError('Request validation failed', formattedErrors));
      }
      next(err);
    }
  };
}
