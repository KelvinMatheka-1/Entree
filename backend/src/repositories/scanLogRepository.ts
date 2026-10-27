import { v4 as uuidv4 } from 'uuid';
import { BaseRepository } from './baseRepository.js';

export interface ScanLogEntry {
  id: string;
  eventId: string;
  passId: string;
  status: string;
  operatorId?: string;
  details?: string;
  createdAt: string;
}

export interface CreateScanLogParams {
  eventId: string;
  passId: string;
  status: string;
  operatorId?: string;
  details?: string;
}

export class ScanLogRepository extends BaseRepository<ScanLogEntry> {
  protected mapRow(row: any): ScanLogEntry {
    return {
      id: row.id,
      eventId: row.event_id,
      passId: row.pass_id,
      status: row.status,
      operatorId: row.operator_id || undefined,
      details: row.details || undefined,
      createdAt: row.created_at ? new Date(row.created_at).toISOString() : new Date().toISOString(),
    };
  }

  public async createLog(params: CreateScanLogParams): Promise<void> {
    await this.query(
      `INSERT INTO scan_logs (id, event_id, pass_id, status, operator_id, details)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [
        uuidv4(),
        params.eventId,
        params.passId,
        params.status,
        params.operatorId || 'default-operator',
        params.details || null,
      ]
    );
  }

  public async findByEventId(eventId: string, limit = 50): Promise<ScanLogEntry[]> {
    const res = await this.query(
      'SELECT * FROM scan_logs WHERE event_id = $1 ORDER BY created_at DESC LIMIT $2',
      [eventId, limit]
    );
    return this.mapRows(res.rows);
  }
}

export const scanLogRepository = new ScanLogRepository();
