import { Request, Response, NextFunction } from 'express';
import { AppError } from '../errors/AppError.js';
import { config } from '../config/env.js';

export function errorHandler(
  err: any,
  req: Request,
  res: Response,
  _next: NextFunction
): void {
  // 1. Handled Operational Errors (AppError instances)
  if (err instanceof AppError) {
    res.status(err.statusCode).json({
      success: false,
      message: err.message,
      ...(err.code ? { code: err.code } : {}),
      ...(err.details ? { details: err.details } : {}),
      ...(config.nodeEnv === 'development' ? { stack: err.stack } : {}),
    });
    return;
  }

  // 2. PostgreSQL Constraint Violations
  if (err && err.code) {
    if (err.code === '23505') {
      res.status(409).json({
        success: false,
        code: 'DUPLICATE_RESOURCE',
        message: 'A resource with this identifier or unique value already exists.',
        details: config.nodeEnv === 'development' ? err.detail : undefined,
      });
      return;
    }
    if (err.code === '23503') {
      res.status(400).json({
        success: false,
        code: 'FOREIGN_KEY_VIOLATION',
        message: 'Referenced related entity does not exist.',
        details: config.nodeEnv === 'development' ? err.detail : undefined,
      });
      return;
    }
  }

  // 3. Syntax / JSON Parsing Errors
  if (err instanceof SyntaxError && 'body' in err) {
    res.status(400).json({
      success: false,
      code: 'INVALID_JSON',
      message: 'Malformed JSON payload in request body.',
    });
    return;
  }

  // 4. Uncaught / Unexpected Internal Errors
  console.error(`[UNHANDLED_ERROR] [${req.method} ${req.originalUrl}]:`, err);

  const statusCode = err.status || err.statusCode || 500;
  const isDev = config.nodeEnv === 'development';

  res.status(statusCode).json({
    success: false,
    code: 'INTERNAL_SERVER_ERROR',
    message: isDev ? (err.message || 'Internal server error') : 'Internal server error occurred.',
    ...(isDev ? { stack: err.stack } : {}),
  });
}
