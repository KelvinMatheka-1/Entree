import rateLimit from 'express-rate-limit';
import { config } from '../config/env.js';

export const globalLimiter = rateLimit({
  windowMs: config.security.rateLimitWindowMs,
  max: config.security.rateLimitMax,
  standardHeaders: true,
  legacyHeaders: false,
  skip: () => config.nodeEnv === 'test',
  message: {
    success: false,
    message: 'Too many requests from this IP, please try again later.',
  },
});

export const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 30, // 30 login attempts per window
  standardHeaders: true,
  legacyHeaders: false,
  skip: () => config.nodeEnv === 'test',
  message: {
    success: false,
    message: 'Too many authentication attempts. Please try again after 15 minutes.',
  },
});

export const scanLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 120, // 120 scans per minute
  standardHeaders: true,
  legacyHeaders: false,
  skip: () => config.nodeEnv === 'test',
  message: {
    success: false,
    message: 'Check-in scanning rate limit exceeded. Please throttle scan interval.',
  },
});
