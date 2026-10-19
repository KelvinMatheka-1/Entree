import pg from 'pg';
import { newDb } from 'pg-mem';
import { config } from '../config/env.js';

let activePool: any = null;
let isInMemory = false;

const realPool = new pg.Pool({
  connectionString: config.database.connectionString,
  max: config.database.maxPoolSize,
  idleTimeoutMillis: config.database.idleTimeoutMillis,
  connectionTimeoutMillis: config.database.connectionTimeoutMillis,
});

realPool.on('error', (err) => {
  if (!isInMemory) {
    console.error('[DATABASE] Unexpected error on idle PostgreSQL client:', err.message);
  }
});

export async function query<T extends pg.QueryResultRow = any>(
  text: string,
  params?: any[]
): Promise<pg.QueryResult<T>> {
  if (!activePool) {
    await initDatabase();
  }
  return activePool.query(text, params);
}

export async function getClient(): Promise<any> {
  if (!activePool) {
    await initDatabase();
  }
  return activePool.connect();
}

export async function closePool(): Promise<void> {
  if (activePool && !isInMemory) {
    await activePool.end();
  }
}

export async function initDatabase(): Promise<void> {
  // Test connection to PostgreSQL server
  try {
    const client = await realPool.connect();
    client.release();
    activePool = realPool;
    isInMemory = false;
    console.log('[DATABASE] Connected to external PostgreSQL database.');
  } catch (err: any) {
    console.warn('[DATABASE] PostgreSQL server not reachable (' + err.message + ').');
    console.log('[DATABASE] Initializing in-memory PostgreSQL engine for local execution.');
    const memDb = newDb();
    const memPg = memDb.adapters.createPg();
    activePool = new memPg.Pool();
    isInMemory = true;
  }

  const client = await activePool.connect();
  try {
    await client.query('BEGIN');

    // 1. Events Table
    await client.query(`
      CREATE TABLE IF NOT EXISTS events (
        id VARCHAR(64) PRIMARY KEY,
        machinenova_event_id VARCHAR(128) UNIQUE,
        name VARCHAR(255) NOT NULL,
        venue VARCHAR(255) DEFAULT '',
        venue_address VARCHAR(255) DEFAULT '',
        collection VARCHAR(128) DEFAULT '',
        description TEXT DEFAULT '',
        date VARCHAR(32) NOT NULL,
        start_time VARCHAR(32) DEFAULT '18:00',
        end_time VARCHAR(32) DEFAULT '22:00',
        doors_open_time VARCHAR(32) DEFAULT '17:30',
        tables INTEGER DEFAULT 10,
        seats_per_table INTEGER DEFAULT 10,
        total_capacity INTEGER DEFAULT 100,
        passes_issued INTEGER DEFAULT 0,
        checked_in INTEGER DEFAULT 0,
        status VARCHAR(32) DEFAULT 'upcoming',
        image_url TEXT,
        is_paid BOOLEAN DEFAULT TRUE,
        price_badge VARCHAR(64),
        city VARCHAR(128) DEFAULT '',
        restrict_to_jurisdiction BOOLEAN DEFAULT FALSE,
        restrict_to_roster BOOLEAN DEFAULT FALSE,
        geo_node VARCHAR(128),
        organization VARCHAR(128),
        sync_status VARCHAR(32) DEFAULT 'synced',
        last_synced_at TIMESTAMPTZ,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // 2. Guests Table
    await client.query(`
      CREATE TABLE IF NOT EXISTS guests (
        id VARCHAR(64) PRIMARY KEY,
        event_id VARCHAR(64) NOT NULL REFERENCES events(id) ON DELETE CASCADE,
        pass_id VARCHAR(128) NOT NULL,
        full_name VARCHAR(255) NOT NULL,
        email VARCHAR(255) DEFAULT '',
        phone VARCHAR(64) DEFAULT '',
        table_number VARCHAR(32) DEFAULT '01',
        table_name VARCHAR(128) DEFAULT 'General',
        status VARCHAR(32) DEFAULT 'notArrived',
        check_in_time VARCHAR(32),
        admission VARCHAR(64) DEFAULT 'Standard Pass',
        guest_count INTEGER DEFAULT 1,
        dob VARCHAR(32),
        sex VARCHAR(16),
        county VARCHAR(128),
        constituency VARCHAR(128),
        ward VARCHAR(128),
        polling_center VARCHAR(128),
        is_outside_jurisdiction BOOLEAN DEFAULT FALSE,
        registration_status VARCHAR(64),
        sync_status VARCHAR(32) DEFAULT 'synced',
        last_synced_at TIMESTAMPTZ,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // 3. Scan & Audit Logs Table
    await client.query(`
      CREATE TABLE IF NOT EXISTS scan_logs (
        id VARCHAR(64) PRIMARY KEY,
        event_id VARCHAR(64) NOT NULL,
        pass_id VARCHAR(128) NOT NULL,
        status VARCHAR(64) NOT NULL,
        operator_id VARCHAR(128),
        details TEXT,
        scanned_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // 4. Offline Sync Queue Table
    await client.query(`
      CREATE TABLE IF NOT EXISTS sync_queue (
        id VARCHAR(64) PRIMARY KEY,
        action VARCHAR(64) NOT NULL,
        payload JSONB NOT NULL,
        attempts INTEGER DEFAULT 0,
        status VARCHAR(32) DEFAULT 'pending',
        last_error TEXT,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // Indexes
    if (!isInMemory) {
      await client.query(`
        CREATE INDEX IF NOT EXISTS idx_events_date ON events(date);
        CREATE INDEX IF NOT EXISTS idx_events_status ON events(status);
        CREATE INDEX IF NOT EXISTS idx_guests_event ON guests(event_id);
        CREATE INDEX IF NOT EXISTS idx_guests_pass_id ON guests(pass_id);
        CREATE INDEX IF NOT EXISTS idx_guests_status ON guests(status);
        CREATE INDEX IF NOT EXISTS idx_scan_logs_event ON scan_logs(event_id);
        CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue(status);
      `);
    }

    await client.query('COMMIT');
    console.log('[DATABASE] PostgreSQL schema verified and ready.');
  } catch (err: any) {
    await client.query('ROLLBACK');
    console.error('[DATABASE] Schema initialization error:', err.message);
    throw err;
  } finally {
    client.release();
  }
}
