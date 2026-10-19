import { query } from '../db/database.js';
import { machinenovaClient } from '../clients/machinenovaClient.js';
import { config } from '../config/env.js';

export class SyncService {
  private timer: NodeJS.Timeout | null = null;
  private isProcessing = false;

  public startBackgroundSync(): void {
    if (!config.enableAutoSync) return;
    if (this.timer) return;

    this.timer = setInterval(async () => {
      await this.processQueue();
    }, config.syncIntervalMs);

    console.log(`[SYNC] Offline sync worker started (Interval: ${config.syncIntervalMs}ms)`);
  }

  public stopBackgroundSync(): void {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }

  public async getQueueStatus(): Promise<{
    pending: number;
    processing: number;
    failed: number;
    completed: number;
    recentJobs: any[];
  }> {
    const counts = await query(`
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

    const recentJobs = await query(
      'SELECT * FROM sync_queue ORDER BY created_at DESC LIMIT 10'
    );

    return {
      pending: map.pending || 0,
      processing: map.processing || 0,
      failed: map.failed || 0,
      completed: map.completed || 0,
      recentJobs: recentJobs.rows,
    };
  }

  public async processQueue(): Promise<{ processed: number; succeeded: number; failed: number }> {
    if (this.isProcessing) return { processed: 0, succeeded: 0, failed: 0 };
    if (!machinenovaClient.isConfigured()) return { processed: 0, succeeded: 0, failed: 0 };

    this.isProcessing = true;
    let processed = 0;
    let succeeded = 0;
    let failed = 0;

    try {
      const items = await query(`
        SELECT * FROM sync_queue
        WHERE status = 'pending' OR (status = 'failed' AND attempts < 5)
        ORDER BY created_at ASC
        LIMIT 20
      `);

      for (const item of items.rows) {
        processed++;
        await query(
          "UPDATE sync_queue SET status = 'processing', attempts = attempts + 1 WHERE id = $1",
          [item.id]
        );

        try {
          const payload = typeof item.payload === 'string' ? JSON.parse(item.payload) : item.payload;
          await this.executeAction(item.action, payload);

          await query(
            "UPDATE sync_queue SET status = 'completed', updated_at = CURRENT_TIMESTAMP WHERE id = $1",
            [item.id]
          );
          succeeded++;
        } catch (err: any) {
          failed++;
          console.error(`[SYNC] Job ${item.id} execution failed:`, err.message);
          await query(
            `UPDATE sync_queue
             SET status = 'failed', last_error = $1, updated_at = CURRENT_TIMESTAMP
             WHERE id = $2`,
            [err.message, item.id]
          );
        }
      }
    } finally {
      this.isProcessing = false;
    }

    return { processed, succeeded, failed };
  }

  private async executeAction(action: string, payload: any): Promise<void> {
    switch (action) {
      case 'CREATE_EVENT': {
        const mnEvent = await machinenovaClient.createEvent({
          eventName: payload.input.name,
          geoNode: payload.input.geoNode,
          eventStartDate: payload.input.date,
          restrictToJurisdiction: payload.input.restrictToJurisdiction,
          restrictToRoster: payload.input.restrictToRoster,
        });

        await query(
          `UPDATE events SET
            machinenova_event_id = $1,
            sync_status = 'synced',
            last_synced_at = CURRENT_TIMESTAMP
          WHERE id = $2`,
          [mnEvent.name, payload.id]
        );
        break;
      }

      case 'UPDATE_EVENT': {
        await machinenovaClient.updateEvent({
          eventId: payload.machinenovaEventId,
          eventName: payload.input.name,
          isActive: payload.input.status ? payload.input.status !== 'past' : undefined,
          restrictToJurisdiction: payload.input.restrictToJurisdiction,
          restrictToRoster: payload.input.restrictToRoster,
        });

        await query(
          "UPDATE events SET sync_status = 'synced', last_synced_at = CURRENT_TIMESTAMP WHERE id = $1",
          [payload.id]
        );
        break;
      }

      case 'DELETE_EVENT': {
        await machinenovaClient.deleteEvent(payload.machinenovaEventId);
        break;
      }

      case 'CHECKIN': {
        await machinenovaClient.checkin({
          event: payload.machinenovaEventId,
          idNumber: payload.passId,
          fullName: payload.fullName,
          phone: payload.phone,
        });

        await query(
          "UPDATE guests SET sync_status = 'synced', last_synced_at = CURRENT_TIMESTAMP WHERE pass_id = $1",
          [payload.passId]
        );
        break;
      }

      default:
        console.warn(`[SYNC] Unknown sync action: ${action}`);
    }
  }
}

export const syncService = new SyncService();
