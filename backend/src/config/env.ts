import dotenv from 'dotenv';

dotenv.config();

export const config = {
  port: parseInt(process.env.PORT || '4000', 10),
  host: process.env.HOST || '0.0.0.0',
  nodeEnv: process.env.NODE_ENV || 'development',
  corsOrigin: process.env.CORS_ORIGIN || '*',

  // Security & Authentication Settings
  security: {
    jwtSecret: process.env.JWT_SECRET || 'entree-machinenova-jwt-secret-key-32charsmin',
    jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
    apiKey: process.env.ENTREE_API_KEY || 'entree-api-key-default-dev',
    allowAnonymousDev: process.env.ALLOW_ANONYMOUS_DEV !== 'false',
    rateLimitWindowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '900000', 10), // 15 mins
    rateLimitMax: parseInt(process.env.RATE_LIMIT_MAX || '600', 10), // 600 requests per window
  },

  // PostgreSQL Configuration
  database: {
    connectionString:
      process.env.DATABASE_URL ||
      `postgres://${process.env.PGUSER || 'postgres'}:${process.env.PGPASSWORD || 'postgres'}@${process.env.PGHOST || 'localhost'}:${process.env.PGPORT || '5432'}/${process.env.PGDATABASE || 'entree_db'}`,
    maxPoolSize: parseInt(process.env.PGMAX_POOL || '20', 10),
    idleTimeoutMillis: parseInt(process.env.PG_IDLE_TIMEOUT || '30000', 10),
    connectionTimeoutMillis: parseInt(process.env.PG_CONN_TIMEOUT || '5000', 10),
  },

  // MachineNova Upstream Settings
  machinenova: {
    useMachineNovaLive: process.env.USE_MACHINENOVA_LIVE === 'true',
    baseUrl: process.env.MACHINENOVA_BASE_URL || 'https://checkin-backend.machinenova.com',
    frontendUrl: process.env.MACHINENOVA_FRONTEND_URL || 'https://checkin.machinenova.com',
    orgSlug: process.env.MACHINENOVA_ORG_SLUG || '',
    username: process.env.MACHINENOVA_USERNAME || '',
    password: process.env.MACHINENOVA_PASSWORD || '',
    apiKey: process.env.MACHINENOVA_API_KEY || '',
    apiSecret: process.env.MACHINENOVA_API_SECRET || '',
    timeoutMs: parseInt(process.env.MACHINENOVA_TIMEOUT_MS || '10000', 10),
  },

  // Sync Engine Settings
  syncIntervalMs: parseInt(process.env.SYNC_INTERVAL_MS || '30000', 10),
  enableAutoSync: process.env.ENABLE_AUTO_SYNC === 'true',
};
