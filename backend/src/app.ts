import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import apiRouter from './routes/index.js';
import { errorHandler } from './middleware/errorHandler.js';
import { globalLimiter } from './middleware/rateLimiter.js';
import { requestLogger } from './middleware/requestLogger.js';
import { NotFoundError } from './errors/index.js';

export function createApp(): express.Application {
  const app = express();

  // Security HTTP headers
  app.use(
    helmet({
      crossOriginResourcePolicy: { policy: 'cross-origin' },
    })
  );

  // Global rate limiter
  app.use(globalLimiter);

  // CORS headers
  app.use(
    cors({
      origin: '*',
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization', 'X-API-Key'],
    })
  );

  // Body parsers
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true }));

  // Structured HTTP request logging
  app.use(requestLogger);

  // Health check endpoint
  app.get('/health', (_req, res) => {
    res.json({
      status: 'healthy',
      time: new Date().toISOString(),
      service: 'Entree MachineNova Event Backend',
    });
  });

  // Mount API router
  app.use('/api/v1', apiRouter);

  // 404 handler forwarded to central error handler
  app.use((req, _res, next) => {
    next(new NotFoundError(`Cannot ${req.method} ${req.path}`));
  });

  // Central operational error handler
  app.use(errorHandler);

  return app;
}
