import { createApp } from './app.js';
import { config } from './config/env.js';
import { initDatabase, closePool } from './db/database.js';
import { seedInitialData } from './db/seed.js';
import { syncService } from './services/syncService.js';
import { machinenovaClient } from './clients/machinenovaClient.js';

async function bootstrap() {
  console.log('[STARTUP] Initializing Entree Backend...');

  // 1. Initialize PostgreSQL Database & Seed Data
  try {
    await initDatabase();
    await seedInitialData();
  } catch (err: any) {
    console.error('[DATABASE] Database initialization failed:', err.message);
    console.warn('[DATABASE] Continuing startup, will retry connections as requests arrive.');
  }

  // 2. Start offline sync worker
  syncService.startBackgroundSync();

  // 3. Test MachineNova upstream connection if configured
  if (machinenovaClient.isConfigured()) {
    console.log(`[AUTH] Connecting to MachineNova upstream (${config.machinenova.baseUrl})...`);
    const authed = await machinenovaClient.login();
    if (authed) {
      console.log('[AUTH] Connected and authenticated with MachineNova.');
    } else {
      console.log('[AUTH] MachineNova credentials provided but login was unconfirmed. Running with local fallback enabled.');
    }
  } else {
    console.log('[AUTH] Running in Local / Zero-Config mode with PostgreSQL persistence.');
  }

  // 4. Start HTTP Server
  const app = createApp();
  const server = app.listen(config.port, config.host, () => {
    console.log(`\n======================================================`);
    console.log(`[SERVER] Entree Backend is live at http://${config.host}:${config.port}`);
    console.log(`[SERVER] API Endpoints base: http://${config.host}:${config.port}/api/v1`);
    console.log(`[SERVER] Health check:       http://${config.host}:${config.port}/health`);
    console.log(`======================================================\n`);
  });

  // Graceful shutdown
  const shutdown = async () => {
    console.log('\n[SHUTDOWN] Shutting down gracefully...');
    syncService.stopBackgroundSync();
    server.close(async () => {
      try {
        await closePool();
      } catch (_) {}
      console.log('[SHUTDOWN] Server terminated.');
      process.exit(0);
    });
  };

  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

bootstrap().catch((err) => {
  console.error('[FATAL] Initialization error:', err);
  process.exit(1);
});
