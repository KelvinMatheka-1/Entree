import { v4 as uuidv4 } from 'uuid';
import { BaseRepository } from './baseRepository.js';
import { EntreeGuest } from '../types/guest.js';

export interface GuestFilterOptions {
  status?: string;
  search?: string;
}

export interface AddGuestParams {
  fullName: string;
  email?: string;
  phone?: string;
  passId?: string;
  tableNumber?: string;
  tableName?: string;
  admission?: string;
  county?: string;
  constituency?: string;
  ward?: string;
  pollingCenter?: string;
}

export interface GuestStats {
  total: number;
  checkedIn: number;
  expected: number;
  inRegion: number;
  outOfRegion: number;
}

export class GuestRepository extends BaseRepository<EntreeGuest> {
  protected mapRow(row: any): EntreeGuest {
    return {
      id: row.id,
      eventId: row.event_id,
      passId: row.pass_id,
      fullName: row.full_name,
      email: row.email || '',
      phone: row.phone || undefined,
      tableNumber: row.table_number || '01',
      tableName: row.table_name || 'General',
      status: row.status as any,
      checkInTime: row.check_in_time || undefined,
      admission: row.admission || 'Standard Pass',
      guestCount: Number(row.guest_count ?? 1),
      dob: row.dob || undefined,
      sex: row.sex || undefined,
      county: row.county || undefined,
      constituency: row.constituency || undefined,
      ward: row.ward || undefined,
      pollingCenter: row.polling_center || undefined,
      isOutsideJurisdiction: Boolean(row.is_outside_jurisdiction),
      registrationStatus: row.registration_status || undefined,
      syncStatus: row.sync_status || 'synced',
      lastSyncedAt: row.last_synced_at ? new Date(row.last_synced_at).toISOString() : undefined,
    };
  }

  public async findByEventId(eventId: string, options?: GuestFilterOptions): Promise<EntreeGuest[]> {
    let sql = 'SELECT * FROM guests WHERE event_id = $1';
    const params: any[] = [eventId];
    let pIdx = 2;

    if (options?.status) {
      sql += ` AND status = $${pIdx++}`;
      params.push(options.status);
    }

    if (options?.search) {
      sql += ` AND (full_name ILIKE $${pIdx} OR pass_id ILIKE $${pIdx} OR email ILIKE $${pIdx} OR phone ILIKE $${pIdx})`;
      params.push(`%${options.search}%`);
      pIdx++;
    }

    sql += ' ORDER BY full_name ASC';

    const res = await this.query(sql, params);
    return this.mapRows(res.rows);
  }

  public async findByPassId(eventId: string, passId: string): Promise<EntreeGuest | null> {
    const res = await this.query(
      'SELECT * FROM guests WHERE event_id = $1 AND (pass_id = $2 OR id = $3)',
      [eventId, passId, passId]
    );
    if (res.rows.length === 0) return null;
    return this.mapRow(res.rows[0]);
  }

  public async create(eventId: string, guest: AddGuestParams): Promise<EntreeGuest> {
    const id = `g-${uuidv4().substring(0, 8)}`;
    const passId = guest.passId || `PASS-${Math.floor(1000 + Math.random() * 9000)}`;

    const sql = `
      INSERT INTO guests (
        id, event_id, pass_id, full_name, email, phone,
        table_number, table_name, status, admission, guest_count,
        county, constituency, ward, polling_center, sync_status
      ) VALUES (
        $1, $2, $3, $4, $5, $6,
        $7, $8, 'notArrived', $9, 1,
        $10, $11, $12, $13, 'local_only'
      )
    `;

    await this.query(sql, [
      id,
      eventId,
      passId,
      guest.fullName,
      guest.email || '',
      guest.phone || '',
      guest.tableNumber || '01',
      guest.tableName || 'General',
      guest.admission || 'Standard Pass',
      guest.county || null,
      guest.constituency || null,
      guest.ward || null,
      guest.pollingCenter || null,
    ]);

    const created = await this.findByPassId(eventId, passId);
    return created!;
  }

  public async updateCheckInStatus(
    guestId: string,
    checkInTime: string | null,
    syncStatus: string = 'synced'
  ): Promise<void> {
    const status = checkInTime ? 'checkedIn' : 'notArrived';
    await this.query(
      `UPDATE guests SET
        status = $1,
        check_in_time = $2,
        sync_status = $3,
        last_synced_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
      WHERE id = $4`,
      [status, checkInTime, syncStatus, guestId]
    );
  }

  public async updateSyncStatusByPassId(passId: string, syncStatus: string): Promise<void> {
    await this.query(
      "UPDATE guests SET sync_status = $1, last_synced_at = CURRENT_TIMESTAMP WHERE pass_id = $2",
      [syncStatus, passId]
    );
  }

  public async getEventGuestStats(eventId: string): Promise<GuestStats> {
    const res = await this.query(
      `SELECT
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE status = 'checkedIn') as checked_in,
        COUNT(*) FILTER (WHERE is_outside_jurisdiction = TRUE) as out_of_region
       FROM guests
       WHERE event_id = $1`,
      [eventId]
    );

    const row = res.rows[0] || {};
    const total = parseInt(row.total || '0', 10);
    const checkedIn = parseInt(row.checked_in || '0', 10);
    const outOfRegion = parseInt(row.out_of_region || '0', 10);
    const expected = Math.max(0, total - checkedIn);
    const inRegion = Math.max(0, checkedIn - outOfRegion);

    return {
      total,
      checkedIn,
      expected,
      inRegion,
      outOfRegion,
    };
  }
}

export const guestRepository = new GuestRepository();
