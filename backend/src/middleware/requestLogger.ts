import { Request, Response, NextFunction } from 'express';

export function requestLogger(req: Request, res: Response, next: NextFunction): void {
  if (process.env.NODE_ENV === 'test') {
    return next();
  }
  const start = Date.now();
  const { method, originalUrl, ip } = req;

  res.on('finish', () => {
    const duration = Date.now() - start;
    const statusCode = res.statusCode;
    const logPrefix = `[HTTP] ${method} ${originalUrl} ${statusCode} - ${duration}ms (IP: ${ip || 'unknown'})`;

    if (statusCode >= 500) {
      console.error(logPrefix);
    } else if (statusCode >= 400) {
      console.warn(logPrefix);
    } else {
      console.log(logPrefix);
    }
  });

  next();
}
