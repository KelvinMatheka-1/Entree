import { v4 as uuidv4 } from 'uuid';
import { BaseRepository } from './baseRepository.js';

export interface SyncQueueItem {
  id: string;
  action: string;
  payload: any;
  status: 'pending' | 'processing' | 'completed' | 'failed';
  attempts: number;
  lastError?: string;
  createdAt: string;
  updatedAt: string;
}

export interface SyncQueueStatus {
  pending: number;
  processing: number;
  failed: number;
  completed: number;
  recentJobs: SyncQueueItem[];
}

export class SyncQueueRepository extends BaseRepository<SyncQueueItem> {
  protected mapRow(row: any): SyncQueueItem {
    let payload = row.payload;
    if (typeof payload === 'string') {
      try {
        payload = JSON.parse(payload);
      } catch (_) {
        // keep string if not json
      }
    }

    return {
      id: row.id,
      action: row.action,
      payload,
      status: row.status,
      attempts: Number(row.attempts ?? 0),
      lastError: row.last_error || undefined,
      createdAt: row.created_at ? new Date(row.created_at).toISOString() : new Date().toISOString(),
      updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : new Date().toISOString(),
    };
  }

  public async enqueue(action: string, payload: any): Promise<void> {
    await this.query(
      `INSERT INTO sync_queue (id, action, payload, status)
       VALUES ($1, $2, $3, 'pending')`,
      [uuidv4(), action, payload]
    );
  }

  public async findPendingAndRetriable(limit = 20, maxAttempts = 5): Promise<SyncQueueItem[]> {
    const res = await this.query(
      `SELECT * FROM sync_queue
       WHERE status = 'pending' OR (status = 'failed' AND attempts < $1)
       ORDER BY created_at ASC
       LIMIT $2`,
      [maxAttempts, limit]
    );
    return this.mapRows(res.rows);
  }

  public async markProcessing(id: string): Promise<void> {
    await this.query(
      "UPDATE sync_queue SET status = 'processing', attempts = attempts + 1, updated_at = CURRENT_TIMESTAMP WHERE id = $1",
      [id]
    );
  }

  public async markCompleted(id: string): Promise<void> {
    await this.query(
      "UPDATE sync_queue SET status = 'completed', updated_at = CURRENT_TIMESTAMP WHERE id = $1",
      [id]
    );
  }

  public async markFailed(id: string, errorMessage: string): Promise<void> {
    await this.query(
      "UPDATE sync_queue SET status = 'failed', last_error = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2",
      [errorMessage, id]
    );
  }

  public async getQueueStatus(): Promise<SyncQueueStatus> {
    const counts = await this.query(`
      SELECT status, COUNT(*) as count
      FROM sync_queue
      GROUP BY status
    `);

    const map: Record<string, number> = {
      pending: 0,
      processing: 0,
      failed: 0,
      completed: 0,
    };

    for (const c of counts.rows) {
      map[c.status] = parseInt(c.count || '0', 10);
    }

    const recentJobs = await this.query(
      'SELECT * FROM sync_queue ORDER BY created_at DESC LIMIT 10'
    );

    return {
      pending: map.pending || 0,
      processing: map.processing || 0,
      failed: map.failed || 0,
      completed: map.completed || 0,
      recentJobs: this.mapRows(recentJobs.rows),
    };
  }

  public async getPendingCount(): Promise<number> {
    const res = await this.query(
      "SELECT COUNT(*) as count FROM sync_queue WHERE status = 'pending'"
    );
    return parseInt(res.rows[0]?.count || '0', 10);
  }
}

export const syncQueueRepository = new SyncQueueRepository();
